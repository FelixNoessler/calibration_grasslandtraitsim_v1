using DataFrames, DataFramesMeta
using Unitful
using Statistics
using RCall
import CSV
import Dates
import Base

Base.round(x::Quantity; digits) = round(typeof(x), x; digits)

function mean_missing(x1, x2)
    if ismissing(x1)
        return x2
    elseif ismissing(x2)
        return x1
    else
        return mean([x1, x2])
    end
end

function bexis_leaf_traits(path)
    @info "Loading bexis leaf traits"
    df = CSV.read(path * "leaf_traits.csv", DataFrame;
        missingstring="NA")

    # LA: leaf area [mm²]
    # LFM: leaf fresh mass [g]
    # LDM: leaf dry weight [g]
    df = @chain df begin
        @subset :system .== "grassland"
        @rtransform begin
            :LA = :total_area * u"mm^2"
            :LDM = :dry_weight * u"g"
            :leaf_species_orig = :pl_species
            :leaf_species = :pl_species
        end
        @rename :plotID = :plotid_withzero
        @subset :leaf_species .∉ Ref(["Crataegus sp", "Secale sp"])
        @select :plotID :leaf_species :leaf_species_orig :LA :LDM
        @rsubset !(ismissing(:LA) || ismissing(:LDM))
    end
    disallowmissing!(df)

    df[df.leaf_species .== "Festuca pratensis", :leaf_species] .= "Lolium pratense (Huds.) Darbysh."
    df[df.leaf_species .== "Festuca arundinacea", :leaf_species] .= "Lolium arundinaceum (Schreb.) Darbysh."
    df[df.leaf_species .== "Taraxacum sp", :leaf_species] .= "Taraxacum officinale F.H.Wigg."
    df[df.leaf_species .== "Prunella sp", :leaf_species] .= "Prunella vulgaris L."
    df[df.leaf_species .== "Primula elatior veris agg", :leaf_species] .= "Primula elatior Hill"
    df[df.leaf_species .== "Bromus hordeaceus agg incl. B. commutatus", :leaf_species] .= "Bromus hordeaceus L."
    df[df.leaf_species .== "Rhinanthus agg", :leaf_species] .= "Rhinanthus minor L."

    leaf_species = sort(unique(df.leaf_species))
    # [println(s) for s in sort(unique(leaf_species))];
    @rput leaf_species
    R"""
    library(TNRS)
    leaf_species_df<- TNRS(leaf_species)
    NaN
    """
    @rget leaf_species_df

    leaf_species_df = @chain leaf_species_df begin
        @rename begin
            :leaf_species = :Name_submitted
            :species = :Accepted_species
        end
        @select :species :leaf_species
    end

    @chain df begin
        leftjoin(leaf_species_df, on = :leaf_species)
        @groupby :species
        @combine begin
            :leaf_species_orig = first(:leaf_species_orig)
            :LA = median(:LA)
            :LDM = median(:LDM)
        end
        @orderby :species
        @transform :sla1 = :LA ./ :LDM
    end
end

function bexis_root_traits(path)
    @info "Loading bexis root traits"
    df = CSV.read(path * "root_traits.csv", DataFrame;
        missingstring="NA")

    df = @chain df begin
        @rename :root_species_orig = :species
        @transform :species = convert.(String, :root_species_orig)
    end

    df[df.species .== "Festuca_pratensis", :species] .= "Lolium pratense (Huds.) Darbysh."
    df[df.species .== "Festuca_arundinacea", :species] .= "Lolium arundinaceum (Schreb.) Darbysh."

    root_species = df.species
    # [println(s) for s in root_species];
    @rput root_species
    R"""
    library(TNRS)
    root_species_df<- TNRS(root_species)
    NaN
    """
    @rget root_species_df

    # BA:
    #   below ground dry biomass / aboveground dry biomass
    #   [ratio area/mass]
    # SRSA:
    #   root surface area / root dry biomass
    #   [m²/g]
    # AMC:
    #   arbuscular mycorrhizal colonisation of the entire root system
    #   [fraction, 0 to 1]
    @chain df begin
        @transform begin
            :species = root_species_df.Accepted_species
            :ba = :biomass_allocation
            :srsa = :SRSA * u"m^2 / g"
            :amc = :col
            :sla2 = :SLA * u"cm^2 / g"
        end
        @rtransform :abp = 1 / (1 + :ba)
        @rtransform :bbp = 1 - :abp
        @orderby :species
        @select :species :root_species_orig :srsa :amc :sla2 :abp :bbp
    end
end

function LEDA_height(path)
    if isfile(path *  "canopy_height_LEDA.csv")
        df = CSV.read(path *  "canopy_height_LEDA.csv", DataFrame)
        @transform! df :height = :height * u"m"
        @subset! df .! ismissing.(:species)
        return df
    end

    @info "Loading leada height"
    function data_available(data)
        f = isa.(data, Number)
        f[f] .= .! isnan.(data[f]) .&& Inf .> data[f] .> 0
        return f
    end

    df = CSV.read(path *  "LEDA/canopy_height.txt", DataFrame;
        missingstring=["", "NA"],
        delim=";")

    df[!, :height] .= NaN

    ### Use single values
    f1 = data_available(df[:, "single value [m]"])
    df[f1, :height] .= df[f1, "single value [m]"]

    ### even better mean values
    f1 = data_available(df[:, "mean CH [m]"])
    df[f1, :height] .= df[f1, "mean CH [m]"]

    @rename! df :species_leda = $(Symbol("SBS name"))
    @transform! df :leda_species_orig = :species_leda

    df[df.species_leda .== "Festuca pratensis", :species_leda] .= "Lolium pratense (Huds.) Darbysh."
    df[df.species_leda .== "Festuca pratensis s. apennina", :species_leda] .= "Festuca pratensis subsp. apennina(De Not.) Hegi"
    df[df.species_leda .== "Festuca arundinacea", :species_leda] .= "Lolium arundinaceum (Schreb.) Darbysh."
    df[df.species_leda .== "Senecio jacobaea", :species_leda] .= "Senecio vulgaris L."
    df[df.species_leda .== "Taraxacum Sec. Ruderalia", :species_leda] .= "Taraxacum officinale F.H.Wigg."

    leda_species = sort(unique(df.species_leda))
    @rput leda_species
    R"""
    library(TNRS)
    leda_species_df <- TNRS(leda_species)
    NaN
    """
    @rget leda_species_df

    leda_species_df = @chain leda_species_df begin
        @rename begin
            :species_leda = :Name_submitted
            :species = :Accepted_species
        end
        @select :species :species_leda
    end

    df = @chain df begin
        leftjoin(leda_species_df, on = :species_leda)
        @groupby :species
        @combine begin
            :species_leda = first(:species_leda)
            :height = median(:height)
        end
    end

    CSV.write(path *  "LEDA/canopy_height_sub.csv", df)
    @transform! df :height = :height * u"m"

    return df
end

function manual_height!(df)
    species_without_height = ["Poa trivialis", "Helictotrichon pubescens",
        "Veronica teucrium", "Tripleurospermum inodorum", "Rumex acetosella",
        "Medicago falcata", "Carex vulpina"]
    new_height = [0.3, 0.6, 0.5, 0.5, 0.2, 0.5, 0.7]u"m"

    for i in eachindex(new_height)
        s = species_without_height[i]
        v = new_height[i]
        df[df.species .== s, :height] .= v
    end

    return df
end

function load_lnc_try(path)
    @info "Loading try lnc"

    if isfile(path *  "TRY_Leaf_nitrogen_content.csv")
        df = CSV.read(path *  "TRY_Leaf_nitrogen_content.csv", DataFrame)
        @transform! df :lnc = :lnc * u"mg/g"
        @subset! df .! ismissing.(:species)
        return df
    end

    try_df = CSV.read(path *  "TRY/33838.txt", DataFrame;
        missingstring=["", "NA"],
        delim="\t")

    try_sub_df = @chain try_df begin
        @subset .! ismissing.(:AccSpeciesName)
        @subset .! ismissing.(:TraitName)
        @subset .! ismissing.(:StdValue)
        @select :AccSpeciesName :StdValue :TraitName
    end
    disallowmissing!(try_sub_df)

    try_species = unique(try_sub_df.AccSpeciesName)
    @rput try_species
    R"""
    library(TNRS)
    try_species_df<- TNRS(try_species)
    NaN
    """
    @rget try_species_df

    try_species_sub_df = @chain try_species_df begin
        @rename begin
            :AccSpeciesName = :Name_submitted
            :species = :Accepted_species
        end
        @orderby :species
        @select :species :AccSpeciesName
    end

    df = @chain try_sub_df begin
        leftjoin(try_species_sub_df, on = "AccSpeciesName")
        @subset :TraitName .== "Leaf nitrogen (N) content per leaf dry mass"
        @groupby :species
        @combine :lnc = median(:StdValue)
        @subset .! ismissing.(:species)
    end

    CSV.write(path *  "TRY/33838_sub.csv", df)
    @transform! df :lnc = :lnc * u"mg/g"

    return df
end

function load_maxheight(path)
    @chain CSV.read(path * "Rothmaler_maxheight.csv", DataFrame) begin
        @transform :maxheight = :maxheight .* u"m"
        @select :species :maxheight
    end
end

### export citation from TRY
function try_dataset_references(species)
    try_df = CSV.read(data_path *  "TRY/33838.txt", DataFrame;
                    missingstring=["", "NA"], delim="\t")

    @chain try_df begin
        @transform :species = :SpeciesName
        @subset :species .∈ Ref(species)
        @subset :TraitName .== "Leaf nitrogen (N) content per leaf dry mass"
        @groupby :Dataset :Reference
        @combine begin
            :n = length(:Dataset)
            :r = first(:Reference)
        end
        @orderby :n
    end
end

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head = 3, tail = 0)
    b = lpad(b, 2, "0")
    return a * b
end

function to_numeric(d::Dates.Date)
    daysinyear = Dates.daysinyear(Dates.year(d))
    return Dates.year(d) + (Dates.dayofyear(d) - 1) / daysinyear
end

function load_veg_df(path)
    veg_df = CSV.read(path * "vegetation_2008_2022.csv", DataFrame,
        missingstring = ["", "NA"])

    veg_df = @chain veg_df begin
        @subset .! ismissing.(:Cover)
        @subset :Cover .> 0

        @rename begin
            :species = :Species
            :year = :Year
            :cover = :Cover
            :plotID = :Useful_EP_PlotID
        end
        @select :plotID :year :species :cover
        @orderby :plotID :year :species
    end

    veg_df[veg_df.species .== "Festuca_pratensis", :species] .= "Lolium pratense (Huds.) Darbysh."
    veg_df[veg_df.species .== "Festuca_arundinacea", :species] .= "Lolium arundinaceum (Schreb.) Darbysh."
    veg_df[veg_df.species .== "Senecio_jacobaea", :species] .= "Jacobaea vulgaris Gaertn."
    veg_df[veg_df.species .== "Trifolium_campestre/dubium_aggr.", :species] .= "Trifolium dubium Sibth."
    veg_df[veg_df.species .== "Vicia_cf_lathyroides", :species] .= "Vicia lathyroides L."
    veg_df[veg_df.species .== "Geum_rivale/urbanum_aggr.", :species] .= "Geum urbanum L."
    veg_df[veg_df.species .== "Ononis_repens/spinosa_aggr.", :species] .= "Ononis spinosa L."
    veg_df[veg_df.species .== "Geranium_cf_pusillum", :species] .= "Geranium pusillum L."
    veg_df[veg_df.species .== "Primula_elatior/veris/aggr.", :species] .= "Primula elatior Hill"

    veg_species = unique(veg_df.species)
    @rput veg_species
    R"""
    library(TNRS)
    veg_species_df <- TNRS(veg_species)
    NaN
    """
    @rget veg_species_df

    veg_species_df = @chain veg_species_df begin
        @rename begin
        :species = :Accepted_species
        :veg_orig_name = :Name_submitted
        end
        @subset :species .!== ""
        @select :species :veg_orig_name
    end

    return veg_df, veg_species_df
end

function load_vegetation_date_df(path)
    ep_plots = ["$(explo)" * lpad(i, 2, "0") for i in 1:50 for explo in ["HEG", "SEG", "AEG"]]
    plot_df = DataFrame(plotID = ep_plots)

    datasets = ["vegetation_header_data_$y.csv" for y in 2009:2021]

    date_col = [fill(:Date, 2)...
        fill(:date, 3)...
        fill(missing, 4)...
        fill(:date_releves, 4)...]
    id_cols = [:EPID
        fill(:EpPlotID, 8)...
        fill(:Ep_PlotID, 4)...]
    dfs = []

    for (i, file) in enumerate(datasets)
        df = CSV.read(path * file,
            DataFrame;
            missingstring = ["", "NA"])

        if ismissing(date_col[i])
            doy = df.day_of_year
            doy[ismissing.(doy)] .= mean(.!ismissing(doy))
            df.date = @. Dates.Date(df.year) + Dates.Day(doy)
        else
            df.date = df[:, date_col[i]]
        end

        df = @chain df begin
            @transform :plotID = convert_id.($(id_cols[i]))
            @select :plotID :date
            rightjoin(plot_df, on = :plotID)
        end

        if any(ismissing.(df.date))
            selected_dates = df[.!ismissing.(df.date), :date]
            year = Dates.year(selected_dates[1])
            mean_doy = Int(median(Dates.dayofyear.(selected_dates)))
            df[ismissing.(df.date), :date] .= Dates.Date(year) + Dates.Day(mean_doy)
        end

        unique!(df, :plotID)

        # @show length(unique(df.plotID))
        push!(dfs, df)
    end
    date_df = vcat(dfs...)
    date_df.year = Dates.year.(date_df.date)
    date_df.numeric_date = to_numeric.(date_df.date)
    return date_df
end
