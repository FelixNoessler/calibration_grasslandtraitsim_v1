include("0_functions_load_traits.jl")

##### load tables
data_path = "../data/"
output_path = "traits.csv"
df_leaf = bexis_leaf_traits(data_path)
df_root = bexis_root_traits(data_path)
df_leda = LEDA_height(data_path)
df_try = load_lnc_try(data_path)
df_maxheight = CSV.read(data_path * "maxheight_rothmaler.csv", DataFrame)
@transform! df_maxheight :maxheight = :maxheight .* u"m"
@select! df_maxheight :species :maxheight

##### Add root data for Taraxacum officinale
# https://groot-database.github.io/GRooT/
# https://github.com/GRooT-Database/GRooT-Data/
push!(df_root, ("Taraxacum officinale", "-", 0.12u"m^2/g", 0.7, missing, 0.47, 0.53))

##### join tables
df_bexis = outerjoin(df_leaf, df_root, on = :species, makeunique = true)
@rtransform! df_bexis :sla = uconvert(u"m^2 / g", mean_missing(:sla1, :sla2))
@select! df_bexis $(Not([:sla1, :sla2, :LA, :LDM]))
df = leftjoin(df_bexis, df_leda, on = :species)
manual_height!(df)
df1 = leftjoin(df, df_try, on = :species)

## export from try datasets citations:
# try_dataset_references(df.species)

##### write output without units
df_out = @chain df1 begin
    @orderby :species
    @rename :rsa = :srsa
    @rsubset !any(ismissing.([:rsa, :amc, :abp, :bbp, :sla, :height, :lnc]))
    @rtransform begin
        :rsa = round(typeof(:rsa), :rsa; digits = 4)
        :amc = round(:amc; digits = 3)
        :abp = round(:abp; digits = 3)
        :bbp = round(:bbp; digits = 3)
        :sla = round(typeof(:sla), :sla; digits = 5)
        :height = round(typeof(:height), :height; digits = 4)
        :lnc = round(typeof(:lnc), :lnc; digits = 1)
    end
    innerjoin(df_maxheight, on = :species)
    # or : species .∉ Ref(["Phragmites australis", "Phalaris arundinacea"])
    @subset :maxheight .<= 2u"m"
    @select Not([:leaf_species_orig, :root_species_orig, :species_leda, :height, :bbp])
end

### Poa annua has a very high SLA value, which is not realistic
### We will replace it with the mean of the other poa species
@subset df_out :sla .> 0.03u"m^2/g"
@subset df_out startswith.(:species, "Poa")
mean([0.001, 0.014, 0.018])
df_out[df_out.species .== "Poa annua", :sla] .= 0.011u"m^2/g"

disallowmissing!(df_out)
df_out_wo_units = @rtransform df_out begin
    :rsa = ustrip(:rsa)
    :sla = ustrip(:sla)
    :maxheight = ustrip(:maxheight)
    :lnc = ustrip(:lnc)
end
CSV.write(output_path, df_out_wo_units)

##### read file and add units
@chain CSV.read(output_path, DataFrame) begin
    @transform begin
        :srsa = :srsa * u"m^2 / g"
        :sla = :sla * u"m^2 / g"
        :height = :height * u"m"
        :lnc = :lnc * u"mg / g"
    end
end