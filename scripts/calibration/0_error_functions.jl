function total_error(opt, p_vals)
    vec(mean(error_for_sites(opt, p_vals); dims = 1))
end

function prepare_p(values, names)
    ## compile parameter
    p = (; zip(Symbol.(names), values)...)

    ## add units for some parameters
    @reset p.δ_NUT_rsa = p.δ_NUT_rsa * u"g / m^2"
    @reset p.δ_WAT_rsa = p.δ_WAT_rsa * u"g / m^2"
    @reset p.α_NUT_TSB = p.α_NUT_TSB * u"kg / ha"
    @reset p.ζ_SEA_ST1 = p.ζ_SEA_ST1 * u"°C"
    @reset p.ζ_SEA_ST2 = p.ζ_SEA_ST2 * u"°C"
    @reset p.ψ_SEN_ST1 = p.ψ_SEN_ST1 * u"°C"

    return p
end

function error_for_sites(opt, p_vals; calc_all_sites = false)
    @unpack input_data, BE_IDs_train, BE_IDs_test, BE_IDs, fixed_parameter, parameter_names,
            cache, trait_input, measurement_data = opt

    site_ids = BE_IDs_train

    ## this is only used for validation/generating plots
    if calc_all_sites
        site_ids = vcat(BE_IDs_train, BE_IDs_test)
    end

    ## compile parameter
    optimized_parameter = prepare_p(p_vals, parameter_names)

    all_p = merge(fixed_parameter, optimized_parameter)
    p = sim.SimulationParameter(; all_p...)

    ## vector for sum of squares
    nobjectives = 7
    nsites = length(site_ids)
    diff_vec = Array{Float64}(undef, nsites, nobjectives)

    for i in eachindex(site_ids)
        try
            plotID = Symbol(site_ids[i])
            input_obj = input_data[plotID]
            prealloc = sim.get_buffer(cache, Float64, Threads.threadid();
                input_obj = input_data[plotID])

            data = measurement_data[plotID]

            diff = error_for_one_site(; p, input_obj, prealloc, trait_input, data)
            diff_vec[i, :] = diff
        catch e
            @warn "Error in calculation: $e" maxlog=100
            diff_vec[i, :] = Inf
        end
    end

    return diff_vec
end

function error_for_one_site(; p, input_obj, prealloc = nothing, trait_input, data)
    sol = sim.solve_prob(; input_obj, p, prealloc, trait_input)

    ##### total biomass
    simulated_cut_biomass = calc_cut_biomass(sol, data);
    measured_cut_biomass = vec(data.Cut_biomass.biomass)
    er_biomass = ustrip(mean_error(simulated_cut_biomass, measured_cut_biomass))

    ##### traits
    trait_dates = LookupArrays.index(data.CWM_traits, :t)
    species_biomass = dropdims(mean(@view sol.output.biomass[time = At(trait_dates)];
                                    dims = (:x, :y)); dims = (:x, :y))
    species_biomass = ustrip.(species_biomass)
    site_biomass = vec(sum(species_biomass; dims = (:species)))

    trait_symbols = [:rsa, :abp, :sla, :maxheight, :amc, :lnc]
    ntraits = length(trait_symbols)
    er_traits = fill(Inf, ntraits)

    if !( any(iszero.(site_biomass)) || any(isnan.(site_biomass)) )
        relative_biomass = species_biomass ./ site_biomass

        for (i,trait_symbol) in enumerate(trait_symbols)
            ## simulated cwm
            trait_vals = sol.traits[trait_symbol]
            weighted_trait = trait_vals .* relative_biomass'
            sim_cwm_trait = vec(sum(weighted_trait; dims = 1))

            ## calculated cwm from observed vegetation
            measured_cwm = data.CWM_traits[trait_symbol]

            er_traits[i] = ustrip(mean_error(sim_cwm_trait, measured_cwm))
        end
    end

    return [er_biomass, er_traits...]
end


function mean_error(x, y)
    sum(abs.(x .- y)) / length(x)
end

function calc_cut_biomass(container, data)
    @unpack species_mean_above_biomass, species_mean_actual_height, species_cut_biomass,
            proportion_mown = container.calc
    @unpack output = container
    @unpack nspecies = container.simp

    cut_dates = LookupArrays.index(data.Cut_biomass, :t)
    ndates = length(cut_dates)
    cut_biomass = Vector{typeof(1.0u"kg/ha")}(undef, ndates)

    for i in 1:ndates
        for s in 1:nspecies
            vec_view = @view output.above_biomass[time = At(cut_dates[i]), species = At(s)]
            species_mean_above_biomass[s] = mean(vec_view)

            vec_height_view = @view output.height[time = At(cut_dates[i]), species = At(s)]
            species_mean_actual_height[s] = mean(vec_height_view)
        end

        # --------- proportion of plant height that is mown
        proportion_mown .= max.(species_mean_actual_height .- data.Cut_biomass.cutting_height[i], 0.0u"m") ./
        (species_mean_actual_height .+ 0.0001u"m")

        species_cut_biomass .= proportion_mown .* species_mean_above_biomass
        cut_biomass[i] = sum(species_cut_biomass)
    end

    return cut_biomass
end
