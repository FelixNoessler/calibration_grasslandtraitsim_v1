using DataFrames
using DataFramesMeta
import CSV
import Dates

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head=3, tail=0)
    b = lpad(b, 2, "0")
    return a * b
end

function isdate(x)
    if ismissing(x)
        return false
    end
    return isnothing(tryparse(Dates.Date, x, Dates.dateformat"yyy-mm-dd")) ? false : true
end


function load_mowing(path)
    lui_df = CSV.read(
        path * "LUI_tool_input.csv",
        DataFrame)

    df = CSV.read(
        path * "management_input.csv",
        DataFrame;
        missingstring=["", "NA"]);

    df = mapcols(col -> replace(col, "-1" => missing), df)
    df = mapcols(col -> replace(col, -1 => missing), df)

    mowing_df = @chain df begin
        @select(:Year, :EP_PlotID,
            $(r"DateCut"), $(r"CutHeight_cm"))
        innerjoin(@select(lui_df, :Year, :EP_PlotID, :TotalMowing),
            _,
            on = [:Year, :EP_PlotID])
        sort(:EP_PlotID)
        disallowmissing!(:Year)
    end

    for i in 1:5
        mowing_df[:, "MowingDay$i"] = Array{Union{Missing, Int64}}(missing, nrow(mowing_df))

        mowing_filter = isdate.(mowing_df[:, "DateCut$i"])
        mowing_dates = Dates.Date.(mowing_df[mowing_filter, "DateCut$i"])
        mowing_df[mowing_filter, "MowingDay$i"] .= Dates.dayofyear.(mowing_dates)

        heights = copy(mowing_df[: ,"CutHeight_cm$i"])
        heights = convert(Vector{Union{Missing, Float64}}, heights)
        f1 = .! ismissing.(heights) .&& heights .< 3.0
        heights[f1] .= missing

        f2 = ismissing.(heights) .&& mowing_filter
        heights[f2] .= 7.5
        mowing_df[!, "CutHeight_cm$i"] = heights
    end

    @select! mowing_df $(Not(r"DateCut"))

    mowing_validation = @chain mowing_df begin
        @transform :EP_PlotID = convert_id.(:EP_PlotID)
        @rename begin
            :plotID = :EP_PlotID
            :year = :Year
        end
        @orderby :year
    end

    return mowing_validation
end

df = load_mowing("../data/")

# move to GrasslandTraitSim/assets/data/input/
CSV.write("mowing.csv", df)
