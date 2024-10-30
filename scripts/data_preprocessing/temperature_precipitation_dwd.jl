import CSV, Dates
using DataFrames, DataFramesMeta
using Statistics

function read_dwd_temp(path; startyear = 2006, endyear = 2008, explo_str)
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
            :date = :MESS_DATUM
            :temperature = :TMK
            :precipitation = :RSK
        end
        @transform :explo = explo_str
        @subset endyear .>= Dates.year.(:date) .>= startyear
        @select(:explo, :date, :temperature, :precipitation, :dwd_stations_id)
    end
    disallowmissing!(df_sub)

    return df_sub
end

data_path = "../data"
sch_path = "$data_path/temperature_precipitation_164.csv"
alb_path = "$data_path/temperature_precipitation_3402.csv"
hai_path = "$data_path/temperature_precipitation_6305.csv"

df_sch = read_dwd_temp(sch_path; explo_str = "SCH")
df_alb = read_dwd_temp(alb_path; explo_str = "ALB")
df_hai = read_dwd_temp(hai_path; explo_str = "HAI")

# move the file to assets/data/input
vcat(df_sch, df_alb, df_hai) |> CSV.write("temperature_precipitation_dwd.csv")
