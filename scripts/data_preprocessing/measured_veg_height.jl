import CSV, Dates
using DataFrames, DataFramesMeta
using Statistics

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head = 3, tail = 0)
    b = lpad(b, 2, "0")
    return a * b
end

function core_height(path)
    datasets = [
        "vegetation_2012.csv"
        "biomass_2013.csv"
        "biomass_2014.csv"
        "vegetation_2015.csv"
        "biomass_2016.csv"
        "biomass_2017.csv"
        "biomass_2018.csv"
        "biomass_2019.csv"
        "biomass_2020.csv"
        "biomass_2021.csv"
        "biomass_2022.csv"
    ]

    id_cols = [
        fill(:EpPlotID, 6)...
        fill(:Ep_PlotID, 4)...
        "EP.PlotID"
    ]
    date_cols = [
        fill(:date, 2)...
        fill(:date_new, 4)...
        fill(:date_bm, 4)...
        "date.bm"
    ]

    veg_height = [
        fill([:v_height_1_cm, :v_height_2_cm,
              :v_height_3_cm, :v_height_4_cm], 2)...,
        fill([:vegetation_height_mean_cm, :height_missing,
              :height_missing, :height_missing], 7)...,
        [:vegetation_height_mean_cm_1, :vegetation_height_mean_cm_2,
         :height_missing, :height_missing],
        ["vegetation.height.1", "vegetation.height.2", :height_missing, :height_missing]
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

        df[!, :height_missing] .= NaN

        df = @chain df begin
            @transform begin
                :plotID = convert_id.($(id_cols[i]))
                :height1 = $(veg_height[i][1])
                :height2 = $(veg_height[i][2])
                :height3 = $(veg_height[i][3])
                :height4 = $(veg_height[i][4])
            end
            @rename :date = $(date_cols[i])
            @orderby :date
            @select :plotID :date :height1 :height2 :height3 :height4
        end

        unique!(df, [:plotID, :date])

        push!(dfs, df)
    end

    concat_dfs = vcat(dfs...)

    final_df = @chain stack(concat_dfs, [:height1, :height2, :height3, :height4]) begin
        @rsubset !isnan(:value) & !ismissing(:date)
        @transform :height = round.(:value ./ 100; digits = 3)
        @orderby :plotID :date
        @select :plotID :date :height
    end

    disallowmissing!(final_df)

    return final_df
end


let
    path = "../data/"
    df = core_height(path)
    output_path = "measured_height.csv"

    # move to assets/data/validation
    CSV.write(output_path, df)
    df
end
