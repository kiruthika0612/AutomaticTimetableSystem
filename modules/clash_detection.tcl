proc openClashDetection {} {
    if {[winfo exists .clash]} {
        raise .clash
        return
    }

    toplevel .clash
    wm title .clash "Clash Detection"
    wm geometry .clash "850x520"
    .clash configure -bg white

    label .clash.title -text "CLASH DETECTION" -font {Arial 16 bold} -bg "#1565C0" -fg white
    pack .clash.title -fill x -pady 10

    frame .clash.actions -bg white
    pack .clash.actions -pady 8

    button .clash.check -text "Check Clashes" -width 16 -command {checkTimetableClashes}
    pack .clash.check -in .clash.actions -side left -padx 6
    button .clash.close -text "Close" -width 10 -command {destroy .clash}
    pack .clash.close -in .clash.actions -side left -padx 6

    text .clash.txt -width 110 -height 24
    pack .clash.txt -fill both -expand 1 -padx 10 -pady 8

    applyThemeToWindow .clash
    checkTimetableClashes
}

proc checkTimetableClashes {} {
    global db
    .clash.txt delete 1.0 end
    .clash.txt insert end "Clash Detection Result\n"
    .clash.txt insert end "======================\n\n"

    set found 0

    .clash.txt insert end "Faculty clashes:\n"
    set sqlFaculty {
        SELECT day_of_week, period_number, start_time, staff_name, COUNT(*) AS total
        FROM timetable_slots
        WHERE slot_type IN ('Class', 'Lab') AND staff_name IS NOT NULL AND trim(staff_name) <> '' AND staff_name <> 'Not Assigned'
        GROUP BY day_of_week, period_number, start_time, staff_name
        HAVING COUNT(*) > 1
        ORDER BY day_of_week, period_number
    }
    db eval $sqlFaculty row {
        set found 1
        .clash.txt insert end "[format {  %s period %s at %s: %s assigned %s times} $row(day_of_week) $row(period_number) $row(start_time) $row(staff_name) $row(total)]\n"
    }

    .clash.txt insert end "\nClassroom clashes:\n"
    set sqlRoom {
        SELECT day_of_week, period_number, start_time, classroom, COUNT(*) AS total
        FROM timetable_slots
        WHERE slot_type IN ('Class', 'Lab') AND classroom IS NOT NULL AND trim(classroom) <> ''
        GROUP BY day_of_week, period_number, start_time, classroom
        HAVING COUNT(*) > 1
        ORDER BY day_of_week, period_number
    }
    db eval $sqlRoom row {
        set found 1
        .clash.txt insert end "[format {  %s period %s at %s: room %s used %s times} $row(day_of_week) $row(period_number) $row(start_time) $row(classroom) $row(total)]\n"
    }

    .clash.txt insert end "\nSection clashes:\n"
    set sqlSection {
        SELECT day_of_week, period_number, start_time, department, section, COUNT(*) AS total
        FROM timetable_slots
        WHERE slot_type IN ('Class', 'Lab') AND department IS NOT NULL AND trim(department) <> '' AND section IS NOT NULL AND trim(section) <> ''
        GROUP BY day_of_week, period_number, start_time, department, section
        HAVING COUNT(*) > 1
        ORDER BY day_of_week, period_number
    }
    db eval $sqlSection row {
        set found 1
        .clash.txt insert end "[format {  %s period %s at %s: %s section %s has %s classes} $row(day_of_week) $row(period_number) $row(start_time) $row(department) $row(section) $row(total)]\n"
    }

    if {!$found} {
        .clash.txt insert end "\nNo clashes found.\n"
    }
}
