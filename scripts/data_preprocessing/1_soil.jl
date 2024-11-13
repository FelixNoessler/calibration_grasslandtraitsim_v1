import CSV
using DataFrames, DataFramesMeta
using Statistics

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head = 3, tail = 0)
    b = lpad(b, 2, "0")
    return a * b
end

function load_soil(path)
    function read_minsoil(path, year)
        @chain CSV.read(path, DataFrame; missingstring = "NA") begin
            @rename :explo = :Exploratory
            @subset :Type .== "G"
            @transform :Year = year
        end
    end

    df_prep = vcat(
        read_minsoil(path * "soilnutrients_2011.csv", 2011),
        read_minsoil(path * "soilnutrients_2014.csv", 2014),
        read_minsoil(path * "soilnutrients_2017.csv", 2017),
        read_minsoil(path * "soilnutrients_2021.csv", 2021))

    minsoil_df = @chain df_prep begin
        groupby(:EP_Plotid)
        @combine :totalN = round(mean(:Total_N); digits = 2)
    end

    texture_df = CSV.read(path * "soiltexture_2011.csv",
        DataFrame;
        missingstring = ["NA"])

    organic_df = CSV.read(path * "soilorganicmatter_2011.csv",
        DataFrame;
        missingstring = ["NA"])

    bulk_df = CSV.read(path * "soilbulkdensity_2011.csv",
        DataFrame;
        missingstring = ["-888888", "NA"])
    coalesce(bulk_df, NaN, missing)

    rooting_df = CSV.read(path * "rootingdepth_2008.csv",
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
        @transform :Clay = :Clay / 1000
        @transform :Silt = (:Fine_Silt + :Medium_Silt + :Coarse_Silt) / 1000
        @transform :Sand = (:Fine_Sand + :Medium_Sand + :Coarse_Sand) / 1000
        @transform :Clay = round.(:Clay, digits = 2)
        @transform :Silt = round.(:Silt, digits = 2)
        @transform :Sand = round.(:Sand, digits = 2)
        @rename :explo = :Exploratory
        leftjoin(_, minsoil_df, on = :EP_Plotid)
        leftjoin(_, organic_df, on = :EP_Plotid, makeunique = true)
        leftjoin(_, bulk_df, on = :EP_Plotid, makeunique = true)
        leftjoin(_, plot_rooting_df, on = :EP_Plotid, makeunique = true)
        leftjoin(_, explo_rooting_df, on = :explo)
        @rename :bulk = :BD
        @transform :bulk = coalesce.(:bulk, mean(:bulk[.!ismissing.(:bulk)]))
        @transform :bulk = round.(:bulk, digits = 2)
        @transform :root_depth = coalesce.(:root_depth, :median_root_depth) * 10
        @transform :organic = round.(:Organic_C / 1000; digits = 2)
        @rtransform :plotID = convert_id(:EP_Plotid)
        @orderby :plotID
        @rename begin
            :clay = :Clay
            :silt = :Silt
            :sand = :Sand
            :rootdepth = :root_depth
        end
        @transform :x = 1
        @transform :y = 1
        @subset startswith.(:plotID, "H")
        @select :sand :silt :clay :organic :bulk :rootdepth :totalN :x :y :plotID
    end

    disallowmissing!(df)

    return df
end

soil_df = load_soil("../Raw_data/BE/")
CSV.write("../Input_data/Soil.csv", soil_df)
