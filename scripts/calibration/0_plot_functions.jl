function decide_on_solution(opt, calibration_obj;  parameter_names = nothing)
    ws = fill(0.5 / 6, 7)
    ws[1] = 0.5
    my_dm = mcdm(opt, ws, TopsisMethod());
    pnames = isnothing(calibration_obj) ? parameter_names : calibration_obj.parameter_names
    p_optimized = prepare_p(opt.population[my_dm.bestIndex].x, pnames)
    return p_optimized
end

function solution(opt, calibration_obj)
    optimized_parameter = decide_on_solution(opt, calibration_obj)
    all_p = merge(calibration_obj.fixed_parameter, optimized_parameter)
    return sim.SimulationParameter(; all_p...)
end

function plot_one_site_several_p(p_vals, weights, opt_obj, train_index = 1)
    @unpack trait_input, parameter_names, fixed_parameter,
            input_data, measurement_data = opt_obj

    input_obj = input_data[train_index]
    data = measurement_data[train_index]
    data_trait_t = LookupArrays.index(data.traits, :time)
    trait_symbols = [:rsa, :abp, :sla, :maxheight, :amc, :lnc]
    ntraits = length(trait_symbols)
    trait_strings = [
        "Root surface area\nper belowground \nbiomass [m² g⁻¹]",
        "Aboveground\nbiomass per\ntotal biomass [-]",
        "Specific leaf\narea [m² g⁻¹]",
        "Maximum\nheight [m]",
        "Arbuscular\nmycorrhizal\ncolonisation [-]",
        "Leaf nitrogen per\nleaf mass [mg g⁻¹]"
    ]
    is_train = String(train_index) ∈ opt_obj.BE_IDs_train
    sitetype_label = is_train ? "calibration" : "validation"

    measured_cut_biomass = vec(data.biomass)
    cut_index = input_obj.output_validation.biomass_cutting_index
    biomass_date = input_obj.output_validation.biomass_cutting_numeric_date[cut_index]

    fig = Figure()

    site = input_obj.site
    nyears = length(2006:2021)

    yearly_sum_precip = Int(round(ustrip(sum(input_obj.input.precipitation) / nyears)))
    yearly_sum_pet = Int(round(ustrip(sum(input_obj.input.PET) / nyears)))
    mean_par = Int(round(ustrip(mean(input_obj.input.PAR) * 0.01 )))
    mean_temperature = round(ustrip(mean(input_obj.input.temperature)); digits = 2)

    nmowing = round(sum(.! isnan.(input_obj.input.CUT_mowing)) / nyears; digits = 1)
    graz_int = round(ustrip(sum(input_obj.input.LD_grazing[.! isnan.(input_obj.input.LD_grazing)]) / nyears); digits = 1)

    site_label1 = rich("Site $(input_obj.simp.plotID) ($sitetype_label)\n", font = :bold)
    site_label2 = """
    \ntotal N: $(ustrip(site.totalN)) [g kg⁻¹]
    sand $(Int(round(100 * site.sand))) [%], silt $(Int(round(100 * site.silt))) [%], clay $(Int(round(100 * site.clay))) [%]
    organic $(Int(round(100 * site.organic))) [%], bulk density $(ustrip(site.bulk)) [g cm⁻³]
    rootdepth $(Int(round(ustrip(site.rootdepth) / 10))) [cm]\n
    daily mean photosynthetically active radiation $mean_par [MJ km⁻²]
    daily mean temperature $mean_temperature [°C]
    yearly sum of precipitation $yearly_sum_precip [mm]
    yearly sum of potential evapotranspiration $yearly_sum_pet [mm]\n
    mowing events per year $nmowing
    yearly sum of livestock density $graz_int [LSU ha⁻¹]"""

    Label(fig[0, 1];
          valign = :top,
          halign = :left,
          justification = :left,
          alignmode = Inside(),
          text = rich(site_label1, site_label2) )

    ######## build axes
    ax_settings = (; width = 450, height = 150, xticks = 2006:2:2022,
                     xminorticks = 2006:1:2022, xminorticksvisible = true)

    biomass_ax = Axis(fig[1, 1]; xlabel = "", ylabel = "Total aboveground\nbiomass [kg ha⁻¹]", ax_settings..., xticklabelsvisible = false, limits = (nothing, nothing, 0, 7000) )
    trait_axes = []
    for t in 1:ntraits
        ## trait input
        input_trait_vals = ustrip.(trait_input[trait_symbols[t]])
        min_trait_val = minimum(input_trait_vals)
        max_trait_val = maximum(input_trait_vals)

        ax = Axis(fig[1+t, 1]; ylabel = String(trait_strings[t]), ax_settings...,
                  xlabel = t == 6 ? "Time [year]" : "",
                  limits = (nothing, nothing, min_trait_val, max_trait_val),
                  xticklabelsvisible = t == 6 ? true : false,)
        push!(trait_axes, ax)
    end

    ######## simulate and plot
    nparameter_combinations = size(p_vals, 1)
    color_vals = fill((:black, 0.1), nparameter_combinations)
    color_vals[1] = (:red, 0.8)
    lws = fill(1, nparameter_combinations)
    lws[1] = 2


    errors = nothing

    for p_i in 1:nparameter_combinations
        optimized_parameter = prepare_p(p_vals[p_i, :], parameter_names)

        p = sim.SimulationParameter(; fixed_parameter..., optimized_parameter...)

        sol = sim.solve_prob(; input_obj, p, trait_input)

        if p_i == 1
            errors = error_for_one_site(; p, input_obj, trait_input, data)
        end

        ##### biomass
        total_biomass = sum(sol.output.above_biomass[:, 1, 1, :]; dims = :species)
        simulated_cut_biomass = ustrip.(sol.valid.cut_biomass)[cut_index]
        lines!(biomass_ax, sol.simp.output_date_num, vec(ustrip.(total_biomass)),
               color = color_vals[p_i])
        scatter!(biomass_ax, biomass_date, simulated_cut_biomass;
                 color = color_vals[p_i], markersize = 10)
        if p_i == 1
            Label(fig[1, 1], "$(round(errors[1]; digits = 0))";
                padding = (0,5,0,0), justification = :right,
                halign = :right, valign = :top)
        end


        ##### traits
        species_biomass = dropdims(mean(@view sol.output.biomass[data_trait_t, :, :, :];
                                        dims = (:x, :y)); dims = (:x, :y))
        species_biomass = ustrip.(species_biomass)
        site_biomass = vec(sum(species_biomass; dims = (:species)))

        species_biomass_all = dropdims(mean(sol.output.biomass;
                                            dims = (:x, :y)); dims = (:x, :y))
        species_biomass_all = ustrip.(species_biomass_all)
        site_biomass_all = vec(sum(species_biomass_all; dims = (:species)))

        if !( any(iszero.(site_biomass)) || any(isnan.(site_biomass)) )
            relative_biomass = species_biomass ./ site_biomass
            relative_biomass_all = species_biomass_all ./ site_biomass_all

            for (i,trait_symbol) in enumerate(trait_symbols)
                ## simulated cwm timeseries
                trait_vals = ustrip.(sol.traits[trait_symbol])
                weighted_trait_all = trait_vals .* relative_biomass_all'
                sim_cwm_trait_all = vec(sum(weighted_trait_all; dims = 1))

                lines!(trait_axes[i], sol.simp.output_date_num, sim_cwm_trait_all,
                    color = color_vals[p_i], linewidth = lws[p_i])

                if p_i == 1
                    Label(fig[1+i, 1], "$(round(errors[i+1]; digits = 3))";
                        padding = (0,5,0,0), justification = :right,
                        halign = :right, valign = :top)
                end
            end
        end
    end

    ######## add measured values
    scatter!(biomass_ax, biomass_date, measured_cut_biomass; color = :black)
    for t in 1:ntraits
        ## calculated cwm from observed vegetation
        measured_cwm = vec(data.traits[trait = At(trait_symbols[t])])
        scatter!(trait_axes[t], to_numeric.(data.fun_diversity.date), measured_cwm; color = :black)
    end

    [rowgap!(fig.layout, i, 10) for i in 2:7]
    resize_to_layout!(fig)
    fig
end

function to_numeric(d::Dates.Date)
    daysinyear = Dates.daysinyear(Dates.year(d))
    return Dates.year(d) + (Dates.dayofyear(d) - 1) / daysinyear
end
