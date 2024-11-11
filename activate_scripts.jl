import Pkg

if isdir("Calibration_GrasslandTraitSim_v1")
    cd("Calibration_GrasslandTraitSim_v1")
    Pkg.activate(".")
    Pkg.develop(path="../Model_code_GrasslandTraitSim_v1")
end
