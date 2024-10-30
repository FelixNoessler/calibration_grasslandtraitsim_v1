import CSV
using DataFrames, DataFramesMeta
using Statistics
using Unitful

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head = 3, tail = 0)
    b = lpad(b, 2, "0")
    return a * b
end


data_dir = "../data/"

texture_df = CSV.read(data_dir * "soiltexture_2011.csv",
    DataFrame;
    missingstring = ["NA"])

organic_df = CSV.read(data_dir * "soilorganicmatter_2011.csv",
    DataFrame;
    missingstring = ["NA"])

bulk_df = CSV.read(data_dir * "soilbulkdensity_2011.csv",
    DataFrame;
    missingstring = ["-888888", "NA"])
coalesce(bulk_df, NaN, missing)

rooting_df = CSV.read(data_dir * "rootingdepth_2008.csv",
    DataFrame;
    missingstring = ["NA"])

plot_rooting_df = @chain rooting_df begin
    @rename :EP_Plotid = :plotid
    @subset .!ismissing.(:rootingSpace)
    groupby(_, :EP_Plotid)
    @combine :root_depth = median(:rootingSpace)
end

explo_rooting_df = @chain rooting_df begin
    @rename :EP_Plotid = :plotid
    @transform :explo = string.(first.(:EP_Plotid))
    @subset .!ismissing.(:rootingSpace)
    groupby(_, :explo)
    @combine :median_root_depth = median(:rootingSpace)
end

df = @chain texture_df begin
    @subset :Type .== "G"
    @transform :Clay = :Clay / 10
    @transform :Silt = (:Fine_Silt + :Medium_Silt + :Coarse_Silt) / 10
    @transform :Sand = (:Fine_Sand + :Medium_Sand + :Coarse_Sand) / 10
    @rename :explo = :Exploratory
    leftjoin(_, organic_df, on = :EP_Plotid, makeunique = true)
    leftjoin(_, bulk_df, on = :EP_Plotid, makeunique = true)
    leftjoin(_, plot_rooting_df, on = :EP_Plotid, makeunique = true)
    leftjoin(_, explo_rooting_df, on = :explo)
    @rename :bulk = :BD
    @transform :bulk = coalesce.(:bulk, mean(:bulk[.!ismissing.(:bulk)]))
    @transform :root_depth = coalesce.(:root_depth, :median_root_depth) * 10
    @transform :organic = round.(:Organic_C / 1000 * 100; digits = 2)
    @rtransform :plotID = convert_id(:EP_Plotid)
    @orderby :plotID
    @rename begin
        :clay = :Clay
        :silt = :Silt
        :sand = :Sand
        :rootdepth = :root_depth
    end
    @select :plotID :explo :clay :silt :sand :organic :bulk :rootdepth
end

CSV.write("soilwater.csv", df)
