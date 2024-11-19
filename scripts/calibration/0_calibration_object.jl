import GrasslandTraitSim as sim
import CSV
using Unitful
using UnPack
using Statistics
using DataFrames, DataFramesMeta

struct BE_optimization{T1, T2, T3, T4, T5}
    parameter_names::Vector{String}
    lb::Vector{Float64}
    ub::Vector{Float64}

    fixed_parameter::T1

    BE_IDs::Vector{String}
    BE_IDs_train::Vector{String}
    BE_IDs_test::Vector{String}

    input_data::T2
    measurement_data::T3
    trait_input::T4

    cache::T5
end

function Base.show(io::IO, be_opt::BE_optimization)
    print(io, """BE_optimization with training plots: $(be_opt.BE_IDs_train)
              and parameters to train: $(be_opt.parameter_names)""")
end

function BE_optimization(; all_sites = false)


    ## site code
    BE_IDs = ["$(explo)$(lpad(i, 2, "0"))" for i in 1:50 for explo in ["HEG"]]

    ## remove sites that are only grazed, as the grazing data quality is low
    ## often, additional fodder is provided on these sites, which is not considered
    select_plots = (;
        HEG01 = true,
        HEG02 = true,
        HEG03 = true,
        HEG04 = true,
        HEG05 = true,
        HEG06 = true,
        HEG07 = false,
        HEG08 = false,
        HEG09 = false,
        HEG10 = true,
        HEG11 = true,
        HEG12 = false,
        HEG13 = true,
        HEG14 = true,
        HEG15 = true,
        HEG16 = false,
        HEG17 = false,
        HEG18 = false,
        HEG19 = false,
        HEG20 = false,
        HEG21 = false,
        HEG22 = true,
        HEG23 = true,
        HEG24 = true,
        HEG25 = false,
        HEG26 = true,
        HEG27 = true,
        HEG28 = true,
        HEG29 = true,
        HEG30 = true,
        HEG31 = true,
        HEG32 = true,
        HEG33 = true,
        HEG34 = true,
        HEG35 = false,
        HEG36 = false,
        HEG37 = true,
        HEG38 = false,
        HEG39 = false,
        HEG40 = false,
        HEG41 = false,
        HEG42 = false,
        HEG43 = false,
        HEG44 = false,
        HEG45 = false,
        HEG46 = false,
        HEG47 = true,
        HEG48 = true,
        HEG49 = true,
        HEG50 = true,)
    plot_filter = [select_plots[Symbol(BE_ID)] for BE_ID in BE_IDs]
    BE_IDs = BE_IDs[plot_filter]

    ## sort sites from north to south
    df_coord = CSV.read(
        joinpath("../Calibration_data", "approx_coordinates.csv"),
        DataFrame)

    @subset! df_coord startswith.(:plotID, "H")
    lat = df_coord.Latitude[plot_filter]
    lat_order = sortperm(lat, rev = true)
    BE_IDs = BE_IDs[lat_order]

    ## divide into training and validation sites
    ntrain = length(BE_IDs) ÷ 2
    BE_IDs_train = sort(BE_IDs[1:ntrain])
    BE_IDs_test = sort(BE_IDs[ntrain+1:end])

    ## for which sites we load the data
    site_ids = BE_IDs_train
    if all_sites
        site_ids = BE_IDs
    end

    ## trait data of species
    sim.load_traits("../Input_data/")
    trait_input = sim.input_traits()

    ## input data
    sim.load_input_data("../Input_data/")
    input_dict = Dict()
    for k in Symbol.(site_ids)
        input_dict[k] = sim.validation_input(k;
            use_height_layers = true,
            nspecies = nothing, trait_seed = missing,
            initbiomass = 5000.0u"kg/ha",
            initsoilwater = 100.0u"mm")
    end
    input_data = NamedTuple(input_dict)

    ## measurements
    sim.load_measured_data("../Calibration_data/")
    data = NamedTuple{Tuple(Symbol.(site_ids))}(sim.measured_data)

    ## cache object for faster computation
    preallocs = sim.PreallocCache()

    ## which parameters to optimize
    parameter_optim = [
        ["α_RUE_cwmH", 0.7, 1.0],

        ["α_WAT_rsa05", 0.7, 0.9999],
        ["δ_WAT_rsa", 0.1, 25.0], #u"g / m^2"
        ["β_WAT_rsa", 6.0, 20.0],

        ["α_NUT_rsa05", 0.7, 0.9999],
        ["α_NUT_amc05", 0.7, 0.9999],
        ["δ_NUT_rsa", 0.1, 25.0], #u"g / m^2"
        ["δ_NUT_amc", 0.1, 15.0],
        ["β_NUT_rsa", 6.0, 20.0],
        ["β_NUT_amc", 6.0, 20.0],
        ["α_NUT_TSB", 5000.0, 25000.0], #u"kg / ha"

        ["κ_ROOT_rsa", 0.0, 0.4],
        ["κ_ROOT_amc", 0.0, 0.4],

        ["ζ_SEAmin", 0.3, 1.0],
        ["ζ_SEAmax", 1.0, 3.0],
        ["ζ_SEA_ST1", 500.0, 800.0], #u"°C"
        ["ζ_SEA_ST2", 1200.0, 1800.0], #u"°C"

        ["α_SEN", 0.03, 0.1],
        ["β_SEN_sla", 0.0, 3.0],
        ["ψ_SEN_ST1", 700.0, 2000.0], #u"°C"
        ["ψ_SENmax", 1.0, 3.0],

        ["β_GRZ_lnc", 0.0, 3.0],
        ["β_GRZ_H", 0.0, 3.0],
    ]
    parameter_names = getindex.(parameter_optim, 1)
    lb = float.(getindex.(parameter_optim, 2))
    ub = float.(getindex.(parameter_optim, 3))

    ## fixed parameters
    p_fixed = (;
        # fixed parameters by literature
        γ_RUEmax = 3 / 1000 * u"kg / MJ",
        γ_RUE_k = 0.6,
        γ_RAD1 = 4.45e-6u"ha / MJ",
        γ_RAD2 = 50000.0u"MJ / ha",
        ω_TEMP_T1 = 4.0u"°C",
        ω_TEMP_T2 = 10.0u"°C",
        ω_TEMP_T3 = 20.0u"°C",
        ω_TEMP_T4 = 35.0u"°C",
        κ_GRZ = 22.0u"kg",
        ψ_SEN_ST2 = 3000.0u"°C",
        ϵ_GRZ_minH = 0.05u"m",

        β_SND_WHC = 0.5678,
        β_SLT_WHC = 0.9228,
        β_CLY_WHC = 0.9135,
        β_OM_WHC = 0.6103,
        β_BLK_WHC = -0.2696u"cm^3/g",
        β_SND_PWP = -0.0059,
        β_SLT_PWP = 0.1142,
        β_CLY_PWP = 0.5766,
        β_OM_PWP = 0.2228,
        β_BLK_PWP = 0.02671u"cm^3/g",


        # set to the mean trait per default
        ϕ_TAMC = mean((1 .- trait_input.abp) .* trait_input.amc),
        ϕ_TRSA = mean((1 .- trait_input.abp) .* trait_input.rsa),
        ϕ_sla = mean(trait_input.sla),

        # fixed by me
        α_NUT_Nmax = 35.0 * u"g / kg",
        η_GRZ = 2.0,
        α_NUT_maxadj = 10.0,

        β_LIG_H = NaN64 # not used
    )

    ## add all other parameters that are not optmized
    ## if there are not already defined in p_fixed
    p_default = sim.SimulationParameter()
    f1 = keys(p_default) .∉ Ref(Symbol.(parameter_names))
    f2 = keys(p_default) .∉ Ref(keys(p_fixed))
    f = collect(f1 .&& f2)
    added_fixed = (; zip(collect(keys(p_default))[f], collect(values(p_default))[f])...)
    if !isempty(added_fixed)
        @warn added_fixed
    end
    p_fixed = merge(added_fixed, p_fixed)

    BE_optimization(parameter_names, lb, ub, p_fixed,
                    BE_IDs, BE_IDs_train, BE_IDs_test,
                    input_data, data, trait_input,
                    preallocs)
end
