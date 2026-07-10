proc openTimetableGenerator {} {
    global currentTimetableId
    set currentTimetableId ""
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
    ttk::combobox .timetable.form.e1 \
        -values {1 2 3 4 5 6 7 8} -width 8 -state readonly
    .timetable.form.e1 set "1"
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
    bind .timetable.form.dept <<ComboboxSelected>> {refreshTimetableSections}
    bind .timetable.form.year <<ComboboxSelected>> {refreshTimetableSections}

    label .timetable.form.l2 -text "Notes (optional) :" -bg white
    grid .timetable.form.l2 -row 4 -column 0 -padx 8 -pady 6 -sticky e
    entry .timetable.form.e2 -width 40
    grid .timetable.form.e2 -row 4 -column 1 -padx 8 -sticky w

    frame .timetable.actions -bg white
    pack .timetable.actions -pady 12

    button .timetable.generate -text "Generate" -width 14 -command {generateTimetable}
    pack .timetable.generate -in .timetable.actions -side left -padx 8
    button .timetable.delete -text "Delete Timetable" -width 16 -command {deleteCurrentTimetable}
    pack .timetable.delete -in .timetable.actions -side left -padx 8
    button .timetable.close -text "Close" -command {destroy .timetable}
    pack .timetable.close -in .timetable.actions -side left -padx 8

    frame .timetable.result -bg white
    pack .timetable.result -fill both -expand 1 -padx 10 -pady 8

    canvas .timetable.result.canvas -bg white -highlightthickness 0
    frame .timetable.result.table -bg white
    scrollbar .timetable.result.ys -orient vertical -command ".timetable.result.canvas yview"
    scrollbar .timetable.result.xs -orient horizontal -command ".timetable.result.canvas xview"
    .timetable.result.canvas configure -yscrollcommand ".timetable.result.ys set" -xscrollcommand ".timetable.result.xs set"
    .timetable.result.canvas create window 0 0 -anchor nw -window .timetable.result.table -tags table
    bind .timetable.result.table <Configure> {
        .timetable.result.canvas configure -scrollregion [.timetable.result.canvas bbox all]
    }

    grid .timetable.result.canvas -row 0 -column 0 -sticky nsew
    grid .timetable.result.ys -row 0 -column 1 -sticky ns
    grid .timetable.result.xs -row 1 -column 0 -sticky ew
    grid rowconfigure .timetable.result 0 -weight 1
    grid columnconfigure .timetable.result 0 -weight 1

    applyThemeToWindow .timetable
}

proc generateTimetable {} {
    global db currentTimetableId
    ensureTimetableTables

    if {![requireEditTimetablePermission]} { return }

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
    set totalSlots [expr {[llength $days] * [llength $periods]}]

    set theoryTodo {}
    set labTodo {}
    set baseLabSlots 0
    array unset facultyBaseCount
    array unset facultyLimit
    array unset facultyExtraSources
    foreach subject $subjects {
        lassign $subject subjectName subjectCode department credits facultyName subjectType labPeriods facultyId facultyHours
        if {$credits eq "" || ![string is integer -strict $credits] || $credits < 1} {
            set credits 3
        }
        if {$labPeriods eq "" || ![string is integer -strict $labPeriods] || $labPeriods < 1} {
            set labPeriods 3
        }

        set facultyKey $facultyId
        if {$facultyKey eq ""} {
            set facultyKey $facultyName
        }
        if {![info exists facultyBaseCount($facultyKey)]} {
            set facultyBaseCount($facultyKey) 0
        }
        if {$facultyHours ne "" && [string is integer -strict $facultyHours] && $facultyHours > 0} {
            set facultyLimit($facultyKey) $facultyHours
        }

        if {[string equal -nocase $subjectType "Lab"]} {
            lappend labTodo [list $subjectName $subjectCode $department $credits $facultyName "Lab" $labPeriods $facultyKey]
            incr baseLabSlots $labPeriods
            incr facultyBaseCount($facultyKey) $labPeriods
        } elseif {[string equal -nocase $subjectType "Blended"]} {
            set theoryItem [list $subjectName $subjectCode $department $credits $facultyName "Theory" 1 $facultyKey]
            lappend facultyExtraSources($facultyKey) $theoryItem
            for {set i 0} {$i < $credits} {incr i} {
                lappend theoryTodo $theoryItem
                incr facultyBaseCount($facultyKey)
            }
            lappend labTodo [list "$subjectName Lab" $subjectCode $department $credits $facultyName "Lab" $labPeriods $facultyKey]
            incr baseLabSlots $labPeriods
            incr facultyBaseCount($facultyKey) $labPeriods
        } else {
            set theoryItem [list $subjectName $subjectCode $department $credits $facultyName "Theory" 1 $facultyKey]
            lappend facultyExtraSources($facultyKey) $theoryItem
            for {set i 0} {$i < $credits} {incr i} {
                lappend theoryTodo $theoryItem
                incr facultyBaseCount($facultyKey)
            }
        }
    }

    set maxTheorySlots [expr {$totalSlots - $baseLabSlots}]
    array unset facultySourceIndex
    foreach facultyKey [array names facultyLimit] {
        set facultySourceIndex($facultyKey) 0
    }
    set addedAllotted 1
    while {$addedAllotted && [llength $theoryTodo] < $maxTheorySlots} {
        set addedAllotted 0
        foreach facultyKey [lsort -dictionary [array names facultyLimit]] {
            if {[llength $theoryTodo] >= $maxTheorySlots} {
                break
            }
            if {![info exists facultyExtraSources($facultyKey)] || $facultyBaseCount($facultyKey) >= $facultyLimit($facultyKey)} {
                continue
            }
            set sources $facultyExtraSources($facultyKey)
            lappend theoryTodo [lindex $sources [expr {$facultySourceIndex($facultyKey) % [llength $sources]}]]
            incr facultyBaseCount($facultyKey)
            incr facultySourceIndex($facultyKey)
            set addedAllotted 1
        }
    }

    set allottedShortfall 0
    foreach facultyKey [array names facultyLimit] {
        if {$facultyBaseCount($facultyKey) < $facultyLimit($facultyKey)} {
            incr allottedShortfall [expr {$facultyLimit($facultyKey) - $facultyBaseCount($facultyKey)}]
        }
    }
    set theoryTodo [spreadTheorySubjects $theoryTodo]

    set classroomIndex 0
    set inserted 0
    set skippedLabs 0
    set requiredSlots [llength $theoryTodo]
    array set occupied {}
    set preferredLabDay 0

    foreach item $labTodo {
        lassign $item subjectName subjectCode department credits facultyName subjectType labPeriods
        incr requiredSlots $labPeriods
        set placed [placeLabBlock $timetableId $days $periods $preferredLabDay $labPeriods $subjectName $subjectCode $facultyName $department $section $classrooms occupied]
        if {$placed < 0} {
            incr skippedLabs
            continue
        }
        set preferredLabDay [expr {($placed + 1) % [llength $days]}]
        incr classroomIndex
        incr inserted $labPeriods
    }

    set slotOrder [balancedTimetableSlotOrder $days $periods]
    set slotOrderIndex 0
    foreach item $theoryTodo {
        set nextSlot [nextCompatibleTimetableSlot $slotOrder slotOrderIndex occupied $days $periods $facultyName $classrooms]
        if {[llength $nextSlot] == 0} {
            break
        }

        lassign $nextSlot dayIndex periodIndex room
        set day [lindex $days $dayIndex]
        set periodData [lindex $periods $periodIndex]
        lassign $periodData periodNumber startTime endTime

        lassign $item subjectName subjectCode department credits facultyName
        set remarks ""
        if {$subjectCode ne ""} {
            set remarks "Code: $subjectCode"
        }
        if {$endTime ne ""} {
            append remarks " | Ends: $endTime"
        }

        insertTimetableSlot $timetableId $day $periodNumber "Class" $startTime $subjectName $facultyName $department $section $room $remarks
        set occupied($dayIndex,$periodIndex) 1
        incr classroomIndex
        incr inserted
    }

    insertBreakSlots $timetableId $year $days
    set currentTimetableId $timetableId
    showGeneratedTimetable $timetableId

    set message "Generated $inserted of $requiredSlots required class/lab slots for $dept section $section, semester $sem, $year."
    if {$requiredSlots > $totalSlots} {
        append message "\nSome subject periods did not fit because only $totalSlots weekly slots are available."
    }
    if {$skippedLabs > 0} {
        append message "\n$skippedLabs lab subject(s) could not fit into continuous lab periods."
    }
    if {$allottedShortfall > 0} {
        append message "\n$allottedShortfall allotted faculty hour(s) could not fit into the available timetable slots."
    }
    tk_messageBox -title "Success" -message $message -icon info
}

proc spreadTheorySubjects {theoryItems} {
    array unset grouped
    set order {}
    foreach item $theoryItems {
        set subjectName [lindex $item 0]
        set subjectCode [lindex $item 1]
        set key "$subjectName|$subjectCode"
        if {![info exists grouped($key)]} {
            lappend order $key
            set grouped($key) {}
        }
        lappend grouped($key) $item
    }

    set result {}
    set added 1
    while {$added} {
        set added 0
        foreach key $order {
            if {[llength $grouped($key)] > 0} {
                lappend result [lindex $grouped($key) 0]
                set grouped($key) [lrange $grouped($key) 1 end]
                set added 1
            }
        }
    }

    return $result
}

proc findTimetableToDelete {} {
    global db currentTimetableId
    if {[info exists currentTimetableId] && $currentTimetableId ne ""} {
        return $currentTimetableId
    }

    set sem [string trim [.timetable.form.e1 get]]
    set year [string trim [.timetable.form.year get]]
    set dept [string trim [.timetable.form.dept get]]
    set section [string trim [.timetable.form.section get]]
    if {$section eq ""} {
        set section "General"
    }

    if {$sem eq "" || $year eq "" || $dept eq "" || ![string is integer -strict $sem]} {
        return ""
    }

    set timetableId ""
    set sql "SELECT timetable_id FROM timetables WHERE semester = $sem AND year = [sqlQuote $year] AND department = [sqlQuote $dept] AND section = [sqlQuote $section] ORDER BY timetable_id DESC LIMIT 1"
    db eval $sql result {
        set timetableId $result(timetable_id)
    }
    return $timetableId
}

proc deleteCurrentTimetable {} {
    global db currentTimetableId
    if {![requireEditTimetablePermission]} { return }
    set timetableId [findTimetableToDelete]
    if {$timetableId eq ""} {
        tk_messageBox -title "Delete" -message "Generate a timetable first, or select the same semester, year, department, and section to delete." -icon info
        return
    }

    if {[tk_messageBox -type yesno -icon question -title "Confirm Delete" -message "Delete timetable ID $timetableId and all its slots?"] ne "yes"} {
        return
    }

    if {[catch {
        db eval "DELETE FROM timetable_slots WHERE timetable_id = $timetableId"
        db eval "DELETE FROM timetables WHERE timetable_id = $timetableId"
    } err]} {
        tk_messageBox -title "Database Error" -message "Could not delete timetable:\n$err" -icon error
        return
    }

    set currentTimetableId ""
    clearTimetableResult
    tk_messageBox -title "Deleted" -message "Timetable deleted successfully." -icon info
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

# Refresh the Section dropdown when Department or Year changes
proc refreshTimetableSections {} {
    global db
    if {![winfo exists .timetable.form.section]} { return }
    set dept [string trim [.timetable.form.dept get]]
    set year [string trim [.timetable.form.year get]]

    set sections {}
    if {$dept ne "" && $year ne ""} {
        set escDept [string map {"'" "''"} $dept]
        set escYear [string map {"'" "''"} $year]
        db eval "SELECT DISTINCT section_name FROM sections
                 WHERE (department = '$escDept'
                    OR department IN (SELECT department_name FROM departments WHERE short_name = '$escDept')
                    OR department IN (SELECT short_name FROM departments WHERE department_name = '$escDept'))
                   AND year = '$escYear'
                 ORDER BY section_name" row {
            lappend sections $row(section_name)
        }
    }
    # Always keep A B C D as fallback options
    foreach s {A B C D} {
        if {[lsearch -exact $sections $s] < 0} { lappend sections $s }
    }
    .timetable.form.section configure -values $sections
    if {[.timetable.form.section get] eq "" || \
        [lsearch -exact $sections [.timetable.form.section get]] < 0} {
        .timetable.form.section set [lindex $sections 0]
    }
}

proc loadTimetableDepartments {} {
    global db
    set departments {}
    db eval {SELECT department_name, short_name FROM departments ORDER BY department_name} row {
        set dept $row(department_name)
        if {$row(short_name) ne ""} {
            set dept $row(short_name)
        }
        if {[lsearch -exact $departments $dept] < 0} {
            lappend departments $dept
        }
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

proc departmentMatchSql {column dept} {
    set quoted [sqlQuote $dept]
    return "($column = $quoted OR $column IN (SELECT department_name FROM departments WHERE short_name = $quoted) OR $column IN (SELECT short_name FROM departments WHERE department_name = $quoted))"
}

proc loadTimetableSubjects {sem dept} {
    global db
    set subjects {}
    set sql "SELECT s.subject_name, s.subject_code, s.department, s.credits, s.faculty_id, COALESCE(f.faculty_name, 'Not Assigned') AS faculty_name, COALESCE(f.hours_allotted, '') AS hours_allotted, COALESCE(s.subject_type, 'Theory') AS subject_type, COALESCE(s.lab_hours, 3) AS lab_hours FROM subjects s LEFT JOIN faculty f ON s.faculty_id = f.faculty_id WHERE s.semester = $sem AND [departmentMatchSql s.department $dept] ORDER BY CASE COALESCE(s.subject_type, 'Theory') WHEN 'Lab' THEN 0 ELSE 1 END, s.subject_name"
    db eval $sql row {
        lappend subjects [list $row(subject_name) $row(subject_code) $row(department) $row(credits) $row(faculty_name) $row(subject_type) $row(lab_hours) $row(faculty_id) $row(hours_allotted)]
    }
    return $subjects
}

proc balancedTimetableSlotOrder {days periods} {
    set order {}
    for {set dayIndex 0} {$dayIndex < [llength $days]} {incr dayIndex} {
        for {set periodIndex 0} {$periodIndex < [llength $periods]} {incr periodIndex} {
            lappend order [list $dayIndex $periodIndex]
        }
    }
    return $order
}

proc nextFreeTimetableSlot {slotOrder slotOrderIndexVar occupiedVar} {
    upvar $slotOrderIndexVar slotOrderIndex
    upvar $occupiedVar occupied

    while {$slotOrderIndex < [llength $slotOrder]} {
        set slot [lindex $slotOrder $slotOrderIndex]
        incr slotOrderIndex
        lassign $slot dayIndex periodIndex
        if {![info exists occupied($dayIndex,$periodIndex)]} {
            return $slot
        }
    }

    return {}
}

# Find the next free slot AND assign a classroom from the pool (round-robin)
# Returns: {dayIndex periodIndex roomName}  or {} when no slot is available
proc nextCompatibleTimetableSlot {slotOrder slotOrderIndexVar occupiedVar days periods facultyName classrooms} {
    upvar $slotOrderIndexVar slotOrderIndex
    upvar $occupiedVar occupied

    while {$slotOrderIndex < [llength $slotOrder]} {
        set slot [lindex $slotOrder $slotOrderIndex]
        incr slotOrderIndex
        lassign $slot dayIndex periodIndex

        if {[info exists occupied($dayIndex,$periodIndex)]} {
            continue
        }

        # Pick a classroom (round-robin based on how many slots are filled)
        set filledCount 0
        foreach key [array names occupied] { incr filledCount }
        set roomCount [llength $classrooms]
        if {$roomCount > 0} {
            set room [lindex $classrooms [expr {$filledCount % $roomCount}]]
        } else {
            set room ""
        }

        return [list $dayIndex $periodIndex $room]
    }

    return {}
}

proc placeLabBlock {timetableId days periods preferredDay labPeriods subjectName subjectCode facultyName department section room occupiedVar} {
    upvar $occupiedVar occupied
    set periodsPerDay [llength $periods]
    set dayCount [llength $days]

    for {set dayOffset 0} {$dayOffset < $dayCount} {incr dayOffset} {
        set dayIndex [expr {($preferredDay + $dayOffset) % $dayCount}]
        set day [lindex $days $dayIndex]
        for {set periodIndex 0} {[expr {$periodIndex + $labPeriods}] <= $periodsPerDay} {incr periodIndex} {
            set canPlace 1
            for {set i 0} {$i < $labPeriods} {incr i} {
                if {[info exists occupied($dayIndex,[expr {$periodIndex + $i}])]} {
                    set canPlace 0
                    break
                }
            }

            if {$canPlace} {
                for {set i 0} {$i < $labPeriods} {incr i} {
                    set periodData [lindex $periods [expr {$periodIndex + $i}]]
                    lassign $periodData periodNumber startTime endTime
                    set remarks "Lab block: $labPeriods periods"
                    if {$subjectCode ne ""} {
                        append remarks " | Code: $subjectCode"
                    }
                    if {$endTime ne ""} {
                        append remarks " | Ends: $endTime"
                    }
                    insertTimetableSlot $timetableId $day $periodNumber "Lab" $startTime $subjectName $facultyName $department $section $room $remarks
                    set occupied($dayIndex,[expr {$periodIndex + $i}]) 1
                }
                return $dayIndex
            }
        }
    }

    return -1
}

proc loadTimetableClassrooms {dept} {
    global db
    set classrooms {}
    set sql "SELECT room_number, name FROM classrooms WHERE [departmentMatchSql department $dept] OR department IS NULL OR trim(department) = '' ORDER BY room_number"
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

proc timetableDisplayTime {timeValue} {
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

proc timetableDaySortValue {day} {
    switch -- $day {
        Monday { return 1 }
        Tuesday { return 2 }
        Wednesday { return 3 }
        Thursday { return 4 }
        Friday { return 5 }
        default { return 6 }
    }
}

proc compareTimetableDays {left right} {
    return [expr {[timetableDaySortValue $left] - [timetableDaySortValue $right]}]
}

proc compareTimetableRows {left right} {
    set leftDay [timetableDaySortValue [lindex $left 0]]
    set rightDay [timetableDaySortValue [lindex $right 0]]
    if {$leftDay != $rightDay} {
        return [expr {$leftDay - $rightDay}]
    }

    set leftTime [timeToMinutes [lindex $left 2]]
    set rightTime [timeToMinutes [lindex $right 2]]
    if {$leftTime < 0} { set leftTime 99999 }
    if {$rightTime < 0} { set rightTime 99999 }
    if {$leftTime != $rightTime} {
        return [expr {$leftTime - $rightTime}]
    }

    return [expr {[lindex $left 1] - [lindex $right 1]}]
}

proc timetableRepeat {text count} {
    set result ""
    for {set i 0} {$i < $count} {incr i} {
        append result $text
    }
    return $result
}

proc timetablePad {text width} {
    set text [string range $text 0 [expr {$width - 1}]]
    set padding [expr {$width - [string length $text]}]
    return "$text[timetableRepeat " " $padding]"
}

proc timetableBorder {leftWidth colWidth colCount} {
    set line "+"
    append line [timetableRepeat "-" [expr {$leftWidth + 2}]] "+"
    for {set i 0} {$i < $colCount} {incr i} {
        append line [timetableRepeat "-" [expr {$colWidth + 2}]] "+"
    }
    return "$line\n"
}

proc timetableWrapText {text width} {
    set text [string trim [string map [list "\r" " " "\n" " "] $text]]
    if {$text eq ""} {
        return [list ""]
    }

    set lines {}
    set current ""
    foreach word [split $text " "] {
        if {$word eq ""} {
            continue
        }
        while {[string length $word] > $width} {
            if {$current ne ""} {
                lappend lines $current
                set current ""
            }
            lappend lines [string range $word 0 [expr {$width - 1}]]
            set word [string range $word $width end]
        }
        if {$word eq ""} {
            continue
        }
        if {$current eq ""} {
            set current $word
        } elseif {[string length "$current $word"] <= $width} {
            append current " $word"
        } else {
            lappend lines $current
            set current $word
        }
    }
    if {$current ne ""} {
        lappend lines $current
    }
    if {[llength $lines] == 0} {
        return [list ""]
    }
    return $lines
}

proc clearTimetableResult {} {
    if {![winfo exists .timetable.result.table]} {
        return
    }
    foreach child [winfo children .timetable.result.table] {
        destroy $child
    }
    if {[winfo exists .timetable.result.canvas]} {
        .timetable.result.canvas configure -scrollregion [.timetable.result.canvas bbox all]
    }
}

proc addTimetableLabel {row column text args} {
    set widget ".timetable.result.table.r${row}c${column}"
    if {[winfo exists $widget]} {
        destroy $widget
    }

    set options [list -text $text -bg white -fg "#222222" -font {Arial 10} -justify center -anchor center -wraplength 130 -padx 6 -pady 6 -relief solid -bd 1]
    foreach {key value} $args {
        lappend options $key $value
    }
    label $widget {*}$options
    grid $widget -row $row -column $column -sticky nsew
    grid columnconfigure .timetable.result.table $column -minsize 145
}

proc addTimetableMessage {message} {
    clearTimetableResult
    addTimetableLabel 0 0 $message -font {Arial 11} -relief flat -wraplength 600 -anchor w -justify left
}

proc timetableSlotEndTime {startTime slotType remarks} {
    if {[string equal -nocase $slotType "Break"] && [regexp {^[0-9][0-9]?:[0-9][0-9][[:space:]]*-[[:space:]]*([0-9][0-9]?:[0-9][0-9])} $remarks -> endTime]} {
        return $endTime
    }
    if {[regexp {Ends:[[:space:]]*([0-9][0-9]?:[0-9][0-9])} $remarks -> endTime]} {
        return $endTime
    }
    return ""
}

proc timetableColumnLabel {startTime endTime} {
    if {$endTime eq ""} {
        return [timetableDisplayTime $startTime]
    }
    return "[timetableDisplayTime $startTime]-[timetableDisplayTime $endTime]"
}

proc timetableCellText {slotType subject staff classroom remarks} {
    if {[string equal -nocase $slotType "Break"]} {
        return [string toupper $subject]
    }

    set text $subject
    if {[string equal -nocase $slotType "Lab"] && $classroom ne ""} {
        append text " ($classroom)"
    }
    return $text
}

proc loadTimetableDisplayBreaks {year} {
    global db
    set breaks {}
    set escYear [string map {"'" "''"} $year]
    set sql "SELECT break_name, start_time, end_time FROM breaktimes WHERE year = '$escYear' AND start_time IS NOT NULL AND end_time IS NOT NULL ORDER BY start_time"
    db eval $sql row {
        set startMinutes [timeToMinutes $row(start_time)]
        set endMinutes [timeToMinutes $row(end_time)]
        if {$startMinutes >= 0 && $endMinutes >= 0} {
            lappend breaks [list $row(break_name) $row(start_time) $row(end_time)]
        }
    }
    return $breaks
}

proc showGeneratedTimetable {timetableId} {
    global db
    if {![winfo exists .timetable.result.table]} {
        return
    }

    clearTimetableResult

    set semester ""
    set year ""
    set department ""
    set section ""
    db eval "SELECT semester, year, department, section FROM timetables WHERE timetable_id = $timetableId" info {
        set semester $info(semester)
        set year $info(year)
        set department $info(department)
        set section $info(section)
    }

    set rows {}
    set sql "SELECT day_of_week, period_number, start_time, slot_type, subject_name, staff_name, department, section, classroom, remarks FROM timetable_slots WHERE timetable_id = $timetableId ORDER BY CASE day_of_week WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 ELSE 6 END, period_number, start_time"
    db eval $sql row {
        lappend rows [list $row(day_of_week) $row(period_number) $row(start_time) $row(slot_type) $row(subject_name) $row(staff_name) $row(department) $row(section) $row(classroom) $row(remarks)]
    }

    if {[llength $rows] == 0} {
        addTimetableMessage "No timetable slots found."
        return
    }

    set columns {}
    set days {}
    array unset cells

    foreach periodData [loadTimetablePeriods $year] {
        lassign $periodData periodNumber start end
        set startMinutes [timeToMinutes $start]
        set endMinutes [timeToMinutes $end]
        if {$startMinutes < 0} {
            continue
        }
        if {$endMinutes < 0} {
            set endMinutes $startMinutes
        }
        set label [timetableColumnLabel $start $end]
        set key "$startMinutes|$endMinutes|$label"
        lappend columns [list $startMinutes $endMinutes $key $label "Period" ""]
    }

    foreach breakData [loadTimetableDisplayBreaks $year] {
        lassign $breakData breakName start end
        set startMinutes [timeToMinutes $start]
        set endMinutes [timeToMinutes $end]
        if {$startMinutes < 0} {
            continue
        }
        if {$endMinutes < 0} {
            set endMinutes $startMinutes
        }
        set label [timetableColumnLabel $start $end]
        set key "$startMinutes|$endMinutes|$label"
        lappend columns [list $startMinutes $endMinutes $key $label "Break" $breakName]
    }

    foreach slotRow $rows {
        lassign $slotRow day period start type subject staff rowDept rowSection classroom remarks
        if {[lsearch -exact $days $day] < 0} {
            lappend days $day
        }
        if {[string equal -nocase $type "Break"]} {
            continue
        }

        set end [timetableSlotEndTime $start $type $remarks]
        set startMinutes [timeToMinutes $start]
        set endMinutes [timeToMinutes $end]
        if {$startMinutes < 0} {
            set startMinutes 99999
        }
        if {$endMinutes < 0} {
            set endMinutes $startMinutes
        }

        set label [timetableColumnLabel $start $end]
        set key "$startMinutes|$endMinutes|$label"
        set cellText [timetableCellText $type $subject $staff $classroom $remarks]
        if {[info exists cells($day,$key)] && $cells($day,$key) ne ""} {
            append cells($day,$key) " / $cellText"
        } else {
            set cells($day,$key) $cellText
        }
    }

    set columns [lsort -integer -index 0 $columns]
    set days [lsort -command compareTimetableDays $days]

    set firstRoom ""
    foreach slotRow $rows {
        if {[lindex $slotRow 8] ne ""} {
            set firstRoom [lindex $slotRow 8]
            break
        }
    }

    set heading "Year: $year | Semester: $semester | Department: $department | Section: $section"
    if {$firstRoom ne ""} {
        append heading " | Class Room: $firstRoom"
    }
    addTimetableLabel 0 0 $heading -font {Arial 11 bold} -relief flat -anchor w -justify left -wraplength 900
    grid .timetable.result.table.r0c0 -columnspan [expr {[llength $columns] + 1}] -sticky ew
    grid columnconfigure .timetable.result.table 0 -minsize 120

    set colIndex 1
    foreach column $columns {
        addTimetableLabel 1 $colIndex [lindex $column 3] -bg "#1565C0" -fg white -font {Arial 10 bold}
        incr colIndex
    }
    addTimetableLabel 1 0 "Day/Time" -bg "#1565C0" -fg white -font {Arial 10 bold}

    set rowIndex 2
    foreach day $days {
        addTimetableLabel $rowIndex 0 $day -bg "#E3F2FD" -font {Arial 10 bold}
        set colIndex 1
        foreach column $columns {
            set key [lindex $column 2]
            set columnType [lindex $column 4]
            set breakName [lindex $column 5]
            if {[string equal -nocase $columnType "Break"]} {
                addTimetableLabel $rowIndex $colIndex [string toupper $breakName] -bg "#FFF3E0" -font {Arial 10 bold}
            } elseif {[info exists cells($day,$key)]} {
                addTimetableLabel $rowIndex $colIndex $cells($day,$key)
            } else {
                addTimetableLabel $rowIndex $colIndex ""
            }
            incr colIndex
        }
        incr rowIndex
    }

    if {[winfo exists .timetable.result.canvas]} {
        update idletasks
        .timetable.result.canvas configure -scrollregion [.timetable.result.canvas bbox all]
    }
}
