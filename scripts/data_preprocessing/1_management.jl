using DataFrames
using DataFramesMeta
using Statistics
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

function convert_month(str)
    if ismissing(str)
        return missing
    end

    month_strs = [
        "Januar", "Februar", "Maerz", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember"]

    return findfirst(str .== month_strs)
end


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
        path * "management_input.csv",
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


        @subset startswith.(:plotID, "H")
        @select :plotID :year :inten_graz1 :start_graz1 :end_graz1
    end


    df
end

function load_mowing(path)
    function countdate(X)
        ndata = 0
        for i in eachindex(X)
            if !ismissing(X[i])
                ndata += 1
            end
        end
        return ndata
    end

    function convert_date(date_string, year = nothing)
        if ismissing(date_string)
            return missing
        else
            if contains(date_string, "6/17/2019")
                date_string = "06/07/2019"
            end

            if date_string ∈ ["0", "-2", "-3"]
                return missing
            end

            if date_string == "Fruehjahr"
                return Dates.Date(year, 5)
            end

            if date_string == "Herbst"
                return Dates.Date(year, 10, 20)
            end

            if date_string == "July"
                return Dates.Date(year, 7)
            end

            if date_string == "November"
                return Dates.Date(year, 11)
            end

            return Dates.Date(date_string, "dd/mm/yyyy")
        end
    end

    df = CSV.read(
        path * "management_input.csv",
        DataFrame;
        missingstring=["", "NA"]);

    df = mapcols(col -> replace(col, "-1" => missing), df)
    df = mapcols(col -> replace(col, -1 => missing), df)

    mowing_df = @chain df begin
        @transform :plotID = convert_id.(:EP_PlotID)
        @subset startswith.(:plotID, "H")
        @orderby :plotID :Year
        @select :Year :plotID :Cuts $(r"DateCut") $(r"DateMulching") $(r"CutHeight_cm")
        disallowmissing!(:Year)
    end

    ## missing dates for mowing
    cutdate_df = @chain mowing_df begin
        @select :plotID :Year :Cuts  $(r"DateCut") $(r"DateMulching")
        @transform :DateCut1 = convert_date.(:DateCut1)
        @transform :DateCut2 = convert_date.(:DateCut2)
        @transform :DateCut3 = convert_date.(:DateCut3)
        @transform :DateCut4 = convert_date.(:DateCut4)
        @transform :DateCut5 = convert_date.(:DateCut5)
        @transform :DateMulching1 = convert_date.(:DateMulching1, :Year)
        @transform :DateMulching2 = convert_date.(:DateMulching2, :Year)

        ## after 2010: complete mulch is counted as cut
        @rtransform :DateMulching1 = :Year > 2010 ? missing : :DateMulching1
        @rtransform :DateMulching2 = :Year > 2010 ? missing : :DateMulching2

        ## manual change: missing mulching date for HEG5 in 2006
        @rtransform :DateMulching1 = :plotID == "HEG05" && :Year == 2006 ? Dates.Date(:Year, 10, 20) : :DateMulching1

        @rtransform :ndates = countdate([:DateCut1, :DateCut2, :DateCut3, :DateCut4, :DateCut5,
                                         :DateMulching1, :DateMulching2])
    end

    ## Year != year of given date, the year is more trustworty
    function correct_year(date, year)
        doy = Dates.dayofyear(date)
        return Dates.Date(year) + Dates.Day(doy)
    end

    cutdate_df = @chain cutdate_df begin
        @rtransform :year_date1_wrong = !ismissing.(:DateCut1) && Dates.year(:DateCut1) != :Year
        @rtransform :year_date2_wrong = !ismissing.(:DateCut2) && Dates.year(:DateCut2) != :Year
        @rtransform :year_date3_wrong = !ismissing.(:DateCut3) && Dates.year(:DateCut3) != :Year
        @rtransform :year_date4_wrong = !ismissing.(:DateCut4) && Dates.year(:DateCut4) != :Year
        @rtransform :year_date5_wrong = !ismissing.(:DateCut5) && Dates.year(:DateCut5) != :Year
        @rtransform :year_mulchdate1_wrong = !ismissing.(:DateMulching1) && Dates.year(:DateMulching1) != :Year
        @rtransform :year_mulchdate2_wrong = !ismissing.(:DateMulching2) && Dates.year(:DateMulching2) != :Year

        @rtransform :DateCut1 = :year_date1_wrong ? correct_year(:DateCut1, :Year) : :DateCut1
        @rtransform :DateCut2 = :year_date2_wrong ? correct_year(:DateCut2, :Year) : :DateCut2
        @rtransform :DateCut3 = :year_date3_wrong ? correct_year(:DateCut3, :Year) : :DateCut3
        @rtransform :DateCut4 = :year_date4_wrong ? correct_year(:DateCut4, :Year) : :DateCut4
        @rtransform :DateCut5 = :year_date5_wrong ? correct_year(:DateCut5, :Year) : :DateCut5
        @rtransform :DateMulching1 = :year_mulchdate1_wrong ? correct_year(:DateMulching1, :Year) : :DateMulching1
        @rtransform :DateMulching2 = :year_mulchdate2_wrong ? correct_year(:DateMulching2, :Year) : :DateMulching2

        ## for debugging only:
        # @subset :year_mulchdate2_wrong
    end


    ## if we have the mowing date 1 and 3, fill date 2 in between
    function find_date_inbetween(date1, date2)
        days_diff = date2 - date1
        return date1 + Dates.Day(round(days_diff.value/2))
    end

    cutdate_df = @chain cutdate_df begin
        @rtransform :fill_inbetween_date2 = !ismissing(:DateCut1) &&
            ismissing(:DateCut2) &&
            !ismissing(:DateCut3) &&
            :ndates == 2 &&
            :Cuts == 3
        @rtransform :DateCut2 = :fill_inbetween_date2 ? find_date_inbetween(:DateCut1, :DateCut3) : :DateCut2

        ## for debugging only:
        # @subset :fill_inbetween_date2
    end

    ## if we have no mowing date and one mowing event is reported
    ## use the median mowing date when only one mowing event occured
    mowing_one_event_df = @chain cutdate_df begin
        @rsubset :ndates == 1 && :Cuts == 1 && !ismissing(:DateCut1)
        @transform :doy = Dates.dayofyear.(:DateCut1)
    end
    doy_one_event = Int(round(median(mowing_one_event_df.doy)))

    function fill_date(year, doy)
        first_day_of_year = Dates.Date(year)
        return first_day_of_year + Dates.Day(doy)
    end

    cutdate_df = @chain cutdate_df begin
        @rtransform :no_date_one_event = :ndates == 0 && :Cuts == 1
        @rtransform :DateCut1 = :no_date_one_event ? fill_date(:Year, doy_one_event) : :DateCut1

        ## for debugging only:
        # @subset :no_date_one_event
    end

    ## if we have one mowing date and two mowing events are reported
    ## use the median mowing date for the second event when two mowing event occured
    mowing_two_events_df = @chain cutdate_df begin
        @rsubset :ndates == 2 && :Cuts == 2 && !ismissing(:DateCut1) && !ismissing(:DateCut2)
        @transform :doy_first = Dates.dayofyear.(:DateCut1)
        @transform :doy_second = Dates.dayofyear.(:DateCut2)
    end
    doy_first_event_two_total = Int(round(median(mowing_two_events_df.doy_first)))
    doy_second_event_two_total = Int(round(median(mowing_two_events_df.doy_second)))

    cutdate_df = @chain cutdate_df begin
        @rtransform :no_second_date_two_events = :ndates == 1 && !ismissing(:DateCut1) && :Cuts == 2
        @rtransform :DateCut2 = :no_second_date_two_events ? fill_date(:Year, doy_second_event_two_total) : :DateCut2

        ## for debugging only:
        # @subset :no_second_date_two_events
    end

    ## two mowing event occured, no dates reported
    ## we use the median of the first and second date for sites with two mowing events
    cutdate_df = @chain cutdate_df begin
        @rtransform :no_dates_two_events = :ndates == 0  && :Cuts == 2
        @rtransform :DateCut1 = :no_dates_two_events ? fill_date(:Year, doy_first_event_two_total) : :DateCut1
        @rtransform :DateCut2 = :no_dates_two_events ? fill_date(:Year, doy_second_event_two_total) : :DateCut2

        ## for debugging only:
        # @subset :no_dates_two_events
    end

    ## three mowing event occured, no dates reported
    ## we use the median of the first, second and third date for sites with three mowing events
    mowing_three_events_df = @chain cutdate_df begin
        @rsubset :ndates == 3 && :Cuts == 3 &&
                 !ismissing(:DateCut1) && !ismissing(:DateCut2) && !ismissing(:DateCut3)
        @transform :doy_first = Dates.dayofyear.(:DateCut1)
        @transform :doy_second = Dates.dayofyear.(:DateCut2)
        @transform :doy_third = Dates.dayofyear.(:DateCut3)

    end
    doy_first_event_three_total = Int(round(median(mowing_three_events_df.doy_first)))
    doy_second_event_three_total = Int(round(median(mowing_three_events_df.doy_second)))
    doy_third_event_three_total = Int(round(median(mowing_three_events_df.doy_third)))

    cutdate_df = @chain cutdate_df begin
        @rtransform :no_dates_three_events = :ndates == 0  && :Cuts == 3
        @rtransform :DateCut1 = :no_dates_three_events ? fill_date(:Year, doy_first_event_three_total) : :DateCut1
        @rtransform :DateCut2 = :no_dates_three_events ? fill_date(:Year, doy_second_event_three_total) : :DateCut2
        @rtransform :DateCut3 = :no_dates_three_events ? fill_date(:Year, doy_third_event_three_total) : :DateCut3

        ## for debugging only:
        # @subset :no_dates_three_events
    end

    ## Remove mulching dates if the total number of cuts is too high
    ## this means, the mulching was only partially and is not conuted as normal cut
    cutdate_df = @chain cutdate_df begin
        @rtransform :ndates = countdate([:DateCut1, :DateCut2, :DateCut3, :DateCut4, :DateCut5,
                                         :DateMulching1, :DateMulching2])
        @rtransform :DateMulching1 = :ndates > :Cuts ? missing : :DateMulching1

        @rtransform :ndates = countdate([:DateCut1, :DateCut2, :DateCut3, :DateCut4, :DateCut5,
                                         :DateMulching1, :DateMulching2])
        @rtransform :DateMulching2 = :ndates > :Cuts ? missing : :DateMulching2

        @rtransform :ndates = countdate([:DateCut1, :DateCut2, :DateCut3, :DateCut4, :DateCut5,
                                         :DateMulching1, :DateMulching2])

        ## for debugging only:
        # @subset :no_dates_three_events
    end

    ## only for debugging:
    # @subset cutdate_df :ndates .!= :Cuts

    cutdate_df = @chain cutdate_df begin
        @select :plotID :Year $(r"DateCut") $(r"DateMulching")
        @rename :DateCut6 = :DateMulching1
        @rename :DateCut7 = :DateMulching2
        stack([:DateCut1, :DateCut2, :DateCut3, :DateCut4, :DateCut5, :DateCut6, :DateCut7],
              variable_name=:CutNumber, value_name=:t)
        @subset .! ismissing.(:t)
        @rtransform :CutofYear = :CutNumber[end]
        @select :plotID :Year :CutofYear :t
        @orderby :plotID :Year
    end



    cutheight_df = @chain mowing_df begin
        @select :plotID :Year $(r"CutHeight_cm")
        stack(_, [:CutHeight_cm1, :CutHeight_cm2, :CutHeight_cm3, :CutHeight_cm4, :CutHeight_cm5],
            variable_name=:CutNumber, value_name=:CutHeight)
        @rtransform :CutofYear = :CutNumber[end]

        ## set zeros to missing (no cutting machine cuts at zero cm)
        @rtransform :CutHeight = !ismissing(:CutHeight) && iszero(:CutHeight) ? missing : :CutHeight

        @subset .! ismissing.(:CutHeight)
        @select :plotID :Year :CutofYear :CutHeight
    end
    median_cutheight = median(cutheight_df.CutHeight)


    @chain cutdate_df begin
        leftjoin(_, cutheight_df, on = ["CutofYear", "Year", "plotID"])
        @subset .! ismissing.(:CutHeight)
        @rtransform :CutHeight = ismissing(:CutHeight) ? median_cutheight : :CutHeight
        @transform :CutHeight = :CutHeight ./ 100
        @orderby :plotID :t
        @select :plotID :t :CutHeight
    end
end

function load_management(path)
    mowing_df = load_mowing(path)
    grazing_df = load_grazing_simple(path)

    d = grazing_df
    startyear = minimum(d.year)
    endyear = maximum(d.year)
    days = Dates.Date(startyear):Dates.lastdayofyear(Dates.Date(endyear))
    plotIDs = unique(d.plotID)

    df = crossjoin(DataFrame(t = collect(days)), DataFrame(plotID = collect(plotIDs)))
    @transform! df :x = 1
    @transform! df :y = 1
    @transform! df :LD = NaN
    @transform! df :CUT = NaN

    for row in eachrow(grazing_df)
        if row.inten_graz1 > 0
            graz_dates = row.start_graz1:row.end_graz1
            graz_plotID = row.plotID
            graz_inten = row.inten_graz1
            f = (df.plotID .== graz_plotID) .&& (df.t .>= graz_dates[1]) .&& (df.t .<= graz_dates[end])
            df[f, :LD] .= graz_inten
        end
    end

    for row in eachrow(mowing_df)
        f = df.t .== row.t .&& df.plotID .== row.plotID
        df[f, :CUT] .= row.CutHeight
    end

    df = @chain df begin
        @select :LD :CUT :t :x :y :plotID
        @rtransform :LD = isnan(:LD) ? missing : round(:LD; digits = 4)
        @rtransform :CUT = isnan(:CUT) ? missing : :CUT
        # @subset .! ismissing.(:CUT) .|| .! ismissing.(:LD)
        @orderby :plotID :t
    end
    return df
end

df_management = load_management("../Raw_data/BE/")
CSV.write("../Input_data/Management.csv", df_management)
