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
        @subset startswith.(:plotID, "H")
        @select :plotID :date :biomass :cutting_height
    end

    return final_df
end


let
    data_path = "../Raw_data/BE/"

    df = core_biomass(data_path)
    df = @orderby df :plotID :date
    disallowmissing!(df)

    biomass_file = "../Calibration_data/Biomass.csv"

    # @info "$biomass_file"
    CSV.write(biomass_file, df)
    df
end
