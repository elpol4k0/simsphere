module Animals

using ..Types
using ..WorldModule

export AnimalAgent, AgentModel, create_animal_model, step_animals!
export HERBIVORE, CARNIVORE, random_good_pos

const HERBIVORE = :herbivore
const CARNIVORE = :carnivore

mutable struct AnimalAgent
    id::Int
    species::Symbol
    pos::Tuple{Int,Int}
    energy::Float64
    age::Int
    hunger::Float64
    thirst::Float64
    alive::Bool
end

function AnimalAgent(id, species, pos)
    e = species == HERBIVORE ? 0.6 : 0.7
    AnimalAgent(id, species, pos, e, 0, 0.0, 0.0, true)
end

mutable struct AgentModel
    agents::Vector{AnimalAgent}
    next_id::Int
    world::World
    config::SimConfig
    n_herbivores::Int
    n_carnivores::Int
    births::Int
    deaths::Int
end

function create_animal_model(world::World, config::SimConfig;
                             n_herbivores::Int = 40,
                             n_carnivores::Int = 10)
    agents = AnimalAgent[]
    id = 1

    for _ in 1:n_herbivores
        pos = random_good_pos(world, :herbivore)
        push!(agents, AnimalAgent(id, HERBIVORE, pos))
        id += 1
    end

    for _ in 1:n_carnivores
        pos = random_good_pos(world, :carnivore)
        push!(agents, AnimalAgent(id, CARNIVORE, pos))
        id += 1
    end

    AgentModel(agents, id, world, config, n_herbivores, n_carnivores, 0, 0)
end

function random_good_pos(world::World, species::Symbol)
    for _ in 1:100
        i = rand(1:world.height)
        j = rand(1:world.width)
        c = world.cells[i, j]
        if species == HERBIVORE && c.biomass > 0.1 && c.water > 0.05
            return (i, j)
        elseif species == CARNIVORE && c.temperature > 0.0
            return (i, j)
        end
    end
    return (rand(1:world.height), rand(1:world.width))
end

function step_animals!(model::AgentModel, state::SimState)
    world    = model.world
    newborns = AnimalAgent[]

    model.n_herbivores = 0
    model.n_carnivores = 0

    for agent in model.agents
        !agent.alive && continue

        agent.age   += 1
        cell = world.cells[agent.pos[1], agent.pos[2]]

        # Temperature-dependent metabolism: extreme temps cost more energy
        temp_stress  = max(0.0, abs(cell.temperature - 15.0) - 10.0) / 30.0
        base_cost    = energy_cost(agent)
        hunger_delta = base_cost * (1.0 + 1.2 * temp_stress)

        # Disease factor from active events (set in Events.jl via config)
        if agent.species == HERBIVORE
            hunger_delta += model.config.disease_herb_factor
        else
            hunger_delta += model.config.disease_carn_factor
        end

        # Flood penalty: standing in flood water exhausts animals
        if cell.flood_depth > 0.1
            hunger_delta += 0.001 * min(1.0, cell.flood_depth * 4.0)
            agent.thirst  = max(0.0, agent.thirst - 0.05)  # flood water is drinkable
        end

        agent.hunger = min(1.0, agent.hunger + hunger_delta)
        agent.thirst = min(1.0, agent.thirst + 0.002)

        max_age = agent.species == HERBIVORE ? 3650 : 5475
        if agent.hunger >= 1.0 || agent.age > max_age || agent.thirst >= 1.0
            # Dead biomass returns nutrients to soil
            world.cells[agent.pos[1], agent.pos[2]].nutrients =
                min(1.0, cell.nutrients + 0.015)
            agent.alive  = false
            agent.energy = 0.0
            model.deaths += 1
            continue
        end

        move!(agent, world, model)
        eat!(agent, world, model)

        if can_reproduce(agent, model)
            baby = reproduce!(agent, model)
            baby !== nothing && push!(newborns, baby)
        end

        if agent.species == HERBIVORE
            model.n_herbivores += 1
        else
            model.n_carnivores += 1
        end
    end

    filter!(a -> a.alive, model.agents)
    append!(model.agents, newborns)
    model.births += length(newborns)

    model.n_herbivores = count(a -> a.alive && a.species == HERBIVORE, model.agents)
    model.n_carnivores = count(a -> a.alive && a.species == CARNIVORE, model.agents)
end

function move!(agent::AnimalAgent, world::World, model::AgentModel)
    i, j     = agent.pos
    radius   = agent.species == HERBIVORE ? 4 : 6
    best_u   = -Inf
    best_pos = agent.pos

    i_min = max(1, i - radius)
    i_max = min(world.height, i + radius)
    j_min = max(1, j - radius)
    j_max = min(world.width,  j + radius)

    @inbounds for ti in i_min:i_max, tj in j_min:j_max
        dist = sqrt(Float64((ti-i)^2 + (tj-j)^2))
        dist < 0.5 && continue

        u = utility(agent, world, model, ti, tj, dist)
        if u > best_u
            best_u   = u
            best_pos = (ti, tj)
        end
    end

    if best_pos != agent.pos
        di = sign(best_pos[1] - i)
        dj = sign(best_pos[2] - j)
        ni = clamp(i + di, 1, world.height)
        nj = clamp(j + dj, 1, world.width)
        agent.pos = (ni, nj)
    end
end

function utility(agent::AnimalAgent, world::World, model::AgentModel,
                 ti::Int, tj::Int, dist::Float64)::Float64
    cell = world.cells[ti, tj]

    flood_pen = cell.flood_depth * 0.4   # both species avoid deep floods

    if agent.species == HERBIVORE
        food_value  = cell.biomass * agent.hunger
        water_value = cell.water   * agent.thirst * 0.5
        # Herding: slight preference for cells where other herbivores are (safety)
        herd_bonus  = count_nearby(model, ti, tj, HERBIVORE, 2) * 0.02
        temp_pen    = temp_penalty(cell.temperature, 15.0, 12.0)
        return (food_value + water_value + herd_bonus) / (dist + 1.0) - temp_pen - flood_pen
    else
        prey_nearby = count_nearby(model, ti, tj, HERBIVORE, 2)
        prey_value  = (prey_nearby * 0.5 + 0.1) * (agent.hunger + 0.2)
        water_value = cell.water * agent.thirst * 0.4
        temp_pen    = temp_penalty(cell.temperature, 18.0, 15.0)
        return (prey_value + water_value) / (dist + 1.0) - temp_pen - flood_pen
    end
end

@inline function temp_penalty(temp::Float64, t_opt::Float64, sigma::Float64)::Float64
    return 0.3 * (1.0 - exp(-((temp - t_opt)^2) / (2.0 * sigma^2)))
end

function count_nearby(model::AgentModel, i::Int, j::Int,
                      species::Symbol, radius::Int)::Int
    n = 0
    for a in model.agents
        a.alive && a.species == species || continue
        if abs(a.pos[1]-i) <= radius && abs(a.pos[2]-j) <= radius
            n += 1
        end
    end
    n
end

function eat!(agent::AnimalAgent, world::World, model::AgentModel)
    i, j = agent.pos
    cell = world.cells[i, j]

    if agent.species == HERBIVORE
        if cell.biomass > 0.05
            eaten = min(0.05, cell.biomass)
            cell.biomass -= eaten
            agent.energy += eaten * 0.8
            agent.hunger  = max(0.0, agent.hunger - eaten * 2.0)
        end
        if cell.water > 0.1
            agent.thirst = max(0.0, agent.thirst - 0.1)
            cell.water  -= 0.005
        end
    else
        if cell.water > 0.15
            agent.thirst = max(0.0, agent.thirst - 0.15)
            cell.water  -= 0.003
        end

        if agent.hunger > 0.35
            for prey in model.agents
                !prey.alive && continue
                prey.species != HERBIVORE && continue
                dist = abs(prey.pos[1] - agent.pos[1]) + abs(prey.pos[2] - agent.pos[2])
                if dist <= 1
                    catch_prob = 0.08 + 0.15 * agent.hunger
                    if rand() < catch_prob
                        prey.alive    = false
                        agent.energy  = min(1.0, agent.energy + 0.6)
                        agent.hunger  = max(0.0, agent.hunger - 0.7)
                        agent.thirst  = max(0.0, agent.thirst - 0.4)
                        model.deaths += 1
                    end
                    break
                end
            end
        end
    end

    agent.energy = clamp(agent.energy, 0.0, 1.0)
end

function can_reproduce(agent::AnimalAgent, model::AgentModel)::Bool
    min_age = agent.species == HERBIVORE ? 240 : 480
    agent.energy > 0.65 && agent.age > min_age && agent.hunger < 0.35
end

function reproduce!(agent::AnimalAgent, model::AgentModel)::Union{AnimalAgent,Nothing}
    if agent.species == HERBIVORE
        for other in model.agents
            !other.alive && continue
            other.id == agent.id && continue
            other.species != HERBIVORE && continue
            !can_reproduce(other, model) && continue
            abs(other.pos[1]-agent.pos[1]) + abs(other.pos[2]-agent.pos[2]) > 3 && continue

            model.next_id += 1
            bi = clamp(agent.pos[1] + rand(-1:1), 1, model.world.height)
            bj = clamp(agent.pos[2] + rand(-1:1), 1, model.world.width)
            baby = AnimalAgent(model.next_id, HERBIVORE, (bi, bj))
            baby.energy = 0.4
            agent.energy -= 0.15
            other.energy -= 0.15
            return baby
        end
    else
        if agent.energy > 0.8 && agent.hunger < 0.2
            model.next_id += 1
            bi = clamp(agent.pos[1] + rand(-2:2), 1, model.world.height)
            bj = clamp(agent.pos[2] + rand(-2:2), 1, model.world.width)
            baby = AnimalAgent(model.next_id, CARNIVORE, (bi, bj))
            baby.energy = 0.5
            agent.energy -= 0.3
            return baby
        end
    end
    return nothing
end

@inline function energy_cost(agent::AnimalAgent)::Float64
    agent.species == HERBIVORE ? 0.0008 : 0.0006
end

function cap_population!(model::AgentModel, max_herb::Int, max_carn::Int)
    herbs = filter(a -> a.alive && a.species == HERBIVORE, model.agents)
    carns = filter(a -> a.alive && a.species == CARNIVORE, model.agents)

    if length(herbs) > max_herb
        sort!(herbs, by=a->a.energy)
        for a in herbs[1:length(herbs)-max_herb]
            a.alive = false
        end
    end
    if length(carns) > max_carn
        sort!(carns, by=a->a.energy)
        for a in carns[1:length(carns)-max_carn]
            a.alive = false
        end
    end
end

function agent_density_map(model::AgentModel, species::Symbol)
    h, w = model.world.height, model.world.width
    m = zeros(Float64, h, w)
    for a in model.agents
        a.alive && a.species == species || continue
        m[a.pos[1], a.pos[2]] += 1.0
    end
    m
end

end
