import CSV, Dates
using DataFrames, DataFramesMeta
using Statistics

data_path = "../data/"

df = CSV.read(data_path * "exploratories_climate/plots.csv",
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
        :date = :datetime
        :temperature = :Ta_200
    end
    @transform begin
        :year = Dates.year.(:date)
        :doy = Dates.dayofyear.(:date)
        :temperature = round.(:temperature, digits = 1)
        :precipitation = round.(:precipitation, digits = 1)
    end
    @subset 2009 .<= :year .<= 2022
    @orderby :date
    @select(:plotID, :date, :year, :doy, :temperature, :precipitation)
end
disallowmissing!(df_sub)

## values look plausible!
# using CairoMakie
# display(hist(df_sub.temperature; bins=100))
# display(hist(df_sub.soiltemperature; bins=100))
# display(hist(df_sub.precipitation; bins=100))

# move file to assets/data/input
CSV.write("temperature_precipitation.csv", df_sub)
