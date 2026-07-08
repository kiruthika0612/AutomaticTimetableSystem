package require Ttk

proc openReports {} {
    global currentReportType
    set currentReportType ""

    ensureReportTables
    if {[winfo exists .reports]} {
        raise .reports
        return
    }
    toplevel .reports
    wm title .reports "Reports"
    wm geometry .reports "800x520"
    .reports configure -bg white

    label .reports.title -text "REPORTS" -font {Arial 16 bold} -bg "#1565C0" -fg white
    pack .reports.title -fill x -pady 10

    frame .reports.controls -bg white
    pack .reports.controls -pady 8 -fill x

    label .reports.controls.l1 -text "Report Type:" -bg white
    grid .reports.controls.l1 -row 0 -column 0 -padx 8 -pady 6 -sticky e

    ttk::combobox .reports.controls.cb -values {"Faculty List" "Subjects" "Classrooms" "Timetables" "Timetable Slots" "Breaktimes"} -width 35
    grid .reports.controls.cb -row 0 -column 1 -padx 8 -pady 6 -sticky w

    button .reports.controls.view -text "View" -width 12 -command {viewReport}
    grid .reports.controls.view -row 0 -column 2 -padx 8 -pady 6

    button .reports.controls.export -text "Export" -width 12 -command {exportReport}
    grid .reports.controls.export -row 0 -column 3 -padx 8 -pady 6
    button .reports.controls.delete -text "Delete Selected" -width 15 -command {deleteSelectedReportRow}
    grid .reports.controls.delete -row 0 -column 4 -padx 8 -pady 6

    frame .reports.content -bg white
    pack .reports.content -fill both -expand 1 -padx 8 -pady 8

    ttk::style configure Report.Treeview -font {Arial 10} -rowheight 30
    ttk::style configure Report.Treeview.Heading -font {Arial 10 bold} -background "#1565C0" -foreground white
    ttk::treeview .reports.content.tree -show headings -selectmode browse -style Report.Treeview
    scrollbar .reports.content.ys -orient vertical -command ".reports.content.tree yview"
    scrollbar .reports.content.xs -orient horizontal -command ".reports.content.tree xview"
    .reports.content.tree configure -yscrollcommand ".reports.content.ys set" -xscrollcommand ".reports.content.xs set"
    .reports.content.tree tag configure odd -background "#F7FBFF"
    .reports.content.tree tag configure even -background "#EAF3FC"
    .reports.content.tree tag configure break -background "#FFF3E0"
    .reports.content.tree tag configure lab -background "#E8F5E9"

    grid .reports.content.tree -row 0 -column 0 -sticky nsew
    grid .reports.content.ys -row 0 -column 1 -sticky ns
    grid .reports.content.xs -row 1 -column 0 -sticky ew
    grid rowconfigure .reports.content 0 -weight 1
    grid columnconfigure .reports.content 0 -weight 1

    frame .reports.actions -bg white
    pack .reports.actions -pady 8
    button .reports.close -text "Close" -command {destroy .reports}
    pack .reports.close -in .reports.actions -side left -padx 6

    applyThemeToWindow .reports
}

proc reportCleanValue {value} {
    if {$value eq ""} {
        return ""
    }
    return [string map [list "\r" " " "\n" " "] $value]
}

proc clearReportTable {} {
    if {![winfo exists .reports.content.tree]} {
        return
    }
    .reports.content.tree delete [.reports.content.tree children {}]
    .reports.content.tree configure -columns {}
}

proc setReportTable {headers rows} {
    clearReportTable
    if {![winfo exists .reports.content.tree]} {
        return
    }

    .reports.content.tree configure -columns $headers
    foreach header $headers {
        .reports.content.tree heading $header -text $header
        set width [expr {[string length $header] * 11 + 40}]
        if {$width < 90} {
            set width 90
        }
        .reports.content.tree column $header -width $width -minwidth 70 -stretch 1 -anchor center
    }

    set rowIndex 0
    foreach row $rows {
        set values {}
        for {set i 0} {$i < [llength $headers]} {incr i} {
            set value [reportCleanValue [lindex $row $i]]
            lappend values $value
            set header [lindex $headers $i]
            set width [expr {[string length $value] * 8 + 45}]
            if {$width > [.reports.content.tree column $header -width]} {
                .reports.content.tree column $header -width $width
            }
        }

        set tag [expr {$rowIndex % 2 == 0 ? "even" : "odd"}]
        foreach value $values {
            set rowType [string tolower $value]
            if {$rowType eq "break"} {
                set tag "break"
                break
            } elseif {$rowType eq "lab"} {
                set tag "lab"
            }
        }
        .reports.content.tree insert {} end -values $values -tags $tag
        incr rowIndex
    }

    if {[llength $rows] == 0} {
        .reports.content.tree insert {} end -values [list "No records found"] -tags even
    }
}

proc reportTimeToMinutes {timeValue} {
    if {![regexp {^([0-9][0-9]?):([0-9][0-9])$} $timeValue -> hour minute]} {
        return -1
    }
    set rawHour $hour
    scan $hour %d hour
    scan $minute %d minute
    if {[string length $rawHour] == 1 && $hour >= 1 && $hour <= 4} {
        incr hour 12
    }
    if {$hour < 0 || $hour > 23 || $minute < 0 || $minute > 59} {
        return -1
    }
    return [expr {$hour * 60 + $minute}]
}

proc reportDisplayTime {timeValue} {
    if {![regexp {^([0-9][0-9]?):([0-9][0-9])$} $timeValue -> hour minute]} {
        return $timeValue
    }
    scan $hour %d hour
    scan $minute %d minute
    if {$hour > 12} {
        set hour [expr {$hour - 12}]
    }
    return [format "%d:%02d" $hour $minute]
}

proc reportTimetableDaySortValue {day} {
    switch -- $day {
        Monday { return 1 }
        Tuesday { return 2 }
        Wednesday { return 3 }
        Thursday { return 4 }
        Friday { return 5 }
        default { return 6 }
    }
}

proc compareReportTimetableDays {left right} {
    return [expr {[reportTimetableDaySortValue $left] - [reportTimetableDaySortValue $right]}]
}

proc reportTimetableSlotEndTime {slotType remarks} {
    if {[string equal -nocase $slotType "Break"] && [regexp {^[0-9][0-9]?:[0-9][0-9][[:space:]]*-[[:space:]]*([0-9][0-9]?:[0-9][0-9])} $remarks -> endTime]} {
        return $endTime
    }
    if {[regexp {Ends:[[:space:]]*([0-9][0-9]?:[0-9][0-9])} $remarks -> endTime]} {
        return $endTime
    }
    return ""
}

proc reportTimetableColumnLabel {startTime endTime} {
    if {$endTime eq ""} {
        return [reportDisplayTime $startTime]
    }
    return "[reportDisplayTime $startTime]-[reportDisplayTime $endTime]"
}

proc showReportTimetableGrid {} {
    global db currentReportType
    set currentReportType "Timetable Slots"

    set timetableId ""
    db eval {SELECT timetable_id FROM timetables ORDER BY timetable_id DESC LIMIT 1} row {
        set timetableId $row(timetable_id)
    }
    if {$timetableId eq ""} {
        setReportTable [list "Day/Time"] {}
        return
    }

    set columns {}
    set days {}
    array unset cells
    set sql "SELECT day_of_week, start_time, slot_type, subject_name, classroom, remarks FROM timetable_slots WHERE timetable_id = $timetableId ORDER BY CASE day_of_week WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 ELSE 6 END, period_number, start_time"
    db eval $sql row {
        set day $row(day_of_week)
        set start $row(start_time)
        set type $row(slot_type)
        set subject $row(subject_name)
        set classroom $row(classroom)
        set remarks $row(remarks)
        set end [reportTimetableSlotEndTime $type $remarks]
        set startMinutes [reportTimeToMinutes $start]
        set endMinutes [reportTimeToMinutes $end]
        if {$startMinutes < 0} {
            return
        }
        if {$endMinutes < 0} {
            set endMinutes $startMinutes
        }

        set label [reportTimetableColumnLabel $start $end]
        set key "$startMinutes|$endMinutes|$label"
        if {[lsearch -exact $columns [list $startMinutes $endMinutes $key $label]] < 0} {
            lappend columns [list $startMinutes $endMinutes $key $label]
        }
        if {[lsearch -exact $days $day] < 0} {
            lappend days $day
        }

        if {[string equal -nocase $type "Break"]} {
            set text [string toupper $subject]
        } elseif {[string equal -nocase $type "Lab"] && $classroom ne ""} {
            set text "$subject ($classroom)"
        } else {
            set text $subject
        }
        if {[info exists cells($day,$key)] && $cells($day,$key) ne ""} {
            append cells($day,$key) " / $text"
        } else {
            set cells($day,$key) $text
        }
    }

    set columns [lsort -integer -index 0 $columns]
    set days [lsort -command compareReportTimetableDays $days]
    set headers [list "Day/Time"]
    foreach column $columns {
        lappend headers [lindex $column 3]
    }

    set rows {}
    foreach day $days {
        set displayRow [list $day]
        foreach column $columns {
            set key [lindex $column 2]
            if {[info exists cells($day,$key)]} {
                lappend displayRow $cells($day,$key)
            } else {
                lappend displayRow ""
            }
        }
        lappend rows $displayRow
    }

    setReportTable $headers $rows
}

proc viewReport {} {
    global db currentReportType
    ensureReportTables
    set sel [.reports.controls.cb get]
    set currentReportType $sel
    clearReportTable
    if {$sel eq ""} {
        tk_messageBox -title "Validation" -message "Select a report type." -icon warning
        return
    }

    if {$sel eq "Faculty List"} {
        set rows {}
        db eval {SELECT faculty_id, faculty_name, department, designation, email, phone, COALESCE(hours_allotted, '') AS hours_allotted FROM faculty ORDER BY department, faculty_name} row {
            lappend rows [list $row(faculty_id) $row(faculty_name) $row(department) $row(designation) $row(email) $row(phone) $row(hours_allotted)]
        }
        setReportTable [list ID "Faculty Name" Department Designation Email Phone "Hours/Week"] $rows
    } elseif {$sel eq "Subjects"} {
        set rows {}
        db eval {SELECT s.subject_id, s.subject_name, s.subject_code, s.department, s.credits, s.semester, COALESCE(f.faculty_name, s.faculty_id, '') AS faculty, COALESCE(s.subject_type, 'Theory') AS subject_type, COALESCE(s.lab_hours, 3) AS lab_hours FROM subjects s LEFT JOIN faculty f ON s.faculty_id = f.faculty_id ORDER BY s.department, s.semester, s.subject_name} row {
            lappend rows [list $row(subject_id) $row(subject_name) $row(subject_code) $row(department) $row(credits) $row(semester) $row(faculty) $row(subject_type) $row(lab_hours)]
        }
        setReportTable [list ID Subject Code Department Credits Semester Faculty Type "Lab Periods"] $rows
    } elseif {$sel eq "Classrooms"} {
        set rows {}
        db eval {SELECT classroom_id, room_number, name, building, capacity, department, COALESCE(lab_location, '') AS lab_location FROM classrooms ORDER BY department, room_number} row {
            lappend rows [list $row(classroom_id) $row(room_number) $row(name) $row(building) $row(capacity) $row(department) $row(lab_location)]
        }
        setReportTable [list ID "Room No" Name Building Capacity Department "Lab Location"] $rows
    } elseif {$sel eq "Timetables"} {
        set rows {}
        db eval {SELECT t.timetable_id, t.department, t.section, t.semester, t.year, t.generated_at, t.notes, COUNT(s.slot_id) AS slots FROM timetables t LEFT JOIN timetable_slots s ON t.timetable_id = s.timetable_id GROUP BY t.timetable_id ORDER BY t.timetable_id DESC} row {
            lappend rows [list $row(timetable_id) $row(department) $row(section) $row(semester) $row(year) $row(generated_at) $row(slots) $row(notes)]
        }
        setReportTable [list ID Department Section Semester Year Generated Slots Notes] $rows
    } elseif {$sel eq "Timetable Slots"} {
        showReportTimetableGrid
    } elseif {$sel eq "Breaktimes"} {
        set rows {}
        db eval {SELECT break_id, year, break_name, start_time, end_time FROM breaktimes ORDER BY year, start_time} row {
            lappend rows [list $row(break_id) $row(year) $row(break_name) $row(start_time) $row(end_time)]
        }
        setReportTable [list ID Year "Break Name" "Start Time" "End Time"] $rows
    } else {
        setReportTable [list Message] [list [list "No handler for $sel"]]
    }
}

proc selectedReportId {} {
    set selected [.reports.content.tree selection]
    if {$selected eq ""} {
        return ""
    }
    set values [.reports.content.tree item [lindex $selected 0] -values]
    set id [lindex $values 0]
    if {![string is integer -strict $id]} {
        return ""
    }
    return $id
}

proc deleteSelectedReportRow {} {
    global db currentReportType
    set reportType [.reports.controls.cb get]
    if {$reportType eq ""} {
        set reportType $currentReportType
    }
    if {$reportType eq "Timetable Slots"} {
        tk_messageBox -title "Delete" -message "This view is only the timetable table. To delete an unwanted timetable, select the Timetables report, choose the timetable row, then click Delete Selected." -icon info
        return
    }
    set id [selectedReportId]
    if {$id eq ""} {
        tk_messageBox -title "Delete" -message "Select a report row to delete." -icon info
        return
    }

    set table ""
    set idColumn ""
    set extraSql ""
    switch -- $reportType {
        "Faculty List" {
            set table "faculty"
            set idColumn "faculty_id"
        }
        "Subjects" {
            set table "subjects"
            set idColumn "subject_id"
        }
        "Classrooms" {
            set table "classrooms"
            set idColumn "classroom_id"
        }
        "Timetables" {
            set table "timetables"
            set idColumn "timetable_id"
            set extraSql "DELETE FROM timetable_slots WHERE timetable_id = $id"
        }
        "Breaktimes" {
            set table "breaktimes"
            set idColumn "break_id"
        }
        default {
            tk_messageBox -title "Delete" -message "This report type cannot be deleted here." -icon info
            return
        }
    }

    if {[tk_messageBox -type yesno -icon question -title "Confirm Delete" -message "Delete selected $reportType row ID $id?"] ne "yes"} {
        return
    }

    if {[catch {
        if {$extraSql ne ""} {
            db eval $extraSql
        }
        db eval "DELETE FROM $table WHERE $idColumn = $id"
    } err]} {
        tk_messageBox -title "Delete Error" -message "Could not delete selected report row:\n$err" -icon error
        return
    }

    tk_messageBox -title "Deleted" -message "Selected report row deleted." -icon info
    viewReport
}

proc exportReport {} {
    if {![winfo exists .reports.content.tree]} {
        return
    }
    set columns [.reports.content.tree cget -columns]
    if {[llength $columns] == 0 || [llength [.reports.content.tree children {}]] == 0} {
        tk_messageBox -title "Export" -message "Nothing to export. Run View first." -icon info
        return
    }

    set lines {}
    lappend lines [join $columns "\t"]
    foreach item [.reports.content.tree children {}] {
        lappend lines [join [.reports.content.tree item $item -values] "\t"]
    }

    set file [tk_getSaveFile -defaultextension .txt -filetypes {{{Text Files} {.txt}} {{All Files} {*}}}]
    if {$file eq ""} { return }
    if {[catch {
        set fh [open $file w]
        puts $fh [join $lines "\n"]
        close $fh
    } err]} {
        tk_messageBox -title "Export Error" -message "Failed to write file:\n$err" -icon error
    } else {
        tk_messageBox -title "Export" -message "Exported to $file" -icon info
    }
}

proc ensureReportTables {} {
    global db
    db eval {
        CREATE TABLE IF NOT EXISTS timetables (
            timetable_id INTEGER PRIMARY KEY AUTOINCREMENT,
            semester INTEGER,
            year TEXT,
            department TEXT,
            section TEXT,
            notes TEXT,
            generated_at TEXT
        )
    }

    set hasDepartment 0
    set hasSection 0
    db eval {PRAGMA table_info(timetables)} row {
        if {$row(name) eq "department"} {
            set hasDepartment 1
        }
        if {$row(name) eq "section"} {
            set hasSection 1
        }
    }
    if {!$hasDepartment} {
        db eval {ALTER TABLE timetables ADD COLUMN department TEXT}
    }
    if {!$hasSection} {
        db eval {ALTER TABLE timetables ADD COLUMN section TEXT}
    }

    db eval {
        CREATE TABLE IF NOT EXISTS timetable_slots (
            slot_id INTEGER PRIMARY KEY AUTOINCREMENT,
            timetable_id INTEGER,
            day_of_week TEXT,
            period_number INTEGER,
            slot_type TEXT,
            start_time TEXT,
            subject_name TEXT,
            staff_name TEXT,
            department TEXT,
            section TEXT,
            classroom TEXT,
            remarks TEXT
        )
    }

    set hasSlotSection 0
    db eval {PRAGMA table_info(timetable_slots)} row {
        if {$row(name) eq "section"} {
            set hasSlotSection 1
        }
    }
    if {!$hasSlotSection} {
        db eval {ALTER TABLE timetable_slots ADD COLUMN section TEXT}
    }
}
