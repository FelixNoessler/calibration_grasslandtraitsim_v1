function get_mowing(nmowing, date, ntimesteps)
    ################## mowing
    mheight = 0.05u"m"
    mowing = if nmowing == 0
        mowing_none = fill(NaN * u"m", ntimesteps)
    elseif nmowing == 1
        mowing_dates = Dates.Date.(2006:2021, 7, 1)
        mowing_one = fill(NaN * u"m", ntimesteps)
        [mowing_one[d .== date] .= mheight for d in mowing_dates]
        mowing_one
    elseif nmowing == 2
        mowing_dates = vcat(Dates.Date.(2006:2021, 5, 1), Dates.Date.(2006:2021, 9, 1))
        mowing_two = fill(NaN * u"m", ntimesteps)
        [mowing_two[d .== date] .= mheight for d in mowing_dates]
        mowing_two
    elseif nmowing == 3
        mowing_dates = vcat(Dates.Date.(2006:2021, 5, 1), Dates.Date.(2006:2021, 7, 1),
                            Dates.Date.(2006:2021, 9, 1))
        mowing_three = fill(NaN * u"m", ntimesteps)
        [mowing_three[d .== date] .= mheight for d in mowing_dates]
        mowing_three
    elseif nmowing == 4
        mowing_dates = vcat(Dates.Date.(2006:2021, 5, 1), Dates.Date.(2006:2021, 6, 10),
                            Dates.Date.(2006:2021, 7, 20), Dates.Date.(2006:2021, 9, 1))
        mowing_four = fill(NaN * u"m", ntimesteps)
        [mowing_four[d .== date] .= mheight for d in mowing_dates]
        mowing_four
    elseif nmowing == 5
        mowing_dates = vcat(Dates.Date.(2006:2021, 5, 1), Dates.Date.(2006:2021, 6, 1),
                            Dates.Date.(2006:2021, 7, 1), Dates.Date.(2006:2021, 8, 1),
                            Dates.Date.(2006:2021, 9, 1))
        mowing_five = fill(NaN * u"m", ntimesteps)
        [mowing_five[d .== date] .= mheight for d in mowing_dates]
        mowing_five
    end

end

function standing_biomass_mowing(p, opt_obj, plotID, dir; iteration)
    tot_biomass = []
    for nmowing in 1:5
        trait_input = sim.input_traits();
        input_obj = opt_obj.input_data[plotID]
        date = input_obj.simp.mean_input_date
        ntimesteps = input_obj.simp.ntimesteps
        @reset input_obj.input.CUT_mowing = get_mowing(nmowing, date, ntimesteps)
        @reset input_obj.input.LD_grazing .= NaN / u"ha"
        sol = sim.solve_prob(; input_obj, p, trait_input);
        species_biomass = dropdims(mean(sol.output.biomass; dims = (:x, :y)); dims = (:x, :y))
        total_biomass = vec(sum(species_biomass; dims = :species))
        push!(tot_biomass, mean(total_biomass))
    end

    fig, _ = scatter(1:5, ustrip.(tot_biomass),
                     axis = (; xlabel = "Number of mowing events",
                               ylabel = "Mean total biomass [kg ha⁻¹]"))

    # display(fig)
    save("$dir/mowing_$iteration.png", fig)
    return nothing
end


function calibration_logplot(p, opt_obj, site_index, dir; iteration = "")
    @unpack trait_input, parameter_names, input_data, measurement_data = opt_obj

    ax_settings_left = (; width = 400, height = 150,
                        xticks = 2006:4:2022, xminorticks = 2006:1:2022,
                        topspinevisible = true,
                        rightspinevisible = true,
                        limits = (2004.5, 2023.5, nothing, nothing))

    fig = Figure()

    biomass_ax = []
    for s in eachindex(site_index)
        site = site_index[s]

        input_obj = input_data[site]
        data = measurement_data[site]
        sol = sim.solve_prob(; input_obj, p, trait_input)
        num_t = sol.simp.output_date_num
        trait_num_t = num_t[LookupArrays.index(data.traits, :time)]
        errors = error_for_one_site(; p, input_obj, trait_input, data)

        total_biomass = sum(sol.output.above_biomass[:, 1, 1, :]; dims = :species)
        biomass_date = sol.valid.biomass_cutting_numeric_date[sol.valid.cut_index]
        simulated_cut_biomass = ustrip.(sol.valid.cut_biomass)[sol.valid.cut_index]
        measured_cut_biomass = vec(data.biomass)

        ax = Axis(fig[1, s];
            ylabel = s == 1 ? "Total aboveground\nbiomass [kg ha⁻¹]" : "",
            yticklabelsvisible = s == 1 ? true : false,
            yticksvisible = s == 1 ? true : false,
            xlabel = "",
            xticklabelsvisible = false,
            xticksvisible = false,
            ax_settings_left...)

        push!(biomass_ax, ax)
        lines!(sol.simp.output_date_num, vec(ustrip.(total_biomass)))
        scatter!(biomass_date, simulated_cut_biomass)
        scatter!(biomass_date, measured_cut_biomass; color = :black)
        Label(fig[1, s], "$(Int(round(errors[1]; digits = 0)))";
            padding = (0,5,0,0), justification = :right,
            halign = :right, valign = :top)

        ##### traits
        trait_symbols = [:rsa, :abp, :sla, :maxheight, :amc, :lnc]
        trait_strings = [
            "Root surface area\nper belowground \nbiomass [m² g⁻¹]",
            "Aboveground\nbiomass per\ntotal biomass [-]",
            "Specific leaf\narea [m² g⁻¹]",
            "Maximum\nheight [m]",
            "Arbuscular\nmycorrhizal\ncolonisation [-]",
            "Leaf nitrogen per\nleaf mass [mg g⁻¹]"
        ]
        my_yticks = [0.1:0.1:0.3, 0.5:0.1:0.7, 0.005:0.005:0.015,
        0.5:0.5:2.0, 0.2:0.2:0.6, 10:10:40]

        trait_labels = (; zip(trait_symbols, trait_strings)...)

        data_trait_t = LookupArrays.index(data.traits, :time)
        species_biomass = dropdims(mean(@view sol.output.biomass[data_trait_t, :, :, :];
                                        dims = (:x, :y)); dims = (:x, :y))
        species_biomass = ustrip.(species_biomass)
        site_biomass = vec(sum(species_biomass; dims = (:species)))

        species_biomass_all = dropdims(mean(sol.output.biomass;
                                            dims = (:x, :y)); dims = (:x, :y))
        species_biomass_all = ustrip.(species_biomass_all)
        site_biomass_all = vec(sum(species_biomass_all; dims = (:species)))

        ntraits = length(trait_symbols)

        relative_biomass = species_biomass ./ site_biomass
        relative_biomass_all = species_biomass_all ./ site_biomass_all

        for (i,trait_symbol) in enumerate(trait_symbols)
            ## simulated cwmCWM
            trait_vals = ustrip.(sol.traits[trait_symbol])
            weighted_trait = trait_vals .* relative_biomass'
            sim_cwm_trait = vec(sum(weighted_trait; dims = 1))

            ## simulated cwm timeseries
            weighted_trait_all = trait_vals .* relative_biomass_all'
            sim_cwm_trait_all = vec(sum(weighted_trait_all; dims = 1))

            ## calculated cwm from observed vegetation
            measured_cwm = vec(data.traits[trait = At(trait_symbol)])

            ## trait input
            input_trait_vals = ustrip.(trait_input[trait_symbol])
            min_val = minimum(input_trait_vals)
            max_val = maximum(input_trait_vals)

            Axis(fig[1+i, s];
                ylabel = s == 1 ? trait_labels[trait_symbol] : "",
                yticks = my_yticks[i],
                yticklabelsvisible = s == 1 ? true : false,
                yticksvisible = s == 1 ? true : false,
                xlabel = i == 6 ? "Time [year]" : "",
                limits = (nothing, nothing, min_val, max_val),
                xticksvisible = i == 6 ? true : false,
                xticklabelsvisible = i == 6 ? true : false,
                xminorticksvisible = i == 6 ? true : false,
                ax_settings_left...)
            hlines!(input_trait_vals; color = (:black, 0.07))

            lines!(num_t, sim_cwm_trait_all)
            scatter!(trait_num_t, measured_cwm; color = :black)

            trait_err_digits = i == 6 ? 1 : 3
            Label(fig[1+i, s], "$(round(errors[i+1]; digits = trait_err_digits))";
                  padding = (0,5,0,0), justification = :right,
                  halign = :right, valign = :top)

        end
    end

    for (i, label) in enumerate(["Calibration site: $(site_index[1])",
                                 "Calibration site: $(site_index[2])"])
        Box(fig[0, i], color = :gray90, height = 30)
        Label(fig[0, i], label)
    end

    linkaxes!(biomass_ax...)
    [rowgap!(fig.layout, i, 0) for i in 1:7]
    colgap!(fig.layout, 1, 0)

    resize_to_layout!(fig)
    # display(fig)
    save("$dir/calibration_$iteration.png", fig)
    return nothing
end
