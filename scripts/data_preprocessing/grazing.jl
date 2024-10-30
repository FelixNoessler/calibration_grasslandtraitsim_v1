using DataFrames
using DataFramesMeta
using CairoMakie
import CSV
import Dates

function convert_id(id)
    a = first.(id, 3)
    b = chop(id, head=3, tail=0)
    b = lpad(b, 2, "0")
    return a * b
end

function convert_month(str)
    if ismissing(str)
        return missing
    end

    month_strs = [
        "Januar", "Februar", "Maerz", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember"]

    return findfirst(str .== month_strs)
end


function supplementary_feeding(path)
    # supplementary_feeding.csv was created from https://www.bexis.uni-jena.de/ddm/data/Showdata/26487
    df = CSV.read(
        path * "supplementary_feeding.csv",
        DataFrame)

    @rename! df :plotID = :EP_PlotID
    @rename! df :year = :Year


    df_summarized = @chain df begin
        @groupby :plotID
        @combine :supplementary_feeding = any(:SupplementaryFeeding)
    end

    return df, df_summarized
end

function load_grazing(path)
    lui_df = CSV.read(
        path * "LUI_tool_input.csv",
        DataFrame)

    df = CSV.read(
        path * "management_input.csv",
        DataFrame;
        missingstring=["", "NA"]);

    df = mapcols(col -> replace(col, "-1" => missing), df)
    df = mapcols(col -> replace(col, -1 => missing), df)
    df = mapcols(col -> replace(col, "ja" => true), df)
    df = mapcols(col -> replace(col, "nein" => false), df)

    selected_columns = [
        :Year, :EP_PlotID, :SizeManagementUnit,
        :AllYearGrazing, :StartGrazing, :GrazingType,
        :StartGrazingPeriod1,
        :StartGrazingPeriod2,
        :StartGrazingPeriod3,
        :StartGrazingPeriod4,
        :LivestockUnits1, :DayGrazing1, :GrazingArea1,
        :LivestockUnits2, :DayGrazing2, :GrazingArea2,
        :LivestockUnits3, :DayGrazing3, :GrazingArea3,
        :LivestockUnits4, :DayGrazing4, :GrazingArea4,
    ]

    col_filter = Symbol.(names(df)) .∈ Ref(selected_columns)
    df = df[!, col_filter]
    df.AllYearGrazing[ismissing.(df.AllYearGrazing)] .= false
    df.GrazingType[ismissing.(df.GrazingType)] .= ""


    ## 2020: AEG09 grazing of period 1 was written to grazing period 2
    df[findall(df.Year .== 2020 .&& df.EP_PlotID .== "AEG9"), :StartGrazingPeriod1] .= "Mai"
    df[findall(df.Year .== 2020 .&& df.EP_PlotID .== "AEG9"), :DayGrazing1] .= 15
    df[findall(df.Year .== 2020 .&& df.EP_PlotID .== "AEG9"), :LivestockUnits1] .= 70

    df[findall(df.Year .== 2020 .&& df.EP_PlotID .== "AEG9"), :StartGrazingPeriod2] .= missing
    df[findall(df.Year .== 2020 .&& df.EP_PlotID .== "AEG9"), :DayGrazing2] .= missing
    df[findall(df.Year .== 2020 .&& df.EP_PlotID .== "AEG9"), :LivestockUnits2] .= missing


    df = @chain df begin
        innerjoin(@select(lui_df, :Year, :EP_PlotID, :TotalGrazing), _,
                  on = [:Year, :EP_PlotID])
        @rtransform :EP_PlotID = convert_id(:EP_PlotID)
        @orderby :Year :EP_PlotID
        @rtransform begin
            :DayGrazing1 = ismissing(:DayGrazing1) ? 0 : :DayGrazing1
            :DayGrazing2 = ismissing(:DayGrazing2) ? 0 : :DayGrazing2
            :DayGrazing3 = ismissing(:DayGrazing3) ? 0 : :DayGrazing3
            :DayGrazing4 = ismissing(:DayGrazing4) ? 0 : :DayGrazing4
            :LivestockUnits1 = ismissing(:LivestockUnits1) ? 0 : :LivestockUnits1
            :LivestockUnits2 = ismissing(:LivestockUnits2) ? 0 : :LivestockUnits2
            :LivestockUnits3 = ismissing(:LivestockUnits3) ? 0 : :LivestockUnits3
            :LivestockUnits4 = ismissing(:LivestockUnits4) ? 0 : :LivestockUnits4
            :GrazingArea1 = ismissing(:GrazingArea1) ? :SizeManagementUnit : :GrazingArea1
            :GrazingArea2 = ismissing(:GrazingArea2) ? :SizeManagementUnit : :GrazingArea2
            :GrazingArea3 = ismissing(:GrazingArea3) ? :SizeManagementUnit : :GrazingArea3
            :GrazingArea4 = ismissing(:GrazingArea4) ? :SizeManagementUnit : :GrazingArea4
        end
        @rtransform begin
            :GrazingArea1 = iszero(:GrazingArea1) ? :SizeManagementUnit : :GrazingArea1
            :GrazingArea2 = iszero(:GrazingArea2) ? :SizeManagementUnit : :GrazingArea2
            :GrazingArea3 = iszero(:GrazingArea3) ? :SizeManagementUnit : :GrazingArea3
            :GrazingArea4 = iszero(:GrazingArea4) ? :SizeManagementUnit : :GrazingArea4
        end
        @rtransform begin
            :inten_graz1 = :DayGrazing1 * :LivestockUnits1 / :GrazingArea1
            :inten_graz2 = :DayGrazing2 * :LivestockUnits2 / :GrazingArea2
            :inten_graz3 = :DayGrazing3 * :LivestockUnits3 / :GrazingArea3
            :inten_graz4 = :DayGrazing4 * :LivestockUnits4 / :GrazingArea4
        end
        @rtransform :intens_total = :inten_graz1 + :inten_graz2 + :inten_graz3 + :inten_graz4
        @rtransform begin
            :isgrazed1 = :inten_graz1 > 0.0
            :isgrazed2 = :inten_graz2 > 0.0
            :isgrazed3 = :inten_graz3 > 0.0
            :isgrazed4 = :inten_graz4 > 0.0
        end

        ## on some rows the start of the first grazing period was missing
        ## set to the start of the start of the overall grazing period
        @rtransform :StartGrazingPeriod1 =
            ismissing(:StartGrazingPeriod1) ? :StartGrazing : :StartGrazingPeriod1

        @rtransform begin
            :StartGrazingPeriod1 = convert_month(:StartGrazingPeriod1)
            :StartGrazingPeriod2 = convert_month(:StartGrazingPeriod2)
            :StartGrazingPeriod3 = convert_month(:StartGrazingPeriod3)
            :StartGrazingPeriod4 = convert_month(:StartGrazingPeriod4)
        end

        ## allyear grazing on dauerweide starts in january
        @rtransform :StartGrazingPeriod1 = ismissing(:StartGrazingPeriod1) &&
            :AllYearGrazing  && startswith(:GrazingType, "Dauerweide") ?
            1 : :StartGrazingPeriod1

        ## for 16 rows (one row = one year of one site) the start of grazing was missing
        ## set to june
        @rtransform :StartGrazingPeriod1 = ismissing(:StartGrazingPeriod1) ?
            6 : :StartGrazingPeriod1

        ## for 8 rows the start of the second grazing period was missing
        ## set to start of first grazing period + one month
        @rtransform :StartGrazingPeriod2 = ismissing(:StartGrazingPeriod2) &&
            !iszero(:DayGrazing2) && !iszero(:LivestockUnits2) ?
            :StartGrazingPeriod1 + 1 : :StartGrazingPeriod2

        ## for 2 rows the start of the third grazing period was missing
        ## set to start of second grazing period + one month (= July & November)
        @rtransform :StartGrazingPeriod3 = ismissing(:StartGrazingPeriod3) &&
            !iszero(:DayGrazing3) && !iszero(:LivestockUnits3) ?
            :StartGrazingPeriod2 + 1 : :StartGrazingPeriod3

        ## for 1 row the start of the fourth grazing period was missing
        ## set to start of third grazing period + one month (= November)
        @rtransform :StartGrazingPeriod4 = ismissing(:StartGrazingPeriod4) &&
            !iszero(:DayGrazing4) && !iszero(:LivestockUnits4) ?
            :StartGrazingPeriod3 + 1 : :StartGrazingPeriod4

        ## set the start of the grazig to the first day of the month
        @rtransform :start_graz1 = :isgrazed1 ?
            Dates.Date(:Year, :StartGrazingPeriod1) : missing

        ## set the end of the first grazing period to the start date + the number of days
        @rtransform :end_graz1 = :isgrazed1 ?
            :start_graz1 + Dates.Day(:DayGrazing1) : missing

        ## if the start of the second grazing period is before the end of the first
        ## set the start of the second to the end of the first + one day
        @rtransform :start_graz2 = :isgrazed2 ?
            Dates.Date(:Year, :StartGrazingPeriod2) : missing
        @rtransform :start_graz2 = :isgrazed2 && :start_graz2 <= :end_graz1 ?
            :end_graz1 + Dates.Day(1) : :start_graz2

        ## set the end of the second grazing period to the start date + the number of days
        @rtransform :end_graz2 = :isgrazed2 ?
            :start_graz2 + Dates.Day(:DayGrazing2) : missing

        ## if the start of the third grazing period is before the end of the second
        ## set the start of the third to the end of the second + one day
        @rtransform :start_graz3 = :isgrazed3 ?
            Dates.Date(:Year, :StartGrazingPeriod3) : missing
        @rtransform :start_graz3 = :isgrazed3 && :start_graz3 <= :end_graz2 ?
            :end_graz2 + Dates.Day(1) : :start_graz3

        ## set the end of the third grazing period to the start date + the number of days
        @rtransform :end_graz3 = :isgrazed3 ?
            :start_graz3 + Dates.Day(:DayGrazing3) : missing

        ## if the start of the fourth grazing period is before the end of the third
        ## set the start of the fourth to the end of the third + one day
        @rtransform :start_graz4 = :isgrazed4 ?
            Dates.Date(:Year, :StartGrazingPeriod4) : missing
        @rtransform :start_graz4 = :isgrazed4 && :start_graz4 <= :end_graz3 ?
            :end_graz3 + Dates.Day(1) : :start_graz4

        ## set the end of the fourth grazing period to the start date + the number of days
        @rtransform :end_graz4 = :isgrazed4 ?
            :start_graz4 + Dates.Day(:DayGrazing4) : missing
    end

    test1 = sum(abs.(df.TotalGrazing .- df.intens_total) .> 10)
    test2 = df[ismissing.(df.StartGrazingPeriod1), :]
    test3 = df[ismissing.(df.StartGrazingPeriod2) .&& .! iszero.(df.DayGrazing2) .&&
               .! iszero.(df.LivestockUnits2), :]
    test4 = df[ismissing.(df.StartGrazingPeriod3) .&& .! iszero.(df.DayGrazing3) .&&
               .! iszero.(df.LivestockUnits3), :]
    test5 = df[ismissing.(df.StartGrazingPeriod4) .&& .! iszero.(df.DayGrazing4) .&&
               .! iszero.(df.LivestockUnits4), :]

    ## two rows have a small deviation in the total grazing intensity in my calculations
    @show test1
    @show nrow(test2)
    @show nrow(test3)
    @show nrow(test4)
    @show nrow(test5)

    display(scatter(df.TotalGrazing, df.intens_total, color = (:black, 0.2)))

    ## produce the final dataframe that is used for the model input
    final_df = @chain df begin
        @rename begin
            :year = :Year
            :plotID = :EP_PlotID
        end
        @rtransform begin
            :inten_graz1 = round(:inten_graz1 / :DayGrazing1; digits=3)
            :inten_graz2 = round(:inten_graz2 / :DayGrazing2; digits=3)
            :inten_graz3 = round(:inten_graz3 / :DayGrazing3; digits=3)
            :inten_graz4 = round(:inten_graz4 / :DayGrazing4; digits=3)
        end
        @select begin
            :plotID
            :year
            :inten_graz1
            :inten_graz2
            :inten_graz3
            :inten_graz4
            :start_graz1
            :start_graz2
            :start_graz3
            :start_graz4
            :end_graz1
            :end_graz2
            :end_graz3
            :end_graz4
        end

    end

    return final_df
end

df_supple, df_supple_sum = supplementary_feeding("../data/")
df = load_grazing("../data/")

scatter(vec(Matrix(@select(df, $(r"inten_")))))


CSV.write("supplementary_feeding.csv", df_supple_sum)
CSV.write("grazing.csv", df)

# move file to GrasslandTraitSim/assets/data/input


let
    function find_start_month(general_start, start_first_period)
        if ! ismissing(general_start)
            return convert_month(general_start)
        elseif ! ismissing(start_first_period)
            return convert_month(start_first_period)
        else
            return 6
        end
    end

    function find_end_month(general_end)
        if ! ismissing(general_end)
            return convert_month(general_end)
        else
           return 10
        end
    end

    function load_grazing_simple(path)
        lui_df = CSV.read(
            path * "LUI_tool_input.csv",
            DataFrame)

        df = CSV.read(
            path * "nonpublic_management_input.csv",
            DataFrame;
            missingstring=["", "NA"]);

        df = mapcols(col -> replace(col, "-1" => missing), df)
        df = mapcols(col -> replace(col, -1 => missing), df)
        df = mapcols(col -> replace(col, "ja" => true), df)
        df = mapcols(col -> replace(col, "nein" => false), df)

        df = @chain df begin
            innerjoin(@select(lui_df, :Year, :EP_PlotID, :TotalGrazing), _, on = [:Year, :EP_PlotID])

            @transform :startmonth = find_start_month.(:StartGrazing, :StartGrazingPeriod1)
            @transform :endmonth = find_end_month.(:EndGrazing)

            @transform :start_graz1 = Dates.firstdayofmonth.(Dates.Date.(:Year, :startmonth))
            @transform :end_graz1 = Dates.lastdayofmonth.(Dates.Date.(:Year, :endmonth))

            @transform :days_grazing = :end_graz1 .- :start_graz1
            @transform :inten_graz1 = :TotalGrazing ./ Dates.value.(:days_grazing)

            @rtransform :start_graz1 = iszero(:TotalGrazing) ? missing : :start_graz1
            @rtransform :end_graz1 = iszero(:TotalGrazing) ? missing : :end_graz1


            @transform :plotID = convert_id.(:EP_PlotID)
            @rename :year = :Year
            @orderby :plotID
            # @select :plotID :year :TotalGrazing :StartGrazing :EndGrazing :start_graz1 :end_graz1 :days_grazing :inten_graz1

            @select :plotID :year :inten_graz1 :start_graz1 :end_graz1
        end

        df
    end
    df = load_grazing_simple("../data/")
    CSV.write("grazing.csv", df)
end
