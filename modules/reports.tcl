package require Ttk

proc openReports {} {
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

    ttk::combobox .reports.controls.cb -values {"Faculty List" "Subjects" "Classrooms" "Timetables" "Breaktimes"} -width 35
    grid .reports.controls.cb -row 0 -column 1 -padx 8 -pady 6 -sticky w

    button .reports.controls.view -text "View" -width 12 -command {viewReport}
    grid .reports.controls.view -row 0 -column 2 -padx 8 -pady 6

    button .reports.controls.export -text "Export" -width 12 -command {exportReport}
    grid .reports.controls.export -row 0 -column 3 -padx 8 -pady 6

    frame .reports.content -bg white
    pack .reports.content -fill both -expand 1 -padx 8 -pady 8

    text .reports.content.txt -width 100 -height 24
    pack .reports.content.txt -in .reports.content -fill both -expand 1

    frame .reports.actions -bg white
    pack .reports.actions -pady 8
    button .reports.close -text "Close" -command {destroy .reports}
    pack .reports.close -in .reports.actions -side left -padx 6

    applyThemeToWindow .reports
}

proc viewReport {} {
    global db
    ensureReportTables
    set sel [.reports.controls.cb get]
    .reports.content.txt delete 1.0 end
    if {$sel eq ""} {
        tk_messageBox -title "Validation" -message "Select a report type." -icon warning
        return
    }

    if {$sel eq "Faculty List"} {
        db eval {SELECT faculty_id, faculty_name, department, designation, email, phone FROM faculty} {
            .reports.content.txt insert end "[format "%d | %s | %s | %s | %s | %s\n" $row(faculty_id) $row(faculty_name) $row(department) $row(designation) $row(email) $row(phone)]"
        }
    } elseif {$sel eq "Subjects"} {
        db eval {SELECT subject_id, subject_name, subject_code, department, credits, semester, faculty_id, COALESCE(subject_type, 'Theory') AS subject_type, COALESCE(lab_hours, 3) AS lab_hours FROM subjects} {
            .reports.content.txt insert end "[format "%d | %s | %s | %s | Credits:%s | Sem:%s | Faculty:%s | %s | Lab Periods:%s\n" $row(subject_id) $row(subject_name) $row(subject_code) $row(department) $row(credits) $row(semester) $row(faculty_id) $row(subject_type) $row(lab_hours)]"
        }
    } elseif {$sel eq "Classrooms"} {
        db eval {SELECT classroom_id, room_number, name, building, capacity, department FROM classrooms} {
            .reports.content.txt insert end "[format "%d | %s | %s | %s | %s | %s\n" $row(classroom_id) $row(room_number) $row(name) $row(building) $row(capacity) $row(department)]"
        }
    } elseif {$sel eq "Timetables"} {
        set timetableRows {}
        db eval {SELECT timetable_id, semester, year, department, section, notes, generated_at FROM timetables ORDER BY timetable_id DESC} {
            lappend timetableRows [list $row(timetable_id) $row(semester) $row(year) $row(department) $row(section) $row(notes) $row(generated_at)]
        }

        foreach timetable $timetableRows {
            lassign $timetable tid semester year department section notes generatedAt
            .reports.content.txt insert end "[format "Timetable %d | %s Section %s | Semester %s | %s | %s | %s\n" $tid $department $section $semester $year $generatedAt $notes]"
            db eval "SELECT day_of_week, period_number, start_time, slot_type, subject_name, staff_name, department, section, classroom FROM timetable_slots WHERE timetable_id = $tid ORDER BY CASE day_of_week WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 ELSE 6 END, period_number, start_time" slot {
                .reports.content.txt insert end "[format "  %-10s P%-2s %-6s %-6s %-25s %-18s %-12s %-4s %s\n" $slot(day_of_week) $slot(period_number) $slot(start_time) $slot(slot_type) $slot(subject_name) $slot(staff_name) $slot(department) $slot(section) $slot(classroom)]"
            }
            .reports.content.txt insert end "\n"
        }
    } elseif {$sel eq "Breaktimes"} {
        db eval {SELECT break_id, year, break_name, start_time, end_time FROM breaktimes} {
            .reports.content.txt insert end "[format "%d | %s | %s | %s - %s\n" $row(break_id) $row(year) $row(break_name) $row(start_time) $row(end_time)]"
        }
    } else {
        .reports.content.txt insert end "No handler for $sel\n"
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

proc exportReport {} {
    set content [.reports.content.txt get 1.0 end]
    if {[string trim $content] eq ""} {
        tk_messageBox -title "Export" -message "Nothing to export. Run View first." -icon info
        return
    }
    set file [tk_getSaveFile -defaultextension .txt -filetypes {{Text Files} {.txt} {All Files} *}]
    if {$file eq ""} { return }
    if {[catch {set fh [open $file w]; puts $fh $content; close $fh} err]} {
        tk_messageBox -title "Export Error" -message "Failed to write file:\n$err" -icon error
    } else {
        tk_messageBox -title "Export" -message "Exported to $file" -icon info
    }
}
