proc openTimetableGenerator {} {
    ensureTimetableTables
    if {[winfo exists .timetable]} {
        raise .timetable
        return
    }
    toplevel .timetable
    wm title .timetable "Timetable Generator"
    wm geometry .timetable "900x560"
    .timetable configure -bg white

    label .timetable.title -text "GENERATE TIMETABLE" -font {Arial 16 bold} -bg "#1565C0" -fg white
    pack .timetable.title -fill x -pady 10

    frame .timetable.form -bg white
    pack .timetable.form -pady 12

    label .timetable.form.l1 -text "Semester :" -bg white
    grid .timetable.form.l1 -row 0 -column 0 -padx 8 -pady 6 -sticky e
    entry .timetable.form.e1 -width 8
    grid .timetable.form.e1 -row 0 -column 1 -padx 8 -sticky w

    label .timetable.form.lY -text "Year :" -bg white
    grid .timetable.form.lY -row 1 -column 0 -padx 8 -pady 6 -sticky e
    ttk::combobox .timetable.form.year -values {"1st Year" "2nd Year" "3rd Year" "4th Year"} -width 12
    .timetable.form.year set "1st Year"
    grid .timetable.form.year -row 1 -column 1 -padx 8 -sticky w

    label .timetable.form.lD -text "Department :" -bg white
    grid .timetable.form.lD -row 2 -column 0 -padx 8 -pady 6 -sticky e
    ttk::combobox .timetable.form.dept -values [loadTimetableDepartments] -width 28
    grid .timetable.form.dept -row 2 -column 1 -padx 8 -sticky w

    label .timetable.form.lS -text "Section :" -bg white
    grid .timetable.form.lS -row 3 -column 0 -padx 8 -pady 6 -sticky e
    ttk::combobox .timetable.form.section -values {"A" "B" "C" "D"} -width 8
    .timetable.form.section set "A"
    grid .timetable.form.section -row 3 -column 1 -padx 8 -sticky w

    label .timetable.form.l2 -text "Notes (optional) :" -bg white
    grid .timetable.form.l2 -row 4 -column 0 -padx 8 -pady 6 -sticky e
    entry .timetable.form.e2 -width 40
    grid .timetable.form.e2 -row 4 -column 1 -padx 8 -sticky w

    frame .timetable.actions -bg white
    pack .timetable.actions -pady 12

    button .timetable.generate -text "Generate" -width 14 -command {generateTimetable}
    pack .timetable.generate -in .timetable.actions -side left -padx 8
    button .timetable.close -text "Close" -command {destroy .timetable}
    pack .timetable.close -in .timetable.actions -side left -padx 8

    frame .timetable.result -bg white
    pack .timetable.result -fill both -expand 1 -padx 10 -pady 8

    text .timetable.result.txt -width 110 -height 16 -wrap none
    scrollbar .timetable.result.ys -orient vertical -command ".timetable.result.txt yview"
    scrollbar .timetable.result.xs -orient horizontal -command ".timetable.result.txt xview"
    .timetable.result.txt configure -yscrollcommand ".timetable.result.ys set" -xscrollcommand ".timetable.result.xs set"

    grid .timetable.result.txt -row 0 -column 0 -sticky nsew
    grid .timetable.result.ys -row 0 -column 1 -sticky ns
    grid .timetable.result.xs -row 1 -column 0 -sticky ew
    grid rowconfigure .timetable.result 0 -weight 1
    grid columnconfigure .timetable.result 0 -weight 1

    applyThemeToWindow .timetable
}

proc generateTimetable {} {
    global db
    ensureTimetableTables

    set sem [.timetable.form.e1 get]
    set year [.timetable.form.year get]
    set dept [.timetable.form.dept get]
    set section [.timetable.form.section get]
    set notes [.timetable.form.e2 get]

    if {$sem eq ""} {
        tk_messageBox -title "Validation" -message "Enter semester." -icon warning
        return
    }
    if {$year eq ""} {
        tk_messageBox -title "Validation" -message "Select year." -icon warning
        return
    }
    if {$dept eq ""} {
        tk_messageBox -title "Validation" -message "Select department." -icon warning
        return
    }
    if {$section eq ""} {
        set section "General"
    }

    if {![string is integer -strict $sem]} {
        tk_messageBox -title "Validation" -message "Semester must be a number." -icon warning
        return
    }

    set subjects [loadTimetableSubjects $sem $dept]
    if {[llength $subjects] == 0} {
        tk_messageBox -title "Missing Data" -message "No subjects found for $dept semester $sem. Add subjects with this department before generating timetable." -icon warning
        return
    }

    set classrooms [loadTimetableClassrooms $dept]
    if {[llength $classrooms] == 0} {
        tk_messageBox -title "Missing Data" -message "No classrooms found for $dept. Add a classroom with this department, or leave classroom department blank for shared rooms." -icon warning
        return
    }

    set timetableId [createTimetableRecord $sem $year $dept $section $notes]
    if {$timetableId eq ""} {
        return
    }

    if {[catch {db eval "DELETE FROM timetable_slots WHERE timetable_id = $timetableId"} err]} {
        tk_messageBox -title "DB Error" -message "Could not clear old timetable slots:\n$err" -icon error
        return
    }

    set days {"Monday" "Tuesday" "Wednesday" "Thursday" "Friday"}
    set periods [loadTimetablePeriods $year]
    if {[llength $periods] == 0} {
        tk_messageBox -title "Missing Data" -message "No period timings found for $year. Open Settings and add periods." -icon warning
        return
    }

    set theoryTodo {}
    set labTodo {}
    foreach subject $subjects {
        lassign $subject subjectName subjectCode department credits facultyName subjectType labPeriods
        if {$credits eq "" || ![string is integer -strict $credits] || $credits < 1} {
            set credits 3
        }
        if {[string equal -nocase $subjectType "Lab"]} {
            if {$labPeriods eq "" || ![string is integer -strict $labPeriods] || $labPeriods < 1} {
                set labPeriods 3
            }
            lappend labTodo [list $subjectName $subjectCode $department $credits $facultyName "Lab" $labPeriods]
        } else {
            for {set i 0} {$i < $credits} {incr i} {
                lappend theoryTodo [list $subjectName $subjectCode $department $credits $facultyName "Theory" 1]
            }
        }
    }

    set classroomIndex 0
    set slotIndex 0
    set inserted 0
    set skippedLabs 0
    set requiredSlots [llength $theoryTodo]
    set totalSlots [expr {[llength $days] * [llength $periods]}]

    foreach item $labTodo {
        lassign $item subjectName subjectCode department credits facultyName subjectType labPeriods
        incr requiredSlots $labPeriods
        set placed [placeLabBlock $timetableId $days $periods $slotIndex $labPeriods $subjectName $subjectCode $facultyName $department $section [lindex $classrooms [expr {$classroomIndex % [llength $classrooms]}]]]
        if {$placed < 0} {
            incr skippedLabs
            continue
        }
        set slotIndex $placed
        incr classroomIndex
        incr inserted $labPeriods
    }

    foreach item $theoryTodo {
        if {$slotIndex >= $totalSlots} {
            break
        }

        set day [lindex $days [expr {$slotIndex / [llength $periods]}]]
        set periodData [lindex $periods [expr {$slotIndex % [llength $periods]}]]
        lassign $periodData periodNumber startTime endTime

        set room [lindex $classrooms [expr {$classroomIndex % [llength $classrooms]}]]
        lassign $item subjectName subjectCode department credits facultyName
        set remarks ""
        if {$subjectCode ne ""} {
            set remarks "Code: $subjectCode"
        }
        if {$endTime ne ""} {
            append remarks " | Ends: $endTime"
        }

        insertTimetableSlot $timetableId $day $periodNumber "Class" $startTime $subjectName $facultyName $department $section $room $remarks
        incr classroomIndex
        incr slotIndex
        incr inserted
    }

    insertBreakSlots $timetableId $year $days
    showGeneratedTimetable $timetableId

    set message "Generated $inserted class slots for $dept section $section, semester $sem, $year."
    if {$requiredSlots > $totalSlots} {
        append message "\nSome subject periods did not fit because only $totalSlots weekly slots are available."
    }
    if {$skippedLabs > 0} {
        append message "\n$skippedLabs lab subject(s) could not fit into continuous lab periods."
    }
    tk_messageBox -title "Success" -message $message -icon info
}

proc ensureTimetableTables {} {
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

proc sqlQuote {value} {
    return "'[string map {"'" "''"} $value]'"
}

proc loadTimetableDepartments {} {
    global db
    set departments {}
    db eval {SELECT department_name FROM departments ORDER BY department_name} row {
        lappend departments $row(department_name)
    }
    db eval {SELECT DISTINCT department FROM subjects WHERE department IS NOT NULL AND trim(department) <> '' ORDER BY department} row {
        if {[lsearch -exact $departments $row(department)] < 0} {
            lappend departments $row(department)
        }
    }
    db eval {SELECT DISTINCT department FROM classrooms WHERE department IS NOT NULL AND trim(department) <> '' ORDER BY department} row {
        if {[lsearch -exact $departments $row(department)] < 0} {
            lappend departments $row(department)
        }
    }
    db eval {SELECT DISTINCT department FROM faculty WHERE department IS NOT NULL AND trim(department) <> '' ORDER BY department} row {
        if {[lsearch -exact $departments $row(department)] < 0} {
            lappend departments $row(department)
        }
    }
    return $departments
}

proc loadTimetableSubjects {sem dept} {
    global db
    set subjects {}
    set sql "SELECT s.subject_name, s.subject_code, s.department, s.credits, COALESCE(f.faculty_name, 'Not Assigned') AS faculty_name, COALESCE(s.subject_type, 'Theory') AS subject_type, COALESCE(s.lab_hours, 3) AS lab_hours FROM subjects s LEFT JOIN faculty f ON s.faculty_id = f.faculty_id WHERE s.semester = $sem AND s.department = [sqlQuote $dept] ORDER BY CASE COALESCE(s.subject_type, 'Theory') WHEN 'Lab' THEN 0 ELSE 1 END, s.subject_name"
    db eval $sql row {
        lappend subjects [list $row(subject_name) $row(subject_code) $row(department) $row(credits) $row(faculty_name) $row(subject_type) $row(lab_hours)]
    }
    return $subjects
}

proc placeLabBlock {timetableId days periods startSlot labPeriods subjectName subjectCode facultyName department section room} {
    set periodsPerDay [llength $periods]
    set totalSlots [expr {[llength $days] * $periodsPerDay}]
    set slot $startSlot

    while {$slot < $totalSlots} {
        set dayIndex [expr {$slot / $periodsPerDay}]
        set periodIndex [expr {$slot % $periodsPerDay}]

        if {[expr {$periodIndex + $labPeriods}] <= $periodsPerDay} {
            set day [lindex $days $dayIndex]
            set canPlace 1
            set block {}
            for {set i 0} {$i < $labPeriods} {incr i} {
                set periodData [lindex $periods [expr {$periodIndex + $i}]]
                lappend block $periodData
            }

            if {$canPlace} {
                foreach periodData $block {
                    lassign $periodData periodNumber startTime endTime
                    set remarks "Lab block: $labPeriods periods"
                    if {$subjectCode ne ""} {
                        append remarks " | Code: $subjectCode"
                    }
                    if {$endTime ne ""} {
                        append remarks " | Ends: $endTime"
                    }
                    insertTimetableSlot $timetableId $day $periodNumber "Lab" $startTime $subjectName $facultyName $department $section $room $remarks
                }
                return [expr {$slot + $labPeriods}]
            }
        }

        set slot [expr {($dayIndex + 1) * $periodsPerDay}]
    }

    return -1
}

proc loadTimetableClassrooms {dept} {
    global db
    set classrooms {}
    set sql "SELECT room_number, name FROM classrooms WHERE department = [sqlQuote $dept] OR department IS NULL OR trim(department) = '' ORDER BY room_number"
    db eval $sql row {
        if {$row(name) eq ""} {
            lappend classrooms $row(room_number)
        } else {
            lappend classrooms "$row(room_number) - $row(name)"
        }
    }
    return $classrooms
}

proc loadTimetablePeriods {year} {
    global db
    set periods {}
    set escYear [string map {"'" "''"} $year]
    db eval "SELECT period_number, start_time, end_time FROM periods WHERE year = '$escYear' ORDER BY period_number" row {
        lappend periods [list $row(period_number) $row(start_time) $row(end_time)]
    }

    if {[llength $periods] == 0} {
        db eval {SELECT period_number, start_time, end_time FROM periods WHERE year = 'All Years' ORDER BY period_number} row {
            lappend periods [list $row(period_number) $row(start_time) $row(end_time)]
        }
    }

    set breaks [loadBreakRangesForYear $year]
    set teachingPeriods {}
    foreach period $periods {
        lassign $period periodNumber startTime endTime
        if {![periodOverlapsBreak $startTime $endTime $breaks]} {
            lappend teachingPeriods $period
        }
    }

    return $teachingPeriods
}

proc loadBreakRangesForYear {year} {
    global db
    set breaks {}
    set escYear [string map {"'" "''"} $year]
    db eval "SELECT start_time, end_time FROM breaktimes WHERE year = '$escYear' AND start_time IS NOT NULL AND end_time IS NOT NULL" row {
        lappend breaks [list $row(start_time) $row(end_time)]
    }
    return $breaks
}

proc periodOverlapsBreak {periodStart periodEnd breaks} {
    set ps [timeToMinutes $periodStart]
    set pe [timeToMinutes $periodEnd]
    if {$ps < 0 || $pe < 0} {
        return 0
    }

    foreach breakRange $breaks {
        lassign $breakRange breakStart breakEnd
        set bs [timeToMinutes $breakStart]
        set be [timeToMinutes $breakEnd]
        if {$bs < 0 || $be < 0} {
            continue
        }
        if {$ps < $be && $pe > $bs} {
            return 1
        }
    }

    return 0
}

proc timeToMinutes {timeValue} {
    if {![regexp {^([0-9][0-9]?):([0-9][0-9])$} $timeValue -> hour minute]} {
        return -1
    }
    return [expr {$hour * 60 + $minute}]
}

proc createTimetableRecord {sem year dept section notes} {
    global db
    set sql "INSERT INTO timetables (semester, year, department, section, notes, generated_at) VALUES ($sem, [sqlQuote $year], [sqlQuote $dept], [sqlQuote $section], [sqlQuote $notes], datetime('now'))"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "DB Error" -message "Failed to create timetable:\n$err" -icon error
        return ""
    }
    set timetableId ""
    db eval {SELECT last_insert_rowid() AS id} row {
        set timetableId $row(id)
    }
    return $timetableId
}

proc insertTimetableSlot {timetableId day periodNumber slotType startTime subjectName staffName department section classroom remarks} {
    global db
    set sql "INSERT INTO timetable_slots (timetable_id, day_of_week, period_number, slot_type, start_time, subject_name, staff_name, department, section, classroom, remarks) VALUES ($timetableId, [sqlQuote $day], $periodNumber, [sqlQuote $slotType], [sqlQuote $startTime], [sqlQuote $subjectName], [sqlQuote $staffName], [sqlQuote $department], [sqlQuote $section], [sqlQuote $classroom], [sqlQuote $remarks])"
    db eval $sql
}

proc insertBreakSlots {timetableId year days} {
    global db
    set section ""
    db eval "SELECT section FROM timetables WHERE timetable_id = $timetableId" row {
        set section $row(section)
    }
    set breaks {}
    set sql "SELECT break_name, start_time, end_time FROM breaktimes WHERE year = [sqlQuote $year] ORDER BY start_time"
    db eval $sql row {
        lappend breaks [list $row(break_name) $row(start_time) $row(end_time)]
    }
    foreach breakItem $breaks {
        lassign $breakItem breakName startTime endTime
        foreach day $days {
            set remarks "$startTime - $endTime"
            insertTimetableSlot $timetableId $day 0 "Break" $startTime $breakName "" "" $section "" $remarks
        }
    }
}

proc showGeneratedTimetable {timetableId} {
    global db
    if {![winfo exists .timetable.result.txt]} {
        return
    }

    .timetable.result.txt delete 1.0 end
    .timetable.result.txt insert end "Day        Period  Time   Type   Subject / Break                 Faculty            Department       Section  Classroom        Remarks\n"
    .timetable.result.txt insert end "---------------------------------------------------------------------------------------------------------------------------------\n"

    set sql "SELECT day_of_week, period_number, start_time, slot_type, subject_name, staff_name, department, section, classroom, remarks FROM timetable_slots WHERE timetable_id = $timetableId ORDER BY CASE day_of_week WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 ELSE 6 END, period_number, start_time"
    db eval $sql row {
        .timetable.result.txt insert end "[format {%-10s %-7s %-6s %-6s %-31s %-18s %-16s %-8s %-16s %s} $row(day_of_week) $row(period_number) $row(start_time) $row(slot_type) $row(subject_name) $row(staff_name) $row(department) $row(section) $row(classroom) $row(remarks)]\n"
    }
}
