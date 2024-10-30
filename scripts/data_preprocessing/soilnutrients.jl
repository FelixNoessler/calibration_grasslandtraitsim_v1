import CSV
using DataFrames, DataFramesMeta
using Statistics

function read_minsoil(path, year)
    @chain CSV.read(path, DataFrame; missingstring = "NA") begin
        @rename :Plot = :EP_Plotid
        @rename :explo = :Exploratory
        @subset :Type .== "G"
        @transform :Year = year
    end
end

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head = 3, tail = 0)
    b = lpad(b, 2, "0")
    return a * b
end

data_path = "../data/"
df_prep = vcat(
    read_minsoil(data_path * "soilnutrients_2011.csv", 2011),
    read_minsoil(data_path * "soilnutrients_2014.csv", 2014),
    read_minsoil(data_path * "soilnutrients_2017.csv", 2017),
    read_minsoil(data_path * "soilnutrients_2021.csv", 2021))

minsoil_df = @chain df_prep begin
    @transform :plotID = convert_id.(:Plot)
    @orderby :plotID
    groupby(:plotID)
    @combine :totalN = round(mean(:Total_N); digits = 2)
end

CSV.write("soilnutrients.csv", minsoil_df)


## visualize how the total N changes over time
using AlgebraOfGraphics, CairoMakie
let
    plots = ["$(explo)$(lpad(i, 2, "0"))" for i in 1:5 for explo in ["HEG"]]

    df = @chain df_prep begin
        @transform :plotID = convert_id.(:Plot)
        @orderby :plotID
        @subset :plotID .∈ Ref(plots)
        @select :plotID :Year :Total_N
   end

   xy = data(df) * mapping(:Year, :Total_N, color = :plotID)
   layers = visual(Scatter) + visual(Lines)
   draw(layers * xy)
end
