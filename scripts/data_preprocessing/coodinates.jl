using DataFrames
using DataFramesMeta
import CSV

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head=3, tail=0)
    b = lpad(b, 2, "0")
    return a * b
end

function load_coordinates(path)
    df = CSV.read(path * "approx_site_coordinates.csv", DataFrame)

    @chain df begin
        @rename :plotID = :EP_Plot_ID
        @subset :Landuse .== "Grassland"
        @subset :plotID .!= "na"
        @transform :plotID = convert_id.(:plotID)
        @orderby :plotID
        @select :plotID :Exploratory :Latitude :Longitude
    end
end


df_coord = load_coordinates("../Raw_data/BE/")
CSV.write("approx_coordinates.csv", df_coord)

# move file to Model_code_GrasslandTraitSim_v1/assets/data/input
