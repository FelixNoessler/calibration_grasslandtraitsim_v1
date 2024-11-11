import CSV, Dates
using DataFrames, DataFramesMeta
using Statistics
using DataFrames, DataFramesMeta
using CairoMakie
using Polynomials
using Statistics
using Unitful

import CSV
import Dates

function load_PAR(path; startyear = 2006, endyear = 2022, show_plot = false)
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
        @subset :explo .== "HAI"
        @rename :t = :date
        @select :t :PAR
    end

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


function load_PET(path; years = 2006:2022)
    # https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/historical/
    # 164 - Angermünde = SCH
    # 3402 - Münsingen-Apfelstetten = ALB
    # 6305 - Mühlhausen = HAI

    # VPGB - potential evapotranspiration over gras (AMBAV)
    # BF10 - soil moisture under grass and sandy loam
    #        between 0 and 10 cm depth in % plant useable water
    # BFGSL - soil mosture under grass and sandy loam up to 60
    #         cm depth (AMBAV)

    fs = [
        "DWD_PET_6305.txt.gz",
    ]
    station = [
        "Eisenach",
    ]
    explo = ["HAI"]

    final_df = DataFrame()

    for i in eachindex(fs)
        p = joinpath(path, fs[i])
        df = CSV.read(p,
            DataFrame;
            dateformat = "yyyymmdd",
            types = Dict(:Datum => Dates.Date))
        df_transformed = @chain df begin
            @select(:Stationsindex, :Datum, :VPGB, :BF10, :BFGSL)
            @transform(
                :weather_station=station[i],
                :doy=Dates.dayofyear.(:Datum),
                :year=Dates.year.(:Datum),
                :explo=explo[i])
            @select(
                :explo,
                :weather_station,
                :weather_station_index=:Stationsindex,
                :date=:Datum,
                :year,
                :doy,
                :VPGB,
                :BF10,
                :BFGSL)
        end
        final_df = vcat(final_df, df_transformed)

    end

    @chain final_df begin
        @subset :year .∈ Ref(years)
        @rename :PET = :VPGB
        @subset :explo .== "HAI"
        @rename :t = :date
        @select :t :PET
        @orderby :t
    end
end

function load_temperature_precipiation_DWD(path; startyear = 2006, endyear = 2008)
    df = CSV.read(path, DataFrame;
                  types = Dict(2 => Dates.Date),
                  dateformat="yyyymmdd",
                  missingstring = "-999",
                  delim = ";",
                  stripwhitespace=true)

    # TMK mean temperature of the air at 2m in °C
    # RSK sum of precipitation in mm

    df_sub = @chain df begin
        @rename begin
            :dwd_stations_id = :STATIONS_ID
            :t = :MESS_DATUM
            :temperature = :TMK
            :precipitation = :RSK
        end
        @subset endyear .>= Dates.year.(:t) .>= startyear
        @select :t :temperature :precipitation
    end
    disallowmissing!(df_sub)

    return df_sub
end

function load_temperature_precipiation_BE(path)
    df = CSV.read(path * "climate/plots.csv",
        DataFrame,
        missingstring = ["NA"],
        dateformat = "dd/mm/yyyy",)
    df.explo = first.(df.plotID)

    median_temp = @chain df begin
        @subset .!ismissing.(:Ta_200)
        groupby(_, [:explo, :datetime])
        @combine :median_Ta_200 = median(:Ta_200)
    end

    df_sub = @chain df begin
        leftjoin(_, median_temp, on = [:explo, :datetime])
        @rtransform :precipitation = ismissing(:P_RT_NRT) ? :precipitation_radolan : :P_RT_NRT

        ## just for the day 2020-02-06
        @rtransform :precipitation = ismissing(:precipitation) ? 0.0 : :precipitation

        @rtransform :Ta_200 = ismissing(:Ta_200) ? :median_Ta_200 : :Ta_200
        @rename begin
            :t = :datetime
            :temperature = :Ta_200
        end
        @transform begin
            :year = Dates.year.(:t)
            :temperature = round.(:temperature, digits = 1)
            :precipitation = round.(:precipitation, digits = 1)
        end
        @subset 2009 .<= :year .<= 2022
        @orderby :t
        @subset startswith.(:plotID, "H")
        @select :plotID :t :temperature :precipitation
    end
    disallowmissing!(df_sub)
    return df_sub
end


data_path = "../Raw_data/"

function cumulative_temperature(temperature, years)
    temperature_sum = []
    temperature = deepcopy(temperature)
    temperature[temperature .< 0] .= 0

    for y in unique(years)
        year_filter = y .== years
        append!(temperature_sum, cumsum(temperature[year_filter]))
    end

    return temperature_sum
end

function load_climate(path)
    temp1_df = load_temperature_precipiation_DWD(path * "DWD_temperature_precipitation_6305.csv")
    temp2_df = load_temperature_precipiation_BE(path * "BE/")

    startyear = 2006
    endyear = 2022
    days = Dates.Date(startyear):Dates.lastdayofyear(Dates.Date(endyear))
    plotIDs = unique(temp2_df.plotID)

    df = crossjoin(DataFrame(t = collect(days)), DataFrame(plotID = collect(plotIDs)))

    df = @chain df begin
        leftjoin(_, temp1_df, on = [:t])
        leftjoin(_, temp2_df, on = [:t, :plotID], makeunique = true)
        @rtransform :temperature = ismissing(:temperature) ? :temperature_1 : :temperature
        @rtransform :precipitation = ismissing(:precipitation) ? :precipitation_1 : :precipitation
        @orderby :t
        @transform :temperature_sum = NaN
    end

    for p in plotIDs
        f = p .== df.plotID
        df[f, :temperature_sum] = cumulative_temperature(df[f, :temperature], Dates.year.(df[f, :t]))
    end

    df = @chain df begin
        @transform :x = 1
        @transform :y = 1
        leftjoin(_, load_PET(path), on = :t)
        leftjoin(_, load_PAR(path), on = :t)
        @orderby :plotID :t
        @select :temperature :temperature_sum :precipitation :PET :PAR :t :x :y :plotID
    end
    disallowmissing!(df)

    return df
end

df_climate = load_climate("../Raw_data/")
CSV.write("../Input_data/Climate.csv", df_climate)
