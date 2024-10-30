function plot_two_site_paper(p, opt_obj, site_index, dir)
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
        0.25:0.25:1.25, 0.2:0.2:0.6, 10:10:40]

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

            lines!(sol.simp.output_date_num, sim_cwm_trait_all)
            scatter!(to_numeric.(data.fun_diversity.date), measured_cwm; color = :black)

            trait_err_digits = i == 6 ? 1 : 3
            Label(fig[1+i, s], "$(round(errors[i+1]; digits = trait_err_digits))";
                  padding = (0,5,0,0), justification = :right,
                  halign = :right, valign = :top)

        end
    end

    for (i, label) in enumerate(["Validation site: $(site_index[1])",
                                 "Validation site: $(site_index[2])"])
        Box(fig[0, i], color = :gray90, height = 30)
        Label(fig[0, i], label)
    end

    linkaxes!(biomass_ax...)
    [rowgap!(fig.layout, i, 0) for i in 1:7]
    colgap!(fig.layout, 1, 0)

    resize_to_layout!(fig)

    save("$dir/validation.pdf", fig)
    display(fig)
end
