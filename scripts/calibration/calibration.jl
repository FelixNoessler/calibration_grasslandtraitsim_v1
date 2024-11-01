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
using PrettyTables
using DataFrames
using JLD2

includet("0_error_functions.jl")
includet("0_calibration_object.jl")
includet("0_logger_plots.jl")

function run_optimization(opt_obj, function_calls = 200, time_limit_seconds = Inf;
                          X0 = nothing, tmp_location = "")
    bounds = BoxConstrainedSpace(lb = opt_obj.lb, ub = opt_obj.ub)
    options = Options(f_calls_limit = function_calls,
                      time_limit = float(time_limit_seconds),
                      parallel_evaluation = true,
                      store_convergence = true,
                      verbose = true,
                      iterations = 5000);

    function f(x)
        fx = total_error(opt_obj, x)
        return fx, [0.0], [0.0]
    end

    function f_parallel(X)
        N = size(X,1)
        nobjectives = 7
        fx, gx, hx = zeros(N,nobjectives), zeros(N,1), zeros(N,1)
        Threads.@threads for i in 1:N
            fx[i,:], gx[i,:], hx[i,:] = f(X[i,:])
        end
        fx, gx, hx
    end

    algo = NSGA2(; options, N = 10 * length(opt_obj.lb))
    if !isnothing(X0)
        set_user_solutions!(algo, X0, f);
    end

    logger(st) = begin
        if iszero(st.iteration % 5)
            p = solution(st, opt_obj)
            print(p)
            iteration_str = lpad(st.iteration, 4, "0")
            calibration_logplot(p, opt_obj, [:HEG05, :HEG06], tmp_location,
                                iteration = iteration_str)
            standing_biomass_mowing(p, opt_obj, :HEG05, tmp_location; iteration = iteration_str)
            jldsave("$tmp_location/opt_$iteration_str.jld2"; opt=st)
        end
    end

    optimize(f_parallel, bounds, Restart(algo, every=200); logger)
end

out_dir = "calibration_results/test"
mkpath(out_dir)
mkpath("$out_dir/calibration_tmp")

be_opt = BE_optimization(;);
@info "Start with the calibration"
opt = run_optimization(be_opt, 1.0e20, 10 * 60;
                       tmp_location = "$out_dir/calibration_tmp")

jldsave("$out_dir/opt.jld2"; opt)
@info "Saved optimization in $out_dir"
