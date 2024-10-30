data_dir = "../data/"

# https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/historical/
# 164 - Angermünde = SCH
# 3402 - Münsingen-Apfelstetten = ALB
# 6305 - Mühlhausen = HAI
ids = [
    "164",
    "3402",
    "6305",
]

for id in ids
    local url = "https://opendata.dwd.de/climate_environment/CDC/derived_germany/soil/daily/historical/derived_germany_soil_daily_historical_$(id).txt.gz"
    filename = "pet_$(id).txt.gz"
    download(url, joinpath(data_dir, filename))
end
