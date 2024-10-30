import Pkg

if isdir("calibration_grasslandtraitsim_v1")
    cd("calibration_grasslandtraitsim_v1")
    Pkg.activate(".")
    Pkg.develop(path="../1_GrasslandTraitSim")
end
