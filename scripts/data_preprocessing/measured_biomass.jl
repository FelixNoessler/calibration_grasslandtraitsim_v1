import CSV, Dates
using DataFrames, DataFramesMeta
using Statistics

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head = 3, tail = 0)
    b = lpad(b, 2, "0")
    return a * b
end

function core_biomass(path)
    datasets1 = ["biomass_$y.csv" for y in 2009:2011]
    datasets2 = ["vegetation_header_data_$y.csv" for y in 2012:2022]
    datasets = vcat(datasets1, datasets2)

    id_cols = [
        :GpPlotID
        :PlotID
        fill(:EpPlotID, 7)...
        fill(:Ep_PlotID, 4)...
        "EP.PlotID"
    ]
    date_cols = [
        :date_new
        :Datum
        fill(:date, 3)...
        fill(:date_new, 4)...
        fill(:date_bm, 4)...
        "date.bm"
    ]
    biomass_cols = [
        [:Biomass, :biomass_missing],
        [:Biomasse, :biomass_missing],
        fill([:biomass_g, :biomass_missing], 10)...,
        [:biomass_g_1, :biomass_g_2],
        ["biomass.1", "biomass.2"]
    ]

    dfs = []
    for i in eachindex(datasets)
        df = CSV.read(path * datasets[i], DataFrame;
            missingstring = ["", "NA"])

        if !any(["Datum", "date", "date_bm", "date.bm"] .∈ Ref(names(df)))
            if "year" ∈ names(df)
                doy = df.day_of_year
                df.day_of_year[ismissing.(doy)] .= round(median(doy[.!ismissing.(doy)]))
                df.date_new = Dates.Date.(df.year) + Dates.Day.(df.day_of_year)
            elseif "Year" ∈ names(df)
                doy = df.Day_of_year
                year = df.Year
                df.date_new = Dates.Date.(year) + Dates.Day.(doy)
            end
        end

        df = @chain df begin
            @transform :plotID = convert_id.($(id_cols[i]))
            @rename :date = $(date_cols[i])

            ## extract and convert from g/m2 to kg/ha
            @transform :biomass_missing = NaN
            @transform :biomass1 = round.($(biomass_cols[i][1]) * 10)
            @transform :biomass2 = round.($(biomass_cols[i][2]) * 10)
            @transform :cutting_height = 0.04

            @orderby :date
            @select :plotID :date :biomass1 :biomass2 :cutting_height
        end

        unique!(df, [:plotID, :date])

        push!(dfs, df)
    end

    concat_dfs = vcat(dfs...)

    final_df = @chain stack(concat_dfs, [:biomass1, :biomass2]) begin
        @rsubset !isnan(:value) & !ismissing(:date)
        @rename :biomass = :value
        @transform :stat = "core"
        @select :plotID :date :biomass :cutting_height :stat
    end

    return final_df
end

function sade_biomass(path)
    datasets = ["biomass_$(y)_sade.csv" for y in [2015, 2017]]

    dfs = []
    for i in eachindex(datasets)
        df = CSV.read(path * datasets[i], DataFrame;
                    missingstring = ["", "NA"])

        df_transformed = @chain df begin
            @subset :treatment .== "control"
            @transform begin
                :plotID = convert_id.(:EpPlotID)
                :date = Dates.Date.(:year) + Dates.Day.(:day_of_year_bm)
                :biomass = round.(:biomass_g .* 10)
                :cutting_height = 0.02
            end
            @select :plotID :date :biomass :cutting_height
        end
        push!(dfs, df_transformed)
    end

    final_df = vcat(dfs...)
    @transform! final_df :stat = "sade"
    return final_df
end

function hedgeII_biomass(path)
    datasets = [
        "biomass_2017_hainich_hedgeII.csv", # Hainich 2017
        "biomass_2018_alb_hedgeII.csv"  # Alb 2018
    ]
    dates = [
        Dates.Date(2017, 05, 31),
        Dates.Date(2018, 05, 31)
    ]

    dfs = []
    for i in eachindex(datasets)
        df = CSV.read(path * datasets[i], DataFrame;
                    missingstring = ["", "NA"])
        df_transformed = @chain df begin
            @transform begin
                :date = dates[i]
                :biomass = round.(:biomass .* 250)
                :plotID = :plotname
                :cutting_height = 0.02
            end
            @rsubset !ismissing(:biomass)
            @select :plotID :date :biomass :cutting_height
        end

        disallowmissing!(df_transformed)

        push!(dfs, df_transformed)
    end

    final_df = vcat(dfs...)
    @transform! final_df :stat = "hedgeII"
    return final_df
end

function sat_biomass(path)
    df = CSV.read(path * "biomass_from_sentinel.csv", DataFrame)
    @rename! df begin
        :satellite_mean = :biomass_kg_ha
        :satellite_min = :biomass_kg_ha_min
        :satellite_max = :biomass_kg_ha_max
    end

    df_stack = stack(df, [:satellite_mean, :satellite_min, :satellite_max];
                     variable_name = :stat, value_name = :biomass)

    df_final = @chain df_stack begin
        @transform :cutting_height = 0.04
        @select :plotID :date :biomass :cutting_height :stat
    end
    return df_final
end


let
    data_path = "../data/"

    df = vcat(core_biomass(data_path), sade_biomass(data_path),
              sat_biomass(data_path), hedgeII_biomass(data_path))
    df = @orderby df :plotID :date
    disallowmissing!(df)

    biomass_file = "measured_biomass.csv"

    # @info "$biomass_file"
    CSV.write(biomass_file, df)
    df
end
