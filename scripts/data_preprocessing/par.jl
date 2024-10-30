using DataFrames, DataFramesMeta
using CairoMakie
using Polynomials
using Statistics
using Unitful

import CSV
import Dates

function PAR_data(path; startyear = 2006, endyear = 2022, show_plot = false)
    df_input = CSV.read(path * "PAR_2006_2022.csv", DataFrame; missingstring = "-1")
    @select! df_input $(r"^PAR") :plot_id :date

    df = @chain df_input begin
        @transform :PAR = daily_PAR_sum(df_input; show_plot)
        @rename :explo = :plot_id
        @select :date :explo :PAR
    end
    date_range = Dates.Date(startyear):Dates.lastdayofyear(Dates.Date(endyear))
    df_prep = DataFrame(date = repeat(date_range, 3),
        explo = repeat(["HAI", "ALB", "SCH"], inner = length(date_range)))
    df_prep.doy = Dates.dayofyear.(df_prep.date)
    df_prep.year = Dates.year.(df_prep.date)

    df_final = leftjoin(df_prep, df, on = [:date, :explo])

    df_median = @chain df_final begin
        @subset .!ismissing.(:PAR)
        groupby(_, :doy)
        @combine :PAR_median = median(:PAR)
    end

    df = @chain df_final begin
        leftjoin(_, df_median, on = :doy)
        @rtransform :PAR = ismissing(:PAR) ? :PAR_median : :PAR
        @transform :PAR = uconvert.(u"MJ / ha / d", :PAR)
        @transform :PAR = convert.(Int64, round.(ustrip.(:PAR), digits = 0))
        @transform :year = Dates.year.(:date)
        @orderby :date
        @select :date :year :explo :PAR
    end

    CSV.write("par.csv", df)

    return df
end

function daily_PAR_sum(df; show_plot)
    PAR_sum = Quantity{Float64}[]

    for n in 1:nrow(df)
        if show_plot
            plot_par_sum_approximation(df, n)
        end

        area = area_under_curve(Array(df[n, 1:8]))

        push!(PAR_sum, area)
    end

    return PAR_sum
end


function area_under_curve(PAR_measures; return_polygon = false)
    hours = collect(0:3.0:21)
    number_positive = PAR_measures .> 0

    left_no_par = findfirst(PAR_measures .!= 0) -1
    right_no_par = findfirst(PAR_measures[4:end] .== 0) + 3
    f = left_no_par:right_no_par
    p = Polynomials.fit(hours[f], PAR_measures[f], 2)

    ##### Integral
    roots_par = roots(p)
    p1 = integrate(p)
    F_a = p1(roots_par[1])
    F_b = p1(roots_par[2])
    area = (F_b - F_a) / 1e6 * 60^2

    ##### 2nd option: Riemann sum, 1 s -> polynomial interpolation
    # tpoints = uconvert.(u"hr", collect(1.0:60*60*24) * u"s") / u"hr"
    # polygon_y = p.(tpoints)
    # area1 = sum(polygon_y[polygon_y .> 0]) / 1e6

    ##### 3rd option: Riemann sum 3 hours -> no interpolation
    # manual_m = sum(PAR_measures .* 10800) / 1e6

    if return_polygon
        return p
    else
        return area .* u"MJ / m^2 / d"
    end
end

function plot_par_sum_approximation(df, n)
    hours = 0:3:21
    PAR_measures = Array(df[n, 1:8])
    orig_measures = copy(PAR_measures)

    p = area_under_curve(PAR_measures;
        return_polygon = true)

    fig = Figure()
    Axis(fig[1, 1])


    t = collect(0:0.001:24)
    pred = p.(t)
    pred_filter = pred .> 0

    lines!(t[pred_filter], pred[pred_filter])
    band!(t[pred_filter], 0, pred[pred_filter];
        color = (:blue, 0.2))
    scatter!(hours, orig_measures;
        markersize = 15,
        color = :coral3)

    display(fig)

    return nothing
end


let
    path = "../data/"

    # move file to /assets/data/input
    PAR_data(path)
end
