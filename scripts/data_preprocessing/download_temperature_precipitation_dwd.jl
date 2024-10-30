data_dir = "../data/"

base_url = "https://opendata.dwd.de/climate_environment/CDC/observations_germany/climate/daily/kl/historical/"

files = [
    "tageswerte_KL_00164_19080517_20231231_hist.zip",
    "tageswerte_KL_03402_19460101_20231231_hist.zip",
    "tageswerte_KL_06305_20041201_20231231_hist.zip"
]

txt_names = [
    "produkt_klima_tag_19080517_20231231_00164.txt",
    "produkt_klima_tag_19460101_20231231_03402.txt",
    "produkt_klima_tag_20041201_20231231_06305.txt"
]

ids = [164, 3402, 6305]

for i in eachindex(files)
    local my_url = base_url * files[i]
    download(my_url, "data.zip")

    local my_file = txt_names[i]
    run(pipeline(`unzip -p data.zip $my_file`, stdout = "$(data_dir)/temperature_precipitation_$(ids[i]).csv"))
    rm("data.zip")
end
