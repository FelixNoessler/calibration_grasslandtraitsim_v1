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
using PrettyTables
using DataFrames
using JLD2

includet("0_plot_functions.jl")
includet("0_error_functions.jl")
includet("0_calibration_object.jl")
includet("validation_paper_figure.jl")


be_valid = BE_optimization(all_sites = true)

out_dir = "calibration_results/"
website_img_dir = "docs/img"
opt = load("$out_dir/opt.jld2")["opt"];

### weighting objectives
ws = fill(0.5 / 6, 7)
ws[1] = 0.5
my_dm = mcdm(opt, ws, TopsisMethod());
p_optimized = prepare_p(opt.population[my_dm.bestIndex].x, be_valid.parameter_names)
p = solution(opt, be_valid)

## should be true
all(be_valid.parameter_names .== String.(collect(keys(p_optimized))))

### write to file: fixed parameter
open("$out_dir/0_optimized_parameter.txt", "w") do f
    pretty_table(f, [be_valid.parameter_names be_valid.lb  collect(p_optimized) be_valid.ub];
        header = ["Parameter", "Lower bound",  "optimized value", "Upper bound"])
end

### write to file: fixed parameter
open("$out_dir/0_fixed_parameter.txt", "w") do f
    pretty_table(f, [String.(collect(keys(be_valid.fixed_parameter))) collect(be_valid.fixed_parameter)];
                 header = ["Parameter", "Value"])
end

### update calibrated parameters for GrasslandTraitSim.jl package
θ = prepare_p(opt.population[my_dm.bestIndex].x, be_valid.parameter_names)
jldsave(sim.assetpath("data/optim.jld2"); θ = merge(θ, be_valid.fixed_parameter))

### plot the validation with the worst and best score for cut aboveground biomass
diff_sites = error_for_sites(be_valid, opt.population[my_dm.bestIndex].x;
                             calc_all_sites = true)
ntrain = length(be_valid.BE_IDs_train)
biomass_diff_test = diff_sites[ntrain+1:end, 1]
best_site = be_valid.BE_IDs_test[sortperm(biomass_diff_test)[1]]
worst_site = be_valid.BE_IDs_test[sortperm(biomass_diff_test)[end]]
plot_two_site_paper(p, be_valid, [Symbol(best_site), Symbol(worst_site)], out_dir)

### plot the best n parameters of the population with colour according to the score
### that takes into account the weights of the objectives
## the images will be visible on the website
let
    selected_opt = opt
    pos = positions(selected_opt)
    my_dm = mcdm(selected_opt, ws, TopsisMethod());
    scores = float.(my_dm.scores)
    scores_sort = sortperm(scores, rev = true)
    scores = scores[scores_sort]
    pos = pos[scores_sort, :]
    ncombinations = 25

    for p in Symbol.(be_valid.BE_IDs)
        @info "Plotting site $(p)"

        f = plot_one_site_several_p(pos[1:ncombinations, :], scores[1:ncombinations],
            be_valid, p)
        save("$website_img_dir/calibration/$(p).png", f)
    end
end
