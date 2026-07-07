proc openSettings {} {
    if {[winfo exists .settings]} {
        raise .settings
        return
    }

    toplevel .settings
    wm title .settings "Settings"
    wm geometry .settings "680x500"
    .settings configure -bg white

    label .settings.title -text "SETTINGS" -font {Arial 16 bold} -bg "#1565C0" -fg white
    pack .settings.title -fill x -pady 10

    frame .settings.form -bg white
    pack .settings.form -pady 8

    label .settings.form.ly -text "Year :" -bg white
    grid .settings.form.ly -row 0 -column 0 -padx 8 -pady 5 -sticky e
    ttk::combobox .settings.form.year -values {"All Years" "1st Year" "2nd Year" "3rd Year" "4th Year"} -width 12
    .settings.form.year set "All Years"
    grid .settings.form.year -row 0 -column 1 -padx 8 -sticky w
    bind .settings.form.year <<ComboboxSelected>> {refreshPeriodList}

    label .settings.form.l1 -text "Period No :" -bg white
    grid .settings.form.l1 -row 1 -column 0 -padx 8 -pady 5 -sticky e
    entry .settings.form.period -width 8
    grid .settings.form.period -row 1 -column 1 -padx 8 -sticky w

    label .settings.form.l2 -text "Start Time :" -bg white
    grid .settings.form.l2 -row 2 -column 0 -padx 8 -pady 5 -sticky e
    entry .settings.form.start -width 12
    grid .settings.form.start -row 2 -column 1 -padx 8 -sticky w

    label .settings.form.l3 -text "End Time :" -bg white
    grid .settings.form.l3 -row 3 -column 0 -padx 8 -pady 5 -sticky e
    entry .settings.form.end -width 12
    grid .settings.form.end -row 3 -column 1 -padx 8 -sticky w

    frame .settings.actions -bg white
    pack .settings.actions -pady 8

    button .settings.save -text "Save Period" -width 14 -command {savePeriod}
    pack .settings.save -in .settings.actions -side left -padx 5
    button .settings.delete -text "Delete Selected" -width 14 -command {deleteSelectedPeriod}
    pack .settings.delete -in .settings.actions -side left -padx 5
    button .settings.reset -text "Reset 9 Periods" -width 14 -command {resetDefaultPeriods}
    pack .settings.reset -in .settings.actions -side left -padx 5
    button .settings.close -text "Close" -width 10 -command {destroy .settings}
    pack .settings.close -in .settings.actions -side left -padx 5

    listbox .settings.list -width 75 -height 14
    pack .settings.list -fill both -expand 1 -padx 10 -pady 8
    bind .settings.list <<ListboxSelect>> {loadSelectedPeriod}

    applyThemeToWindow .settings
    refreshPeriodList
}

proc refreshPeriodList {} {
    global db
    .settings.list delete 0 end
    set year [.settings.form.year get]
    set escYear [string map {"'" "''"} $year]
    db eval "SELECT period_id, year, period_number, start_time, end_time FROM periods WHERE year = '$escYear' ORDER BY period_number" row {
        .settings.list insert end "[format {%d | %s | Period %d | %s - %s} $row(period_id) $row(year) $row(period_number) $row(start_time) $row(end_time)]"
    }
}

proc clearPeriodForm {} {
    .settings.form.period delete 0 end
    .settings.form.start delete 0 end
    .settings.form.end delete 0 end
}

proc loadSelectedPeriod {} {
    set sel [.settings.list curselection]
    if {$sel eq ""} {
        return
    }
    set line [.settings.list get $sel]
    regexp {^[0-9]+ \| .+ \| Period ([0-9]+) \| ([0-9:]+) - ([0-9:]+)} $line -> period start end
    clearPeriodForm
    .settings.form.period insert 0 $period
    .settings.form.start insert 0 $start
    .settings.form.end insert 0 $end
}

proc savePeriod {} {
    global db
    set period [.settings.form.period get]
    set year [.settings.form.year get]
    set start [.settings.form.start get]
    set end [.settings.form.end get]

    if {$year eq "" || ![string is integer -strict $period] || $start eq "" || $end eq ""} {
        tk_messageBox -title "Validation" -message "Enter year, period number, start time and end time." -icon warning
        return
    }

    set escYear [string map {"'" "''"} $year]
    set escStart [string map {"'" "''"} $start]
    set escEnd [string map {"'" "''"} $end]
    set existing 0
    db eval "SELECT COUNT(*) AS total FROM periods WHERE year = '$escYear' AND period_number = $period" row {
        set existing $row(total)
    }

    if {$existing > 0} {
        db eval "UPDATE periods SET start_time = '$escStart', end_time = '$escEnd' WHERE year = '$escYear' AND period_number = $period"
    } else {
        db eval "INSERT INTO periods(year, period_number, start_time, end_time) VALUES('$escYear', $period, '$escStart', '$escEnd')"
    }

    refreshPeriodList
    clearPeriodForm
}

proc deleteSelectedPeriod {} {
    global db
    set sel [.settings.list curselection]
    if {$sel eq ""} {
        tk_messageBox -title "Delete" -message "Select a period to delete." -icon info
        return
    }
    set line [.settings.list get $sel]
    regexp {^([0-9]+) \|} $line -> periodId
    db eval "DELETE FROM periods WHERE period_id = $periodId"
    refreshPeriodList
    clearPeriodForm
}

proc resetDefaultPeriods {} {
    global db
    set year [.settings.form.year get]
    if {$year eq ""} {
        set year "All Years"
    }
    if {[tk_messageBox -type yesno -icon question -title "Reset Periods" -message "Reset $year periods to 08:30 - 16:30 with 9 periods of 45 minutes?"] ne "yes"} {
        return
    }

    set escYear [string map {"'" "''"} $year]
    db eval "DELETE FROM periods WHERE year = '$escYear'"
    db eval "INSERT INTO periods(year, period_number, start_time, end_time) VALUES
        ('$escYear', 1, '08:30', '09:15'),
        ('$escYear', 2, '09:15', '10:00'),
        ('$escYear', 3, '10:00', '10:45'),
        ('$escYear', 4, '11:00', '11:45'),
        ('$escYear', 5, '11:45', '12:30'),
        ('$escYear', 6, '13:15', '14:00'),
        ('$escYear', 7, '14:00', '14:45'),
        ('$escYear', 8, '15:00', '15:45'),
        ('$escYear', 9, '15:45', '16:30')"

    refreshPeriodList
    clearPeriodForm
}
