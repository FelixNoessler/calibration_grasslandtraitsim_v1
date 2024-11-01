import GrasslandTraitSim as sim
using Accessors
using Unitful
using UnPack
using Metaheuristics
using DimensionalData
using Statistics
using CairoMakie
using JMcDM
import Dates
using PairPlots
using DataFrames
using JLD2
using RCall

includet("0_plot_functions.jl")
includet("0_error_functions.jl")
includet("0_calibration_object.jl")

website_img_dir = "docs/img"
out_dir = "calibration_results/"
be_valid = BE_optimization(all_sites = true)
opt = load("$out_dir/opt.jld2")["opt"];
p = solution(opt, be_valid)

################ Calculate functional diversity in R
function traits_to_matrix(trait_data; std_traits = true)
    trait_names = keys(trait_data)
    ntraits = length(trait_names)
    nspecies = length(trait_data[trait_names[1]])
    m = Matrix{Float64}(undef, nspecies, ntraits)

    for i in eachindex(trait_names)
        tdat = trait_data[trait_names[i]]
        if std_traits
            m[:, i] = (tdat .- mean(tdat)) ./ std(tdat)
        else
            m[:, i] = ustrip.(tdat)
        end
    end

    return m
end

function calc_disp_eve(trait_mat, biomass;)
    biomass_R = ustrip.(biomass.data)
    traits_R = trait_mat

    site_names = string.("time_", 1:size(biomass_R, 1))
    species_names = string.("species_", 1:size(biomass_R, 2))

    ## transfer data to R
    @rput species_names site_names traits_R biomass_R

    R"""
    library(fundiversity)

    rownames(traits_R) <- species_names
    rownames(biomass_R) <- site_names
    colnames(biomass_R) <- species_names

    fdis_R <- fd_fdis(traits_R, biomass_R)$FDis
    feve_R <- fd_feve(traits_R, biomass_R)$FEve
    """

    ## get results back from R
    @rget fdis_R feve_R

    return mean(fdis_R), mean(feve_R)
end

############################# Run one simulation
function run_sim(opt_obj; p, plotID, nmowing = 0, grazing_i = 0)
    @unpack trait_input, input_data = opt_obj

    input_obj = input_data[plotID]

    date = input_obj.simp.mean_input_date
    ntimesteps = length(date)

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

    @reset input_obj.input.CUT_mowing = mowing

    ################## grazing
    grazing = fill(NaN / u"ha", ntimesteps)
    grazing_starts = Dates.Date.(2006:2021, 5, 1)
    grazing_ends = Dates.Date.(2006:2021, 8, 1)

    if grazing_i > 0
        livestock_density = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0][grazing_i] * u"ha^-1"

        for i in eachindex(grazing_starts)
            r = grazing_starts[i] .<= date .<= grazing_ends[i]
            grazing[r] .= livestock_density
        end
    end

    @reset input_obj.input.LD_grazing = grazing

    return sol = sim.solve_prob(; input_obj, p, trait_input);
end

function scenario_results(sol, trait_matrix)
    results = Float64[]

    ### aboveground biomass
    aboveground_biomass = sol.output.above_biomass[end÷2:end, 1, 1, :]
    mean_standing_biomass = mean(sum(aboveground_biomass; dims = :species); dims = :time)[1,1]
    push!(results, ustrip(mean_standing_biomass))

    ### belowground biomass
    belowground_biomass = sol.output.below_biomass[end÷2:end, 1, 1, :]
    mean_below_biomass = mean(sum(belowground_biomass; dims = :species); dims = :time)[1,1]
    push!(results, ustrip(mean_below_biomass))

    ### grazed/mown biomass, divide by 8 to get yearly values
    removed_biomass = sol.output.grazed[end÷2:end, 1, 1, :] .+ sol.output.mown[end÷2:end, 1, 1, :]
    sum_removed_biomass = sum(removed_biomass; dims = (:time, :species))[1,1]
    push!(results, ustrip(sum_removed_biomass) / 8)

    ### height
    height = sol.output.height[end÷2:end, 1, 1, :]
    species_biomass = sol.output.biomass[end÷2:end, 1, 1, :]
    total_biomass = vec(sum(species_biomass; dims = :species))
    relative_biomass = species_biomass ./ total_biomass
    height_weighted = height .* relative_biomass
    height_sum = vec(sum(height_weighted; dims = :species))
    mean_height = mean(height_sum)
    push!(results, ustrip(mean_height))

    ### functional diversity
    disp, eve = calc_disp_eve(trait_matrix, sol.output.biomass[end÷2:30:end, 1, 1, :])
    push!(results, disp)
    push!(results, eve)

    ### community weighted mean traits
    traits = [:maxheight, :sla, :lnc, :abp, :rsa, :amc]

    for i in eachindex(traits)
        trait_vals = sol.traits[traits[i]]
        weighted_trait = trait_vals .* relative_biomass'
        cwm_trait = vec(sum(weighted_trait; dims = 1))
        change =  mean(ustrip.(cwm_trait))
        push!(results, change)
    end

    return results
end

trait_input_wo_lbp = Base.structdiff(sim.input_traits(), (; lbp = nothing))
trait_matrix = traits_to_matrix(trait_input_wo_lbp;)

plotIDs = Symbol.(be_valid.BE_IDs)
result_mowing = Array{Float64}(undef, 12, 5, length(plotIDs))

@info "Start: mowing scenarios"
for i in eachindex(plotIDs)
    @info plotIDs[i]
    for m in 1:5
        sol = run_sim(be_valid; p, plotID = plotIDs[i], nmowing = m, grazing_i = 0);
        result_mowing[:, m, i] = scenario_results(sol, trait_matrix)
    end
end

@info "Start: grazing scenarios"
result_grazing = Array{Float64, 3}(undef, 12, 8, length(plotIDs))
for i in eachindex(plotIDs)
    @info plotIDs[i]
    for g in 1:8
        sol = run_sim(be_valid; p, plotID = plotIDs[i], nmowing = 0, grazing_i = g);
        result_grazing[:, g, i] = scenario_results(sol, trait_matrix)
    end
end


begin
    axes_labels = [
        "Aboveground\nbiomass [kg ha⁻¹]",
        "Belowground\nbiomass [kg ha⁻¹]",
        "Yearly grazed or\nmown biomass\n[kg ha⁻¹]",
        "Height [m]",
        "Functional\ndispersion [-]",
        "Functional\neveness [-]"
    ]

    first_ax = 1
    last_ax = 6

    fig = Figure(;)

    myaxes = []
    for t in first_ax:last_ax
        ax = Axis(fig[t, 1]; xticksvisible = t == last_ax ? true : false,
            xticklabelsvisible = t == last_ax ? true : false,
            yticks = Makie.LinearTicks(4),
            width = 400, height = 150,
            xticks = 1:5,
            ylabel = axes_labels[t],
            xlabel = t == last_ax ? "Number of mowing events per year [-]" : "",
            limits = (0.5, 5.5, nothing, nothing))
        push!(myaxes, ax)
        m = vec(mean(result_mowing[t, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for i in 1:5
                scatter!(i, result_mowing[t, i, p];
                         color = (:dodgerblue4, 0.3))
            end
        end
        lines!(1:5, m; color = (:black, 1))
    end

    for t in first_ax:last_ax
        ax = Axis(fig[t, 2];
            yticklabelsvisible = false, yticksvisible = false,
            rightspinevisible = true,
            width = 400, height = 150,
            yticks = Makie.LinearTicks(4),
            xticksvisible = t == last_ax ? true : false,
            xticklabelsvisible = t == last_ax ? true : false,
            xticks = 1:4,
            xminorticks = 0.5:0.5:4.0,
            xminorticksvisible = t == last_ax ? true : false,
            xlabel = t == last_ax ? "Grazing intensity May-August [LD ha⁻¹ d⁻¹]" : "",
            limits = (0.2, 4.5, nothing, nothing))

        graz_int = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
        m = vec(mean(result_grazing[t, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for g in 1:8
                scatter!(graz_int[g], result_grazing[t, g, p];
                         color = (:dodgerblue4, 0.3))
            end
        end
        lines!(0.5:0.5:4.0, m; color = (:black, 1))

        linkyaxes!(myaxes[t], ax)
    end

    for (i, label) in enumerate(["Mowing only", "Grazing only"])
        Box(fig[0, i], color = :gray90, height = 30)
        Label(fig[0, i], label)
    end
    colgap!(fig.layout, 1, 0)
    [rowgap!(fig.layout, i, 0) for i in 1:last_ax]

    resize_to_layout!(fig)

    display(fig)

    save("$out_dir/scenario_analysis1.pdf", fig)
end

begin
    traits = [:maxheight, :sla, :lnc, :abp, :rsa, :amc]
    axes_labels = [
        "Maximum\nheight [m]",
        "Specific leaf\narea [m² g⁻¹]",
        "Leaf nitrogen\nper leaf mass [mg g⁻¹]",
        "Aboveground\nbiomass per\ntotal biomass [-]",
        "Root surface area\nper belowground\nbiomass [m² g⁻¹]",
        "Arbuscular\nmycorrhizal\ncolonisation [-]",
    ]

    first_ax = 1
    last_ax = 6

    fig = Figure(;)

    myaxes = []
    for t in first_ax:last_ax
        ax = Axis(fig[t, 1]; xticksvisible = t == last_ax ? true : false,
                  xticklabelsvisible = t == last_ax ? true : false,
                  yticks = Makie.LinearTicks(4),
                  width = 400, height = 150,
                  xticks = 1:5,
                  ylabel = axes_labels[t],
                  xlabel = t == last_ax ? "Number of mowing events per year [-]" : "",
                  limits = (0.5, 5.5, nothing, nothing))
        push!(myaxes, ax)
        m = vec(mean(result_mowing[t+6, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for i in 1:5
                scatter!(i, result_mowing[t+6, i, p];
                         color = (:dodgerblue4, 0.3))
            end
        end
        lines!(1:5, m; color = (:black, 1))
    end

    for t in first_ax:last_ax
        ax = Axis(fig[t, 2];
                  yticklabelsvisible = false, yticksvisible = false,
                  rightspinevisible = true,
                  width = 400, height = 150,
                  xticksvisible = t == last_ax ? true : false,
                  xticklabelsvisible = t == last_ax ? true : false,
                  xticks = 1:4,
                  xminorticks = 0.5:0.5:4.0,
                  xminorticksvisible = t == last_ax ? true : false,
                  xlabel = t == last_ax ? "Grazing intensity May-August [LD ha⁻¹ d⁻¹]" : "",
                  limits = (0.2, 4.5, nothing, nothing))

        graz_int = [0.5, 1.0, 1.5, 2.0, 2.5, 3.0, 3.5, 4.0]
        m = vec(mean(result_grazing[t+6, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for g in 1:8
                scatter!(graz_int[g], result_grazing[t+6, g, p];
                         color = (:dodgerblue4, 0.3))
            end
        end
        lines!(0.5:0.5:4.0, m; color = (:black, 1))
        linkyaxes!(myaxes[t], ax)
    end

    for (i, label) in enumerate(["Mowing only", "Grazing only"])
        Box(fig[0, i], color = :gray90, height = 30)
        Label(fig[0, i], label)
    end
    colgap!(fig.layout, 1, 0)
    [rowgap!(fig.layout, i, 0) for i in 1:6]

    resize_to_layout!(fig)

    display(fig)

    save("$out_dir/scenario_analysis2.pdf", fig)
end


#### Results on sites
let
    traits = [:maxheight, :sla, :lnc, :abp, :rsa, :amc]
    axes_labels = [
        "Maximum height [m]",
        "Specific leaf\narea [m² g⁻¹]",
        "Leaf nitrogen\nper leaf mass [mg g⁻¹]",
        "Aboveground\nbiomass per\ntotal biomass [-]",
        "Root surface area\nper belowground\nbiomass [m² g⁻¹]",
        "Arbuscular\nmycorrhizal\ncolonisation [-]",
    ]

    landuse = [1:5, 1:8]
    f = x -> 40 .* sqrt.((x)./π)
    trait_vals = sim.input_traits()
    nspecies = length(trait_vals[:maxheight])

    for i in eachindex(plotIDs)
        @info plotIDs[i]
        fig = Figure()
        for axi in 1:2

            mean_rel_biomass = zeros(length(landuse[axi]), nspecies)
            for l in landuse[axi]
                sol = run_sim(be_valid; p, plotID = plotIDs[i],
                    nmowing = axi == 1 ? l : 0,
                    grazing_i = axi == 2 ? l : 0);
                relative_biomass = sol.output.biomass[end÷2:end, 1, 1, :] ./ sum(sol.output.biomass[end÷2:end, 1, 1, :]; dims = :species)
                mean_rel_biomass[l, :] = vec(mean(relative_biomass; dims = :time))
            end

            for t in eachindex(traits)
                selected_trait = ustrip.(trait_vals[traits[t]])
                maxt = 1.1 * maximum(selected_trait)
                mint = traits[t] == :maxheight ? 0.0 : nothing
                Axis(fig[t+2, axi];
                    topspinevisible = true,
                    rightspinevisible = true,
                    ygridvisible = true,
                    xticklabelsvisible = t == length(traits) ?  true : false,
                    xticksvisible = t == length(traits) ?  true : false,
                    xlabel = axi == 1 ? "Number of mowing events per year [-]" : "Grazing intensity May-August [LD ha⁻¹ d⁻¹]",
                    xlabelvisible = t == length(traits) ?  true : false,
                    ylabel = axi == 1 ? axes_labels[t] : "",
                    yticklabelsvisible = axi == 1 ? true : false,
                    yticksvisible = axi == 1 ? true : false,
                    xticks = axi == 1 ? [1,2,3,4,5] : ([2,4,6,8], ["1", "2", "3", "4"]),
                    xminorticksvisible = axi == 2 && t == length(traits) ? true : false,
                    limits = axi == 1 ? (0.52, 5.48, mint, maxt) : (0.52, 8.48, mint, maxt),
                    width = 400, height = 150,
                    yticks = LinearTicks(3))

                for l in landuse[axi]
                    scatter!(fill(l, length(trait_vals[t])), selected_trait;
                        markersize = f(mean_rel_biomass[l, :]),
                        color = (:steelblue, 0.7))
                end
            end
        end

        ms1 = [MarkerElement(color = (:steelblue, 0.7) , markersize = f(s), marker = '●') for s in [0.1, 0.3, 0.5, 0.7, 0.9]]
        ls1 = string.([0.1, 0.3, 0.5, 0.7, 0.9])

        is_train = String(plotIDs[i]) ∈ be_valid.BE_IDs_train
        sitetype_label = is_train ? "calibration" : "validation"
        Label(fig[1, 1], "$(plotIDs[i]) ($sitetype_label)";
              tellwidth = false, font = :bold)
        Legend(fig[1, 2], ms1, ls1, "Relative biomass contribution";
            tellwidth = false, orientation = :horizontal, nbanks = 1)

        for (i, label) in enumerate(["Mowing only", "Grazing only"])
            Box(fig[2, i], color = :gray90, height = 30)
            Label(fig[2, i], label)
        end

        colgap!(fig.layout, 1, 0)
        [rowgap!(fig.layout, i+1, 0) for i in 1:length(traits)]

        resize_to_layout!(fig)

        save("$website_img_dir/scenario/$(plotIDs[i]).png", fig)
        display(fig)
    end
end
