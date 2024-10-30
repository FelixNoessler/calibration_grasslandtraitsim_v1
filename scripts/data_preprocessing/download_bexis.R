# install with:
# devtools::install_github("BEXIS2/rBExIS", subdir = "rBExIS")
library(rBExIS) 
library(readr)

download_bexis_dataset <- function(id, name, output_dir){
    dir.create("data/", showWarnings = FALSE)
    api_url <- rBExIS:::get_api_url("/data/")
    table_data <- content(rBExIS:::get_response("GET", paste0(api_url, id)))
    write_csv(table_data, paste0(output_dir, name, ".csv"))
}

bexis.options("base_url" = "https://www.bexis.uni-jena.de/")
data_dir = "data/"


## approximate (public) coordinates 
download_bexis_dataset(id = 1000, name = "approx_site_coordinates", output_dir = data_dir)
 
## management input for grazing and mowing
download_bexis_dataset(id = 31715, name = "management_input", output_dir = data_dir)
download_bexis_dataset(id = 25086, name = "LUI_tool_input", output_dir = data_dir)

## cut biomass (botany core)
download_bexis_dataset(id = 16209, name = "biomass_2009", output_dir = data_dir)
download_bexis_dataset(id = 12706, name = "biomass_2010", output_dir = data_dir)
download_bexis_dataset(id = 14346, name = "biomass_2011", output_dir = data_dir)

## cut biomass (sade)
download_bexis_dataset(id = 19812, name = "biomass_2015_sade", output_dir = data_dir)
download_bexis_dataset(id = 23506, name = "biomass_2017_sade", output_dir = data_dir)

## cut biomass (hedge II)
download_bexis_dataset(id = 31138, name = "biomass_2017_hainich_hedgeII", output_dir = data_dir)
download_bexis_dataset(id = 31139, name = "biomass_2018_alb_hedgeII", output_dir = data_dir)

## vegetation
download_bexis_dataset(id = 31389, name = "vegetation_2008_2022", output_dir = data_dir)

## vegetation header data
download_bexis_dataset(id = 6340, name = "vegetation_header_data_2009", output_dir = data_dir)
download_bexis_dataset(id = 13486, name = "vegetation_header_data_2010", output_dir = data_dir)
download_bexis_dataset(id = 14326, name = "vegetation_header_data_2011", output_dir = data_dir)
download_bexis_dataset(id = 15588, name = "vegetation_header_data_2012", output_dir = data_dir)
download_bexis_dataset(id = 16826, name = "vegetation_header_data_2013", output_dir = data_dir)
download_bexis_dataset(id = 19807, name = "vegetation_header_data_2014", output_dir = data_dir)
download_bexis_dataset(id = 19809, name = "vegetation_header_data_2015", output_dir = data_dir)
download_bexis_dataset(id = 21187, name = "vegetation_header_data_2016", output_dir = data_dir)
download_bexis_dataset(id = 31466, name = "vegetation_header_data_2017", output_dir = data_dir)
download_bexis_dataset(id = 24166, name = "vegetation_header_data_2018", output_dir = data_dir)
download_bexis_dataset(id = 26151, name = "vegetation_header_data_2019", output_dir = data_dir)
download_bexis_dataset(id = 27426, name = "vegetation_header_data_2020", output_dir = data_dir)
download_bexis_dataset(id = 31180, name = "vegetation_header_data_2021", output_dir = data_dir)
download_bexis_dataset(id = 31387, name = "vegetation_header_data_2022", output_dir = data_dir)

## leaf traits
download_bexis_dataset(id = 24807, name = "leaf_traits", output_dir = data_dir)

## root traits
download_bexis_dataset(id = 26546, name = "root_traits", output_dir = data_dir)

## soil nutrients
download_bexis_dataset(id = 14446, name = "soilnutrients_2011", output_dir = data_dir)
download_bexis_dataset(id = 18787, name = "soilnutrients_2014", output_dir = data_dir)
download_bexis_dataset(id = 23846, name = "soilnutrients_2017", output_dir = data_dir)
download_bexis_dataset(id = 31210, name = "soilnutrients_2021", output_dir = data_dir)

## soil texture
download_bexis_dataset(id = 14686, name = "soiltexture_2011", output_dir = data_dir)

## soil organic matter content
download_bexis_dataset(id = 14446, name = "soilorganicmatter_2011", output_dir = data_dir)

## soil bulk density
download_bexis_dataset(id = 17086, name = "soilbulkdensity_2011", output_dir = data_dir)

## rooting depth
download_bexis_dataset(id = 4761, name = "rootingdepth_2008", output_dir = data_dir)
