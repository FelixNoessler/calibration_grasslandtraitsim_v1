using CairoMakie

set_theme!(fontsize = 18,
    Axis = (xgridvisible = false, ygridvisible = false,
        topspinevisible = false, rightspinevisible = false))

function calc_reducer(R, trait_values; ϕ_trait = 20, ɑ_R_05, δ_R, β_R = 9.0)
    x0_R_05 = ϕ_trait + 1 / δ_R * log((1 - ɑ_R_05) / ɑ_R_05)
    R_05 = 1 / (1 + exp(-δ_R * (trait_values - x0_R_05)))
    x0 = log((1 - R_05) / R_05) / β_R + 0.5
    reducer = @. 1 / (1 + exp(-β_R * (R - x0)))

    return x0, R_05, reducer
end

let
    α_R_05_vals = [0.95, 0.55]
    δ_R_vals = [0.25, 0.1]

    fig = Figure()
    cmap = cgrad(:viridis, 5, categorical = true)
    lws = [1.5,1.5,4,1.5,1.5]
    ax_settings = (; width = 400, height = 400, limits = (0,1,0,1))

    Axis(fig[1, 1];
         xlabel = rich("Ressource density (",
                       rich("Nₚ", font = :italic), ", ",
                       rich("Wₚ", font = :italic), ")"),
         ylabel = rich("Growth reducer (",
                       rich("NUT", subscript("amc"), font = :italic), ", ",
                       rich("NUT", subscript("rsa"), font = :italic), ", ",
                       rich("WAT", font = :italic),
                       ")\n← stronger reduction, less reduction →"),
         ax_settings ...)

    for (i,t) in enumerate(16:2:24)
        ressource = 0.0:0.01:1.0
        res =  calc_reducer.(ressource, t; ɑ_R_05 = α_R_05_vals[2], δ_R = δ_R_vals[2])
        x0 = getindex.(res, 1)[1]
        R_05 = getindex.(res, 2)[1]
        reducer = getindex.(res, 3)

        lines!(ressource, reducer, color = cmap[i], linewidth = lws[i])
    end

    for (i,t) in enumerate(16:2:24)
        ressource = 0.0:0.01:1.0
        res =  calc_reducer.(ressource, t; ɑ_R_05 = α_R_05_vals[2], δ_R = δ_R_vals[2])
        x0 = getindex.(res, 1)[1]
        R_05 = getindex.(res, 2)[1]
        reducer = getindex.(res, 3)

        if i == 3
            scatter!(0.5, R_05; color = :red, markersize = 12)
        end
    end


    for (i,t) in enumerate(16:2:24)
        ressource = 0.0:0.01:1.0
        res =  calc_reducer.(ressource, t; ɑ_R_05 = α_R_05_vals[1], δ_R = δ_R_vals[1])
        x0 = getindex.(res, 1)[1]
        R_05 = getindex.(res, 2)[1]
        reducer = getindex.(res, 3)

        lines!(ressource, reducer, color = cmap[i], linewidth = lws[i])
    end


    for (i,t) in enumerate(16:2:24)
        ressource = 0.0:0.01:1.0
        res = calc_reducer.(ressource, t; ɑ_R_05 = α_R_05_vals[1], δ_R = δ_R_vals[1])
        x0 = getindex.(res, 1)[1]
        R_05 = getindex.(res, 2)[1]
        reducer = getindex.(res, 3)

        if i == 3
            scatter!(0.5, R_05; color = :red, markersize = 12)
        end
    end

    arrows!([0.5], [α_R_05_vals[1]-0.01], [0], [α_R_05_vals[2] - α_R_05_vals[1] + 0.03])
    scatter!(0.5 + 0.11, α_R_05_vals[1] - (α_R_05_vals[1] - α_R_05_vals[2]) / 3 - 0.005, color = :white, markersize = 35)
    scatter!(0.5 + 0.1, α_R_05_vals[1] - (α_R_05_vals[1] - α_R_05_vals[2]) / 3 - 0.005, color = :white, markersize = 35)
    scatter!(0.5 + 0.09, α_R_05_vals[1] - (α_R_05_vals[1] - α_R_05_vals[2]) / 3 - 0.005, color = :white, markersize = 35)
    scatter!(0.5 + 0.08, α_R_05_vals[1] - (α_R_05_vals[1] - α_R_05_vals[2]) / 3 - 0.005, color = :white, markersize = 35)
    text!(0.5 + 0.07, α_R_05_vals[1] - (α_R_05_vals[1] - α_R_05_vals[2]) / 3,
          text = L"\alpha_{RED, 05}", align = (:center, :center))


    x0, _, _ = calc_reducer(0.5, 20; ɑ_R_05 = α_R_05_vals[1], δ_R = δ_R_vals[1])

    f = 0.6
    arrows!([x0 - 0.02], [0.5], [0.1*f], [0.22*f])
    arrows!([x0 - 0.02], [0.5], [-0.1*f], [-0.22*f])
    scatter!(x0 + 0.02, 0.5 - 0.005, color = :white, markersize = 35)
    scatter!(x0 + 0.05, 0.5 - 0.005, color = :white, markersize = 35)
    text!(x0 + 0.04, 0.5, text = L"\beta_{RED}", align = (:center, :center))


    x0, _, _ = calc_reducer(0.5, 20; ɑ_R_05 = α_R_05_vals[2], δ_R = δ_R_vals[2])
    arrows!([x0], [0.5], [0.03], [0])
    arrows!([x0], [0.5], [-0.03], [0])
    text!(x0 + 0.06, 0.5, text = L"\delta_{RED}", align = (:left, :center))


    text!([0.3, 0.7], [0.95, 0.95], text = ["A", "B"], align = (:center, :center),
          font = :bold)

    Colorbar(fig[1, 2], colormap = cmap,
             ticks = ([0.1, 0.3, 0.5, 0.7, 0.9],
                      [L"\ll ϕ_{trait}", L"< ϕ_{trait}", L"ϕ_{trait}", L"> ϕ_{trait}", L"\gg ϕ_{trait}"]),
             label = rich("Trait values (",
                          rich("TRSA", font = :italic), ", ",
                          rich("TAMC", font = :italic), ")" ))


    resize_to_layout!(fig)
    fig

    save("conceptual_reducer.pdf", fig)
end
