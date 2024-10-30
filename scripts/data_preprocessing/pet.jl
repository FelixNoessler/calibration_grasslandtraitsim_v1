import CSV, Dates
using DataFrames, DataFramesMeta


function load_soil(path)
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
        "pet_164.txt.gz",
        "pet_3402.txt.gz",
        "pet_6305.txt.gz",
    ]
    station = [
        "Angermünde",
        "Münsingen-Apfelstetten",
        "Eisenach",
    ]
    explo = ["SCH", "ALB", "HAI"]

    final_df = DataFrame()

    for i in 1:3
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

    return final_df
end

function load_PET_input(path; years)
    df = load_soil(path)

    @chain df begin
        @subset :year .∈ Ref(years)
        @rename :PET = :VPGB
        @select :explo :date :year :PET
        @orderby :date
    end
end


data_path = "../data/"
load_PET_input(data_path; years = 2006:2022) |> CSV.write("pet.csv")
