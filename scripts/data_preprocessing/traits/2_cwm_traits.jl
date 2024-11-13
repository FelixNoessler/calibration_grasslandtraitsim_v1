include("0_functions_load_traits.jl")

##### load tables
data_path = "../Raw_data/"
veg_df, veg_species_df = load_veg_df(data_path * "BE/")
df_leaf = bexis_leaf_traits(data_path * "BE/")
df_root = bexis_root_traits(data_path * "BE/")
df_try = load_lnc_try(data_path)
df_maxheight = load_maxheight(data_path)

##### create trait tables for all species in vegetation dataset
df_bexis = @chain outerjoin(df_leaf, df_root, on = :species, makeunique = true) begin
    @rtransform :sla = uconvert(u"m^2 / g", mean_missing(:sla1, :sla2))
    @select $(Not([:sla1, :sla2, :LA, :LDM, :leaf_species_orig, :root_species_orig]))
end

veg_trait_df = @chain veg_species_df begin
    leftjoin(df_bexis; on = :species)
    leftjoin(df_maxheight; on = :species)
    leftjoin(df_try; on = :species)
    @rsubset :maxheight <= 2.0u"m"
    @orderby :species
end

veg_trait_final_df = @chain veg_trait_df begin
    @transform :species = :veg_orig_name
    @select $(Not(:veg_orig_name))
end

######### join trait and species cover data
function cwm_missing(trait_vals, cover_vals)
    f = .! ismissing.(trait_vals)
    sum(cover_vals[f] .* trait_vals[f] ./ sum(cover_vals[f]))
end

function cwm_quality(trait_vals, cover_vals)
    f = .! ismissing.(trait_vals)
    sum(cover_vals .* f ./ sum(cover_vals))
end

function functional_dispersion(trait_vec, cover_vals;)
    # Laliberté & Legendre 2010

    trait_matrix = hcat(trait_vec...)
    traits_missing = ismissing.(trait_matrix)
    species_filter = iszero.(vec(sum(traits_missing; dims = 2)))

    trait_matrix = trait_matrix[species_filter, :]
    cover_vals = cover_vals[species_filter]

    nspecies, ntraits = size(trait_matrix)
    z_squarred = zeros(nspecies)

    for t in 1:ntraits
        trait_vals = trait_matrix[:, t]
        trait_vals = trait_vals ./ mean(trait_vals)

        cwm = sum(cover_vals .* trait_vals ./ sum(cover_vals))
        z_squarred .+= (trait_vals .- cwm) .^ 2
    end

    z = sqrt.(z_squarred)

    relative_cover = cover_vals ./ sum(cover_vals)
    return sum(z .* relative_cover)
end


cwm_veg_df = @chain veg_df begin
    leftjoin(veg_trait_final_df, on = :species)
    @groupby :plotID :year
    @combine begin
        :rsa = round(cwm_missing(:srsa, :cover); digits = 4)
        :amc = round(cwm_missing(:amc, :cover); digits = 3)
        :abp = round(cwm_missing(:abp, :cover); digits = 3)
        :sla = round(cwm_missing(:sla, :cover); digits = 5)
        :maxheight = round(cwm_missing(:maxheight, :cover); digits = 2)
        :lnc = round(cwm_missing(:lnc, :cover); digits = 2)
        :fdis = round(functional_dispersion([:srsa, :amc, :abp, :sla, :maxheight, :lnc], :cover); digits = 2) #
        # :srsa_quality = cwm_quality(:srsa, :cover)
        # :amc_quality = cwm_quality(:amc, :cover)
        # :abp_quality = cwm_quality(:abp, :cover)
        # :sla_quality = cwm_quality(:sla, :cover)
        # :height_quality = cwm_quality(:height, :cover)
        # :lnc_quality = cwm_quality(:lnc, :cover)
    end
    @orderby :plotID :year
end

##### join vegetation date
veg_date_df = load_vegetation_date_df(data_path * "BE/")

cwm_veg_df = @chain cwm_veg_df begin
    @subset 2009 .<= :year .<= 2021
    leftjoin(veg_date_df, on = [:year, :plotID])
    @transform :numeric_date = round.(:numeric_date, digits = 5)
end
disallowmissing!(cwm_veg_df)


##### write output without units
cwm_veg_wo_units_df = @rtransform cwm_veg_df begin
    :rsa = ustrip(:rsa)
    :sla = ustrip(:sla)
    :maxheight = ustrip(:maxheight)
    :lnc = ustrip(:lnc)
end
@subset! cwm_veg_wo_units_df startswith.(:plotID, "H")
cwm_output_path = "../Calibration_data/CWM_Traits.csv"
CSV.write(cwm_output_path, cwm_veg_wo_units_df)

##### read file and add units
@chain CSV.read(cwm_output_path, DataFrame) begin
    @transform begin
        :rsa = :rsa * u"m^2 / g"
        :sla = :sla * u"m^2 / g"
        :maxheight = :maxheight * u"m"
        :lnc = :lnc * u"mg / g"
    end
end
