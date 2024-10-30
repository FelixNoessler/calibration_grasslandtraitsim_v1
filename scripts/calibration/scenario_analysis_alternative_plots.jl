traits = [:srsa, :abp, :sla, :height, :amc, :lnc]
trait_names = [
    "Root surface area\nper belowground \nbiomass [m² g⁻¹]",
    "Aboveground\nbiomass per\ntotal biomass [-]",
    "Specific leaf\narea [m² g⁻¹]",
    "Potential\nheight [m]",
    "Arbuscular\nmycorrhizal\ncolonisation [-]",
    "Leaf nitrogen per\nleaf mass [mg g⁻¹]"
]

begin
    colours = [:yellow, :orange, :red, :purple, :black]
    i_adjust = [0.4, 0.2, 0.0, -0.2, -0.4]

    fig = Figure(; size = (1200, 700))
    ax = Axis(fig[1, 1]; yticks = (1:6, trait_names),
              title = "Only mowing",
              titlesize = 20,
              yticklabelsize = 20)


    vlines!(1.0; color = (:black, 0.2), linestyle = :dash)

    for t in eachindex(traits)
        m = vec(mean(result_mowing_relative[t, :, :]; dims = 2))
        lines!(m, t .+ i_adjust; color = (:black, 0.3))

        for p in eachindex(plotIDs)
            for i in 1:5
                scatter!([result_mowing_relative[t, i, p]], [t + i_adjust[i]];
                         color = (colours[i], 0.5),
                         label = "$i")
            end
        end

    end

    axislegend("        Number of\nmowing events\n            per year",
               merge = true, position = :rt, titleposition = :left,
               framevisible = false,
               titlefont = :regular,
               rowgap = -5)

    i_adjust = [0.2, 0.0, -0.2]
    colours = cgrad(:viridis, 3, categorical = true, rev = true)
    ax = Axis(fig[1, 2]; yticks = (1:7, fill("", 7)),
              leftspinevisible = false,
              title = "Only grazing",
              titlesize = 20)

    vlines!(1.0; color = (:black, 0.2), linestyle = :dash)

    for t in eachindex(traits)
        m = vec(mean(result_grazing_relative[t, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for i in 1:3
                scatter!([result_grazing_relative[t, i, p]], [t + i_adjust[i]];
                            color = (colours[i], 0.5),
                            label = "$i")
            end
        end
        lines!(m, t .+ i_adjust; color = (:black, 0.3))
    end

    axislegend("Grazing intensity\n       May-August\n         [LD/(ha⋅d)]",
        merge = true, position = :rt, titleposition = :left,
        framevisible = false, titlehalign = :right,
        titlefont = :regular,
        rowgap = -5)

    Label(fig[2, 1:2], "Community weighted mean trait (CWM) relative to\nmean of CWM of all three management intensities [-]",
          fontsize = 20)
    rowgap!(fig.layout, 1, 5)
    colgap!(fig.layout, 1, 15)

    # save("tmp/poster_landuse.png", fig; px_per_unit = 5)
    fig
end




begin
    traits = [:srsa, :abp, :sla, :height, :amc, :lnc]
    trait_names = [
        "Root surface\narea per below-\nground biomass\n[m² g⁻¹]",
        "Aboveground\nbiomass per\ntotal biomass\n[-]",
        "Specific leaf\narea [m² g⁻¹]",
        "Potential\nheight [m]",
        "Arbuscular\nmycorrhizal\ncolonisation\n[-]",
        "Leaf nitrogen per\nleaf mass\n[mg g⁻¹]"
    ]

    fig = Figure(; size = (1000, 700))

    colours = [:yellow, :orange, :red, :purple, :black]
    i_adjust = [-0.4, -0.2, 0.0, 0.2, 0.4]
    ax1 = Axis(fig[1, 1];  xticks = (1:6, fill("", 6)),
               bottomspinevisible = true, topspinevisible = true,
               xticksvisible = false)
    hlines!(1.0; color = (:black, 0.2), linestyle = :dash)
    for t in eachindex(traits)
        m = vec(mean(result_mowing_relative[t, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for i in 1:5
                scatter!([t + i_adjust[i]], [result_mowing_relative[t, i, p]];
                         color = (colours[i], 0.5),
                         label = "$i")
            end
        end
        lines!(t .+ i_adjust, m; color = (:black, 0.3))
    end
    axislegend("        Number of\nmowing events\n            per year",
               merge = true, position = :rt, titleposition = :left,
               framevisible = false,
               titlefont = :regular,
               rowgap = -5)

    i_adjust = [-0.2, 0.0, 0.2]
    colours = cgrad(:viridis, 3, categorical = true, rev = true)
    ax2 = Axis(fig[2, 1]; xticks = (1:6, trait_names),)
    hlines!(1.0; color = (:black, 0.2), linestyle = :dash)
    for t in eachindex(traits)
        m = vec(mean(result_grazing_relative[t, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for i in 1:3
                scatter!([t + i_adjust[i]], [result_grazing_relative[t, i, p]];
                         color = (colours[i], 0.5),
                         label = "$i")
            end
        end
        lines!(t .+ i_adjust, m; color = (:black, 0.3))
    end
    axislegend("Grazing intensity\n       May-August\n      [LD ha⁻¹ d⁻¹]",
        merge = true, position = :rt, titleposition = :left,
        framevisible = false, titlehalign = :right,
        titlefont = :regular,
        rowgap = -5)

    Label(fig[1:2, 0], "Community weighted mean trait relative to\nmean of all management intensities [-]",
          fontsize = 20, rotation = pi/2)
    for (i, label) in enumerate(["Only mowing", "Only grazing"])
        Box(fig[i, 2], color = :gray90, width = 30)
        Label(fig[i, 2], label, rotation = -pi/2, tellheight = false)
    end
    rowgap!(fig.layout, 1, 0)
    colgap!(fig.layout, 1, 15)
    colgap!(fig.layout, 2, 0)
    linkxaxes!(ax1, ax2)
    # save("tmp/poster_landuse.png", fig; px_per_unit = 5)
    fig
end


begin
    traits = [:srsa, :abp, :sla, :height, :amc, :lnc]
    trait_names = [
        "Root surface\narea per below-\nground biomass\n[m² g⁻¹]",
        "Aboveground\nbiomass per\ntotal biomass\n[-]",
        "Specific leaf\narea [m² g⁻¹]",
        "Potential\nheight [m]",
        "Arbuscular\nmycorrhizal\ncolonisation\n[-]",
        "Leaf nitrogen per\nleaf mass\n[mg g⁻¹]"
    ]

    fig = Figure(;)

    colours = [:yellow, :orange, :red, :purple, :black]
    i_adjust = [-0.4, -0.2, 0.0, 0.2, 0.4]

    ax = nothing
    for t in eachindex(traits)
        ax = Axis(fig[1,t]; xticksvisible = false, xticklabelsvisible = false,
                  width = 200, height = 400)

        m = vec(mean(result_mowing[t, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for i in 1:5
                scatter!([i_adjust[i]], [result_mowing[t, i, p]];
                         color = (colours[i], 0.5),
                         label = "$i")
            end
        end
        lines!(i_adjust, m; color = (:black, 0.3))
    end

    Legend(fig[1, length(traits) + 2], ax,
        "        Number of\nmowing events\n            per year",
        merge = true, position = :rt, titleposition = :left,
        framevisible = false,
        titlefont = :regular,
        rowgap = -5)



    i_adjust = [-0.2, 0.0, 0.2]
    colours = cgrad(:viridis, 3, categorical = true, rev = true)

    ax = nothing
    for t in eachindex(traits)
        ax = Axis(fig[2, t]; xticksvisible = false, xticklabelsvisible = false,
                  width = 200, height = 400)

        m = vec(mean(result_grazing[t, :, :]; dims = 2))
        for p in eachindex(plotIDs)
            for i in 1:3
                scatter!([i_adjust[i]], [result_grazing[t, i, p]];
                         color = (colours[i], 0.5),
                         label = "$i")
            end
        end
        lines!(i_adjust, m; color = (:black, 0.3))
    end

    Legend(fig[2, length(traits) + 2], ax, "Grazing intensity\n       May-August\n      [LD ha⁻¹ d⁻¹]",
        merge = true, position = :rt, titleposition = :left,
        framevisible = false, titlehalign = :right,
        titlefont = :regular,
        rowgap = -5)


    Label(fig[1:2, 0], "Community weighted mean trait",
          fontsize = 20, rotation = pi/2)


    for (i, label) in enumerate(["Only mowing", "Only grazing"])
        Box(fig[i, length(traits) + 1], color = :gray90, width = 30)
        Label(fig[i, length(traits) + 1], label, rotation = -pi/2, tellheight = false)
    end

    for (i, label) in enumerate(trait_names)
        # Box(fig[0, i], color = :gray90)
        Label(fig[0, i], label)
    end


    # rowgap!(fig.layout, 1, 0)
    colgap!(fig.layout, 1, 15)
    colgap!(fig.layout, 7, 0)
    # linkxaxes!(ax1, ax2)

    resize_to_layout!(fig)
    # save("tmp/poster_landuse.png", fig; px_per_unit = 5)
    fig
end
