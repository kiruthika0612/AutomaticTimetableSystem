# =============================================================================
#  Timetable Editor  —  Visual Grid Edition
#  Staff click any cell in the Day × Period grid to edit it directly.
#  No slot IDs, no hidden dialogs — just click and change.
# =============================================================================

# ── Permission helpers ────────────────────────────────────────────────────────
proc currentUserCanEditTimetable {} {
    global db currentUser
    if {![info exists currentUser] || $currentUser eq ""} { return 0 }
    set perm 0
    set escU [string map {"'" "''"} $currentUser]
    db eval "SELECT COALESCE(can_edit_timetable,0) AS p
             FROM users WHERE username = '$escU' LIMIT 1" row {
        set perm $row(p)
    }
    return $perm
}

proc requireEditTimetablePermission {} {
    if {[currentUserCanEditTimetable]} { return 1 }
    tk_messageBox -title "Permission Denied" \
        -message "Your account does not have the \"Edit Timetable\" permission.\n\nAsk an Admin to enable it in User Management." \
        -icon error
    return 0
}

# ── Conflict validator ────────────────────────────────────────────────────────
proc validateSlotConflicts {timetableId day periodNumber slotType
                             subjectName staffName department section
                             classroom excludeSlotId} {
    global db
    set msgs {}
    if {[string equal -nocase $slotType "Break"]} { return "" }
    set excl [expr {$excludeSlotId ne "" ? "AND slot_id <> $excludeSlotId" : ""}]
    set qDay  [sqlQuote $day]
    set qSect [sqlQuote $section]
    set qDept [sqlQuote $department]

    if {$section ne "" && $department ne ""} {
        db eval "SELECT COUNT(*) AS n FROM timetable_slots
                 WHERE day_of_week=$qDay AND period_number=$periodNumber
                   AND slot_type IN ('Class','Lab')
                   AND department=$qDept AND section=$qSect $excl" row {
            if {$row(n) > 0} {
                lappend msgs "Section $department-$section already has a class in period $periodNumber on $day."
            }
        }
    }
    if {$staffName ne "" && $staffName ni {"Not Assigned" "TBA"}} {
        set qStaff [sqlQuote $staffName]
        db eval "SELECT COUNT(*) AS n FROM timetable_slots
                 WHERE day_of_week=$qDay AND period_number=$periodNumber
                   AND slot_type IN ('Class','Lab')
                   AND staff_name=$qStaff $excl" row {
            if {$row(n) > 0} {
                lappend msgs "Faculty \"$staffName\" is already assigned to period $periodNumber on $day."
            }
        }
    }
    if {$classroom ne ""} {
        set qRoom [sqlQuote $classroom]
        db eval "SELECT COUNT(*) AS n FROM timetable_slots
                 WHERE day_of_week=$qDay AND period_number=$periodNumber
                   AND slot_type IN ('Class','Lab')
                   AND classroom=$qRoom $excl" row {
            if {$row(n) > 0} {
                lappend msgs "Classroom \"$classroom\" is already booked for period $periodNumber on $day."
            }
        }
    }
    return [join $msgs "\n"]
}

# ── Helper lists ──────────────────────────────────────────────────────────────
proc loadEditorFacultyList {} {
    global db
    set list {"TBA"}
    db eval {SELECT faculty_name FROM faculty ORDER BY faculty_name} row {
        lappend list $row(faculty_name)
    }
    return $list
}

proc loadEditorClassroomList {} {
    global db
    set list {""}
    db eval {SELECT room_number, name FROM classrooms ORDER BY room_number} row {
        if {$row(name) ne ""} {
            lappend list "$row(room_number) - $row(name)"
        } else {
            lappend list $row(room_number)
        }
    }
    return $list
}

proc loadEditorSubjectList {dept sem} {
    global db
    set list {}
    if {$dept eq "" || $sem eq ""} { return $list }
    set escD [string map {"'" "''"} $dept]
    db eval "SELECT subject_name FROM subjects
             WHERE semester=$sem
               AND ([departmentMatchSql department $dept])
             ORDER BY subject_name" row {
        lappend list $row(subject_name)
    }
    return $list
}

proc resolveEditorTimetableId {} {
    global db
    if {![winfo exists .tteditor.filter.dept]} { return "" }
    set dept    [string trim [.tteditor.filter.dept    get]]
    set year    [string trim [.tteditor.filter.year    get]]
    set sem     [string trim [.tteditor.filter.sem     get]]
    set section [string trim [.tteditor.filter.section get]]
    if {$dept eq "" || $sem eq ""} { return "" }
    set escDept [string map {"'" "''"} $dept]
    set escYear [string map {"'" "''"} $year]
    set escSect [string map {"'" "''"} $section]
    set tid ""
    db eval "SELECT timetable_id FROM timetables
             WHERE semester=$sem AND year='$escYear' AND section='$escSect'
               AND ([departmentMatchSql department $dept])
             ORDER BY timetable_id DESC LIMIT 1" row {
        set tid $row(timetable_id)
    }
    return $tid
}

proc editorGridStatus {msg} {
    if {[winfo exists .tteditor.statusbar.txt]} {
        .tteditor.statusbar.txt configure -text $msg
    }
}

# =============================================================================
#  MAIN EDITOR WINDOW  —  opens the visual grid editor
# =============================================================================
proc openTimetableEditor {} {
    if {![requireEditTimetablePermission]} { return }
    if {[winfo exists .tteditor]} { raise .tteditor ; return }

    toplevel .tteditor
    wm title .tteditor "Timetable Editor — Visual Grid"
    wm geometry .tteditor "1200x700"
    .tteditor configure -bg white

    # Header
    label .tteditor.hdr -text "TIMETABLE EDITOR" \
        -font {Arial 16 bold} -bg "#1565C0" -fg white -pady 8
    pack .tteditor.hdr -fill x

    # Info strip
    frame .tteditor.infobar -bg "#E3F2FD" -relief flat
    pack  .tteditor.infobar -fill x -padx 0
    label .tteditor.infobar.txt \
        -text "  Click any subject cell in the grid to edit it. Green = Theory  |  Teal = Lab  |  Orange = Break  |  Red = Locked" \
        -font {Arial 9} -bg "#E3F2FD" -fg "#0D47A1" -anchor w
    pack .tteditor.infobar.txt -pady 4 -anchor w

    # ── Filter bar ────────────────────────────────────────────────────────────
    frame .tteditor.filter -bg white -relief groove -bd 1
    pack  .tteditor.filter -fill x -padx 10 -pady 6

    label .tteditor.filter.ld -text "Dept :" -bg white -font {Arial 10 bold}
    pack  .tteditor.filter.ld -side left -padx {10 2}
    ttk::combobox .tteditor.filter.dept -values [loadTimetableDepartments] -width 20
    pack .tteditor.filter.dept -side left -padx 4

    label .tteditor.filter.ly -text "Year :" -bg white -font {Arial 10 bold}
    pack  .tteditor.filter.ly -side left -padx {10 2}
    ttk::combobox .tteditor.filter.year \
        -values {"1st Year" "2nd Year" "3rd Year" "4th Year"} -width 10
    .tteditor.filter.year set "1st Year"
    pack .tteditor.filter.year -side left -padx 4

    label .tteditor.filter.ls -text "Sem :" -bg white -font {Arial 10 bold}
    pack  .tteditor.filter.ls -side left -padx {10 2}
    ttk::combobox .tteditor.filter.sem \
        -values {1 2 3 4 5 6 7 8} -width 4 -state readonly
    .tteditor.filter.sem set "1"
    pack .tteditor.filter.sem -side left -padx 4

    label .tteditor.filter.lsc -text "Section :" -bg white -font {Arial 10 bold}
    pack  .tteditor.filter.lsc -side left -padx {10 2}
    ttk::combobox .tteditor.filter.section -values {A B C D} -width 5
    .tteditor.filter.section set "A"
    pack .tteditor.filter.section -side left -padx 4

    button .tteditor.filter.load -text "Load Timetable" -width 14 \
        -bg "#1565C0" -fg white -font {Arial 10 bold} \
        -command {buildEditorGrid}
    pack .tteditor.filter.load -side left -padx 14

    button .tteditor.filter.listview -text "Slot List (Advanced)" -width 18 \
        -command {openSlotListView}
    pack .tteditor.filter.listview -side left -padx 4

    button .tteditor.filter.close -text "Close" -width 8 \
        -command {destroy .tteditor}
    pack .tteditor.filter.close -side right -padx 10

    # Status bar
    frame .tteditor.statusbar -bg "#F1F5F9" -relief solid -bd 1
    pack  .tteditor.statusbar -fill x -padx 10 -side bottom -pady 4
    label .tteditor.statusbar.txt \
        -text "Select Department, Year, Semester, Section — then click Load Timetable." \
        -font {Arial 9} -bg "#F1F5F9" -fg "#475569" -anchor w
    pack .tteditor.statusbar.txt -padx 10 -pady 4 -anchor w

    # Scrollable grid area
    frame .tteditor.gridwrap -bg white
    pack  .tteditor.gridwrap -fill both -expand 1 -padx 10 -pady 4

    canvas .tteditor.gridwrap.canvas -bg white -highlightthickness 0 \
        -yscrollcommand {.tteditor.gridwrap.ys set} \
        -xscrollcommand {.tteditor.gridwrap.xs set}
    scrollbar .tteditor.gridwrap.ys -orient vertical   -command {.tteditor.gridwrap.canvas yview}
    scrollbar .tteditor.gridwrap.xs -orient horizontal -command {.tteditor.gridwrap.canvas xview}

    frame .tteditor.gridwrap.canvas.inner -bg white
    .tteditor.gridwrap.canvas create window 0 0 -anchor nw \
        -window .tteditor.gridwrap.canvas.inner -tags inner

    bind .tteditor.gridwrap.canvas.inner <Configure> {
        .tteditor.gridwrap.canvas configure \
            -scrollregion [.tteditor.gridwrap.canvas bbox all]
    }

    grid .tteditor.gridwrap.canvas -row 0 -column 0 -sticky nsew
    grid .tteditor.gridwrap.ys     -row 0 -column 1 -sticky ns
    grid .tteditor.gridwrap.xs     -row 1 -column 0 -sticky ew
    grid rowconfigure    .tteditor.gridwrap 0 -weight 1
    grid columnconfigure .tteditor.gridwrap 0 -weight 1

    applyThemeToWindow .tteditor
}

# Sort helper: compares "periodNum|startTime" keys by start time in minutes
proc mp_sortByTime {a b} {
    set ta [timeToMinutes [lindex [split $a "|"] 1]]
    set tb [timeToMinutes [lindex [split $b "|"] 1]]
    if {$ta < 0} { set ta 99999 }
    if {$tb < 0} { set tb 99999 }
    return [expr {$ta - $tb}]
}

# =============================================================================
#  BUILD THE VISUAL GRID
# =============================================================================
proc buildEditorGrid {} {
    global db tte_slotMap tte_days tte_periods tte_timetableId

    set dept    [string trim [.tteditor.filter.dept    get]]
    set year    [string trim [.tteditor.filter.year    get]]
    set sem     [string trim [.tteditor.filter.sem     get]]
    set section [string trim [.tteditor.filter.section get]]

    if {$dept eq "" || $sem eq ""} {
        editorGridStatus "Please select Department and Semester first."
        return
    }

    set tte_timetableId [resolveEditorTimetableId]
    if {$tte_timetableId eq ""} {
        editorGridStatus "No timetable found for $dept / $year / Sem $sem / Section $section.  Generate one first."
        return
    }

    # Clear existing grid
    set inner .tteditor.gridwrap.canvas.inner
    foreach w [winfo children $inner] { destroy $w }
    array unset tte_slotMap
    array unset tte_days
    array unset tte_periods

    # Load all slots for this timetable
    set slots {}
    db eval "SELECT slot_id, day_of_week, period_number, start_time,
                    slot_type, subject_name, staff_name, classroom,
                    section, department, COALESCE(locked,0) AS locked
             FROM timetable_slots
             WHERE timetable_id = $tte_timetableId
             ORDER BY period_number, start_time" row {
        lappend slots [list $row(slot_id) $row(day_of_week) $row(period_number) \
            $row(start_time) $row(slot_type) $row(subject_name) \
            $row(staff_name) $row(classroom) $row(section) \
            $row(department) $row(locked)]
    }

    if {[llength $slots] == 0} {
        editorGridStatus "Timetable $tte_timetableId is empty. Generate slots first."
        return
    }

    # Collect unique days and period/time columns
    # IMPORTANT: Break slots have period_number=0 — exclude them from the
    # period column set; they are drawn separately using the breaktimes table.
    set dayOrder {Monday Tuesday Wednesday Thursday Friday}
    set daySet {}
    set periodSet {}   ;# list of "periodNum|startTime" for Class/Lab only

    foreach slot $slots {
        lassign $slot slotId day period startTime stype subj staff room sect dept locked
        if {[lsearch -exact $daySet $day] < 0} { lappend daySet $day }

        # Skip break slots — they go into a separate display column
        if {[string equal -nocase $stype "Break"]} { continue }

        set pkey "$period|$startTime"
        set found 0
        foreach p $periodSet { if {$p eq $pkey} { set found 1 ; break } }
        if {!$found} { lappend periodSet $pkey }

        # Map day+period → slot data (only Class/Lab)
        set tte_slotMap($day,$period) [list $slotId $day $period $startTime \
            $stype $subj $staff $room $sect $dept $locked]
    }

    # Build break columns from the breaktimes table (same year as timetable)
    set ttYear ""
    db eval "SELECT year FROM timetables WHERE timetable_id = $tte_timetableId" ttRow {
        set ttYear $ttRow(year)
    }
    set breakCols {}
    if {$ttYear ne ""} {
        db eval "SELECT break_name, start_time, end_time
                 FROM breaktimes WHERE year = [sqlQuote $ttYear]
                 ORDER BY start_time" ttRow {
            set bs [timeToMinutes $ttRow(start_time)]
            set be [timeToMinutes $ttRow(end_time)]
            if {$bs >= 0} {
                set lbl "$ttRow(start_time)-$ttRow(end_time)"
                lappend breakCols [list $bs $be $lbl $ttRow(break_name)]
            }
        }
    }

    # Sort days by week order
    set sortedDays {}
    foreach d $dayOrder { if {[lsearch -exact $daySet $d] >= 0} { lappend sortedDays $d } }

    # Sort teaching periods by actual start time in minutes (not string sort)
    set sortedPeriods [lsort -command mp_sortByTime $periodSet]

    # Build a merged column list: teaching periods + break columns, sorted by start time
    set allCols {}
    foreach pkey $sortedPeriods {
        lassign [split $pkey "|"] pnum ptime
        set sm [timeToMinutes $ptime]
        if {$sm < 0} { set sm 99999 }
        lappend allCols [list $sm "Period $pnum\n$ptime" "period" $pnum]
    }
    foreach bc $breakCols {
        lassign $bc bs be lbl bname
        lappend allCols [list $bs $lbl "break" $bname]
    }
    set allCols [lsort -integer -index 0 $allCols]

    set tte_days    $sortedDays
    set tte_periods $sortedPeriods

    # ── Draw header row ───────────────────────────────────────────────────────
    set CW 160   ;# cell width
    set CH 70    ;# cell height

    # Top-left corner
    label $inner.corner -text "Day / Period" \
        -font {Arial 10 bold} -bg "#1565C0" -fg white \
        -width 12 -relief solid -bd 1 -pady 8
    grid $inner.corner -row 0 -column 0 -sticky nsew -ipady 4

    set col 1
    foreach colData $allCols {
        lassign $colData sm lbl ctype extra
        set hbg [expr {$ctype eq "break" ? "#F57F17" : "#1565C0"}]
        label $inner.ph_$col -text $lbl \
            -font {Arial 9 bold} -bg $hbg -fg white \
            -width 18 -relief solid -bd 1 -justify center -pady 6
        grid $inner.ph_$col -row 0 -column $col -sticky nsew
        incr col
    }

    # ── Draw day rows ─────────────────────────────────────────────────────────
    set gridRow 1
    foreach day $sortedDays {
        # Day label
        label $inner.day_$gridRow -text $day \
            -font {Arial 10 bold} -bg "#E3F2FD" -fg "#0D47A1" \
            -width 10 -relief solid -bd 1 -pady 20
        grid $inner.day_$gridRow -row $gridRow -column 0 -sticky nsew

        set col 1
        foreach colData $allCols {
            lassign $colData sm lbl ctype extra
            set cellName "$inner.cell_${gridRow}_${col}"

            if {$ctype eq "break"} {
                # Break column — fixed orange cell, not editable
                label $cellName -text [string toupper $extra] \
                    -font {Arial 9 bold} -bg "#FFF8E1" -fg "#E65100" \
                    -width 20 -wraplength 150 -justify center \
                    -relief solid -bd 1 -pady 8
            } else {
                # Teaching period column
                set pnum $extra
                if {[info exists tte_slotMap($day,$pnum)]} {
                    set sdata $tte_slotMap($day,$pnum)
                    lassign $sdata slotId _ _ _ stype subj staff room _ _ locked
                    set bg     [tte_cellColor $stype $locked]
                    set clabel [tte_cellLabel $stype $subj $staff]
                    set cursor [expr {$locked ? "arrow" : "hand2"}]
                    label $cellName -text $clabel \
                        -font {Arial 9} -bg $bg -fg "#111111" \
                        -width 20 -wraplength 150 -justify center \
                        -relief solid -bd 1 -pady 8 -cursor $cursor
                    if {!$locked} {
                        bind $cellName <Button-1> [list openCellEditor $day $pnum]
                    }
                } else {
                    label $cellName -text "" \
                        -font {Arial 9} -bg "#F8F8F8" -fg "#999999" \
                        -width 20 -relief solid -bd 1 -pady 8
                }
            }
            grid $cellName -row $gridRow -column $col -sticky nsew -padx 1 -pady 1
            incr col
        }
        incr gridRow
    }

    # Make columns stretch evenly
    set totalCols [expr {[llength $sortedPeriods] + 1}]
    for {set c 0} {$c < $totalCols} {incr c} {
        grid columnconfigure $inner $c -minsize $CW -weight 1
    }
    for {set gridR 0} {$gridR < $gridRow} {incr gridR} {
        grid rowconfigure $inner $gridR -minsize $CH
    }

    update idletasks
    .tteditor.gridwrap.canvas configure \
        -scrollregion [.tteditor.gridwrap.canvas bbox all]

    editorGridStatus "Timetable loaded: $dept / $year / Sem $sem / Sec $section  —  Click any cell to edit it."
}

proc tte_cellColor {stype locked} {
    if {$locked} { return "#FFCDD2" }
    switch -nocase $stype {
        "Lab"   { return "#E0F2F1" }
        "Break" { return "#FFF8E1" }
        default { return "#E8F5E9" }
    }
}

proc tte_cellLabel {stype subj staff} {
    if {[string equal -nocase $stype "Break"]} {
        return [string toupper $subj]
    }
    set lbl $subj
    if {$staff ne "" && $staff ne "TBA" && $staff ne "Not Assigned"} {
        append lbl "\n$staff"
    }
    return $lbl
}

# =============================================================================
#  CELL EDITOR  —  pops up when staff click a grid cell
# =============================================================================
proc openCellEditor {day periodNum} {
    global db tte_slotMap tte_timetableId

    if {![requireEditTimetablePermission]} { return }
    if {![info exists tte_slotMap($day,$periodNum)]} { return }

    set sdata $tte_slotMap($day,$periodNum)
    lassign $sdata slotId _ _ startTime stype subj staff room sect dept locked

    if {$locked} {
        tk_messageBox -title "Locked" \
            -message "This slot is locked.\nUnlock it from the Slot List view first." \
            -icon warning
        return
    }

    set w .cellEditor
    if {[winfo exists $w]} { destroy $w }
    toplevel $w
    wm title $w "Edit  —  $day  Period $periodNum"
    wm geometry $w "480x380"
    wm resizable $w 0 0
    $w configure -bg white
    wm transient $w .tteditor

    # Header
    label $w.hdr -text "EDIT SLOT  —  $day  |  Period $periodNum  ($startTime)" \
        -font {Arial 12 bold} -bg "#1565C0" -fg white -pady 8
    pack $w.hdr -fill x

    frame $w.form -bg white
    pack  $w.form -fill x -padx 24 -pady 12

    # Subject dropdown (populated from subjects table)
    set dept2  [string trim [.tteditor.filter.dept get]]
    set sem2   [string trim [.tteditor.filter.sem  get]]
    set subjList [loadEditorSubjectList $dept2 $sem2]
    if {[lsearch -exact $subjList $subj] < 0} { lappend subjList $subj }

    label $w.form.ls -text "Subject :" -bg white -font {Arial 10 bold} -anchor e -width 12
    grid  $w.form.ls -row 0 -column 0 -padx 8 -pady 8 -sticky e
    ttk::combobox $w.form.subject -values $subjList -width 34
    $w.form.subject set $subj
    grid $w.form.subject -row 0 -column 1 -padx 8 -pady 8 -sticky w

    # Faculty dropdown
    label $w.form.lf -text "Faculty :" -bg white -font {Arial 10 bold} -anchor e -width 12
    grid  $w.form.lf -row 1 -column 0 -padx 8 -pady 8 -sticky e
    ttk::combobox $w.form.faculty -values [loadEditorFacultyList] -width 34
    $w.form.faculty set $staff
    grid $w.form.faculty -row 1 -column 1 -padx 8 -pady 8 -sticky w

    # Classroom dropdown
    label $w.form.lr -text "Classroom :" -bg white -font {Arial 10 bold} -anchor e -width 12
    grid  $w.form.lr -row 2 -column 0 -padx 8 -pady 8 -sticky e
    ttk::combobox $w.form.classroom -values [loadEditorClassroomList] -width 34
    $w.form.classroom set $room
    grid $w.form.classroom -row 2 -column 1 -padx 8 -pady 8 -sticky w

    # Slot type
    label $w.form.lt -text "Slot Type :" -bg white -font {Arial 10 bold} -anchor e -width 12
    grid  $w.form.lt -row 3 -column 0 -padx 8 -pady 8 -sticky e
    ttk::combobox $w.form.stype \
        -values {"Class" "Lab"} -width 34 -state readonly
    $w.form.stype set $stype
    grid $w.form.stype -row 3 -column 1 -padx 8 -pady 8 -sticky w

    # Status
    label $w.status -text "" -fg "#DC2626" -bg white \
        -wraplength 420 -justify left -font {Arial 9}
    pack $w.status -padx 24 -anchor w

    # Buttons
    frame $w.btns -bg white
    pack  $w.btns -pady 12

    button $w.btns.save -text "Save" -width 12 \
        -bg "#1565C0" -fg white -font {Arial 10 bold} \
        -command [list saveCellEdit $w $slotId $day $periodNum $sect $dept]
    button $w.btns.swap -text "Swap with..." -width 14 \
        -command [list openSwapFromCell $w $slotId $day $periodNum $subj $staff]
    button $w.btns.lock -text "Lock Slot" -width 12 \
        -command [list lockSlotFromCell $slotId $w]
    button $w.btns.cancel -text "Cancel" -width 10 \
        -command [list destroy $w]

    pack $w.btns.save   -side left -padx 6
    pack $w.btns.swap   -side left -padx 6
    pack $w.btns.lock   -side left -padx 6
    pack $w.btns.cancel -side left -padx 6

    applyThemeToWindow $w
    focus $w.form.faculty
}

# ── Save cell edit back to DB and refresh grid cell ───────────────────────────
proc saveCellEdit {w slotId day periodNum sect dept} {
    global db currentUser tte_slotMap

    set newSubj  [string trim [$w.form.subject   get]]
    set newStaff [string trim [$w.form.faculty   get]]
    set newRoom  [string trim [$w.form.classroom get]]
    set newType  [string trim [$w.form.stype     get]]

    if {$newSubj eq ""} {
        $w.status configure -text "Subject cannot be empty."
        return
    }

    set conflict [validateSlotConflicts "" $day $periodNum $newType \
        $newSubj $newStaff $dept $sect $newRoom $slotId]
    if {$conflict ne ""} {
        $w.status configure -text "Conflict: $conflict"
        return
    }

    set escSubj  [string map {"'" "''"} $newSubj]
    set escStaff [string map {"'" "''"} $newStaff]
    set escRoom  [string map {"'" "''"} $newRoom]
    set escType  [string map {"'" "''"} $newType]
    set escUser  [string map {"'" "''"} $currentUser]

    if {[catch {
        db eval "UPDATE timetable_slots
                 SET subject_name='$escSubj', staff_name='$escStaff',
                     classroom='$escRoom', slot_type='$escType',
                     modified_by='$escUser'
                 WHERE slot_id=$slotId"
    } err]} {
        $w.status configure -text "DB Error: $err"
        return
    }

    # Update the in-memory map
    set old $tte_slotMap($day,$periodNum)
    lset old 5 $newSubj
    lset old 6 $newStaff
    lset old 7 $newRoom
    lset old 4 $newType
    set tte_slotMap($day,$periodNum) $old

    # Refresh just this cell label
    refreshGridCell $day $periodNum

    destroy $w
    editorGridStatus "Saved: $day  Period $periodNum  ->  $newSubj  ($newStaff)"
}

# ── Refresh a single grid cell without rebuilding the whole grid ──────────────
proc refreshGridCell {day periodNum} {
    global tte_slotMap tte_days tte_periods tte_timetableId

    set inner .tteditor.gridwrap.canvas.inner

    # Find gridRow for this day
    set gridRow 1
    foreach d $tte_days {
        if {$d eq $day} { break }
        incr gridRow
    }

    # Rebuild allCols the same way buildEditorGrid does, to find the right col index
    # We only need the column index of teaching periods (breaks are fixed cols)
    set ttYear ""
    global db
    db eval "SELECT year FROM timetables WHERE timetable_id = $tte_timetableId" ttRow {
        set ttYear $ttRow(year)
    }

    set breakCols {}
    if {$ttYear ne ""} {
        db eval "SELECT break_name, start_time, end_time
                 FROM breaktimes WHERE year = [sqlQuote $ttYear]
                 ORDER BY start_time" ttRow {
            set bs [timeToMinutes $ttRow(start_time)]
            if {$bs >= 0} {
                lappend breakCols [list $bs "" "break" $ttRow(break_name)]
            }
        }
    }

    set allCols {}
    foreach pkey $tte_periods {
        lassign [split $pkey "|"] pnum ptime
        set sm [timeToMinutes $ptime]
        if {$sm < 0} { set sm 99999 }
        lappend allCols [list $sm "" "period" $pnum]
    }
    foreach bc $breakCols { lappend allCols $bc }
    set allCols [lsort -integer -index 0 $allCols]

    # Find gridCol for this periodNum in allCols
    set gridCol 1
    foreach colData $allCols {
        lassign $colData sm lbl ctype extra
        if {$ctype eq "period" && $extra == $periodNum} { break }
        incr gridCol
    }

    set cellName "$inner.cell_${gridRow}_${gridCol}"
    if {![winfo exists $cellName]} { return }

    if {[info exists tte_slotMap($day,$periodNum)]} {
        set sdata $tte_slotMap($day,$periodNum)
        lassign $sdata _ _ _ _ stype subj staff _ _ _ locked
        set bg     [tte_cellColor $stype $locked]
        set clabel [tte_cellLabel $stype $subj $staff]
        $cellName configure -text $clabel -bg $bg
    }
}

# =============================================================================
#  SWAP  —  select another cell to swap with, using a visual picker
# =============================================================================
proc openSwapFromCell {parentW slotId1 day1 pnum1 subj1 staff1} {
    set w .swapPicker
    if {[winfo exists $w]} { destroy $w }
    toplevel $w
    wm title $w "Swap  —  Select the other slot"
    wm geometry $w "640x480"
    $w configure -bg white
    wm transient $w .tteditor

    label $w.hdr -text "SWAP SLOTS  —  Select the slot to swap with" \
        -font {Arial 12 bold} -bg "#1565C0" -fg white -pady 8
    pack $w.hdr -fill x

    label $w.info \
        -text "Slot A:  $day1  Period $pnum1  —  $subj1  ($staff1)" \
        -font {Arial 10} -bg "#E3F2FD" -fg "#0D47A1" -anchor w -pady 6
    pack $w.info -fill x -padx 14

    label $w.hint \
        -text "Click a row below to select Slot B, then click Swap." \
        -font {Arial 9} -bg white -fg "#666" -anchor w
    pack $w.hint -fill x -padx 14 -pady 4

    # Treeview of all non-break, non-locked slots
    frame $w.tbl -bg white
    pack  $w.tbl -fill both -expand 1 -padx 14 -pady 6

    set cols {SlotID Day Period Time Subject Faculty}
    ttk::treeview $w.tbl.tree -columns $cols -show headings \
        -selectmode browse \
        -yscrollcommand {$w.tbl.ys set}
    scrollbar $w.tbl.ys -orient vertical -command [list $w.tbl.tree yview]

    foreach {col txt cw} {
        SlotID "ID" 45  Day "Day" 90  Period "Period" 55
        Time "Time" 75  Subject "Subject" 200  Faculty "Faculty" 160
    } {
        $w.tbl.tree heading $col -text $txt
        $w.tbl.tree column  $col -width $cw -anchor w
    }
    grid $w.tbl.tree -row 0 -column 0 -sticky nsew
    grid $w.tbl.ys   -row 0 -column 1 -sticky ns
    grid rowconfigure    $w.tbl 0 -weight 1
    grid columnconfigure $w.tbl 0 -weight 1

    # Populate from tte_slotMap
    global tte_slotMap tte_days tte_periods
    foreach day $tte_days {
        foreach pkey $tte_periods {
            lassign [split $pkey "|"] pnum ptime
            if {![info exists tte_slotMap($day,$pnum)]} { continue }
            set sdata $tte_slotMap($day,$pnum)
            lassign $sdata sid _ _ stime stype subj staff _ _ _ locked
            if {$locked || [string equal -nocase $stype "Break"]} { continue }
            if {$sid == $slotId1} { continue }
            $w.tbl.tree insert {} end -values [list $sid $day $pnum $stime $subj $staff]
        }
    }

    label $w.status -text "" -fg "#DC2626" -bg white -anchor w
    pack $w.status -fill x -padx 14 -pady 2

    frame $w.btns -bg white
    pack  $w.btns -pady 8

    button $w.btns.swap -text "Swap Selected" -width 16 \
        -bg "#1565C0" -fg white -font {Arial 10 bold} \
        -command [list executeGridSwap $w $slotId1 $day1 $pnum1]
    button $w.btns.cancel -text "Cancel" -width 10 \
        -command [list destroy $w]
    pack $w.btns.swap   -side left -padx 8
    pack $w.btns.cancel -side left -padx 8

    # Close cell editor too
    if {[winfo exists $parentW]} { destroy $parentW }
    applyThemeToWindow $w
}

proc executeGridSwap {w slotId1 day1 pnum1} {
    global db currentUser tte_slotMap

    if {![requireEditTimetablePermission]} { return }

    set sel [$w.tbl.tree selection]
    if {$sel eq ""} {
        $w.status configure -text "Click a row first to select Slot B."
        return
    }
    set vals [$w.tbl.tree item $sel -values]
    set slotId2 [lindex $vals 0]
    set day2    [lindex $vals 1]
    set pnum2   [lindex $vals 2]

    if {$slotId1 == $slotId2} {
        $w.status configure -text "Both slots are the same. Pick a different one."
        return
    }

    # Read current DB values for both
    set s1 [slotDbRow $slotId1]
    set s2 [slotDbRow $slotId2]
    if {[llength $s1] == 0} { $w.status configure -text "Slot A not found in DB." ; return }
    if {[llength $s2] == 0} { $w.status configure -text "Slot B not found in DB." ; return }

    lassign $s1 d1 p1 t1 locked1
    lassign $s2 d2 p2 t2 locked2
    if {$locked1} { $w.status configure -text "Slot A is locked." ; return }
    if {$locked2} { $w.status configure -text "Slot B is locked." ; return }

    set escUser [string map {"'" "''"} $currentUser]

    if {[catch {
        db eval "UPDATE timetable_slots
                 SET day_of_week=[sqlQuote $d2], period_number=$p2,
                     start_time=[sqlQuote $t2], modified_by='$escUser'
                 WHERE slot_id=$slotId1"
        db eval "UPDATE timetable_slots
                 SET day_of_week=[sqlQuote $d1], period_number=$p1,
                     start_time=[sqlQuote $t1], modified_by='$escUser'
                 WHERE slot_id=$slotId2"
    } err]} {
        $w.status configure -text "DB Error: $err"
        return
    }

    # Swap the in-memory map entries
    if {[info exists tte_slotMap($d1,$p1)] && [info exists tte_slotMap($d2,$p2)]} {
        set tmp $tte_slotMap($d1,$p1)
        set tte_slotMap($d1,$p1) $tte_slotMap($d2,$p2)
        set tte_slotMap($d2,$p2) $tmp
        lset tte_slotMap($d1,$p1) 1 $d1
        lset tte_slotMap($d1,$p1) 2 $p1
        lset tte_slotMap($d2,$p2) 1 $d2
        lset tte_slotMap($d2,$p2) 2 $p2
    }

    refreshGridCell $d1 $p1
    refreshGridCell $d2 $p2
    destroy $w
    editorGridStatus "Swapped: $d1 P$p1  <->  $d2 P$p2  successfully."
}

proc slotDbRow {slotId} {
    global db
    set result {}
    db eval "SELECT day_of_week, period_number, start_time, COALESCE(locked,0) AS locked
             FROM timetable_slots WHERE slot_id=$slotId" row {
        set result [list $row(day_of_week) $row(period_number) \
            $row(start_time) $row(locked)]
    }
    return $result
}

# =============================================================================
#  LOCK / UNLOCK from inside the cell editor
# =============================================================================
proc lockSlotFromCell {slotId w} {
    global db currentUser tte_slotMap

    if {![requireEditTimetablePermission]} { return }

    set locked 0
    db eval "SELECT COALESCE(locked,0) AS lk FROM timetable_slots WHERE slot_id=$slotId" r {
        set locked $r(lk)
    }
    set newLock [expr {$locked ? 0 : 1}]
    set action  [expr {$newLock ? "Lock" : "Unlock"}]

    set confirm [tk_messageBox -title "$action Slot" \
        -message "$action this slot so it cannot be accidentally changed?" \
        -type yesno -icon question]
    if {$confirm ne "yes"} { return }

    set escUser [string map {"'" "''"} $currentUser]
    if {[catch {
        db eval "UPDATE timetable_slots SET locked=$newLock, modified_by='$escUser'
                 WHERE slot_id=$slotId"
    } err]} {
        tk_messageBox -title "Error" -message $err -icon error
        return
    }

    # Update map
    foreach key [array names tte_slotMap] {
        set sdata $tte_slotMap($key)
        if {[lindex $sdata 0] == $slotId} {
            lset sdata 10 $newLock
            set tte_slotMap($key) $sdata
            lassign [split $key ","] d p
            refreshGridCell $d $p
            break
        }
    }

    destroy $w
    editorGridStatus "Slot $slotId [string tolower $action]ed."
}

# =============================================================================
#  SLOT LIST VIEW  — secondary view for power users who want the raw list
#  Accessible via a button from the grid (for admin-level operations)
# =============================================================================
proc openSlotListView {} {
    if {[winfo exists .slotlist]} { raise .slotlist ; return }

    toplevel .slotlist
    wm title .slotlist "Slot List — All Slots"
    wm geometry .slotlist "1100x580"
    .slotlist configure -bg white

    label .slotlist.hdr -text "SLOT LIST (Advanced View)" \
        -font {Arial 14 bold} -bg "#37474F" -fg white -pady 8
    pack .slotlist.hdr -fill x

    frame .slotlist.tblframe -bg white
    pack  .slotlist.tblframe -fill both -expand 1 -padx 10 -pady 8

    set cols {SlotID Day Period Time Type Subject Faculty Classroom Section Locked}
    ttk::treeview .slotlist.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -yscrollcommand {.slotlist.tblframe.ys set} \
        -xscrollcommand {.slotlist.tblframe.xs set}
    scrollbar .slotlist.tblframe.ys -orient vertical   -command {.slotlist.tblframe.tree yview}
    scrollbar .slotlist.tblframe.xs -orient horizontal -command {.slotlist.tblframe.tree xview}

    foreach {col txt w} {
        SlotID "ID" 45  Day "Day" 85  Period "Pd" 40  Time "Time" 70
        Type "Type" 60  Subject "Subject" 185  Faculty "Faculty" 160
        Classroom "Room" 85  Section "Sec" 55  Locked "Lock" 45
    } {
        .slotlist.tblframe.tree heading $col -text $txt
        .slotlist.tblframe.tree column  $col -width $w -anchor w
    }
    .slotlist.tblframe.tree column SlotID -anchor center
    .slotlist.tblframe.tree column Period -anchor center
    .slotlist.tblframe.tree column Locked -anchor center
    .slotlist.tblframe.tree column Type   -anchor center

    .slotlist.tblframe.tree tag configure class  -background "#F1F8E9"
    .slotlist.tblframe.tree tag configure lab    -background "#E0F2F1"
    .slotlist.tblframe.tree tag configure brk    -background "#FFF8E1"
    .slotlist.tblframe.tree tag configure locked -background "#FFCDD2"

    grid .slotlist.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .slotlist.tblframe.ys   -row 0 -column 1 -sticky ns
    grid .slotlist.tblframe.xs   -row 1 -column 0 -sticky ew
    grid rowconfigure    .slotlist.tblframe 0 -weight 1
    grid columnconfigure .slotlist.tblframe 0 -weight 1

    # Action buttons
    frame .slotlist.btns -bg white
    pack  .slotlist.btns -fill x -padx 10 -pady 4

    button .slotlist.btns.del -text "Delete Selected" -width 16 \
        -command {deleteSlotFromList}
    button .slotlist.btns.lock -text "Toggle Lock" -width 14 \
        -command {toggleLockFromList}
    button .slotlist.btns.close -text "Close" -width 10 \
        -command {destroy .slotlist}
    pack .slotlist.btns.del   -side left -padx 6
    pack .slotlist.btns.lock  -side left -padx 6
    pack .slotlist.btns.close -side right -padx 6

    # Status
    frame .slotlist.sb -bg "#F1F5F9" -relief solid -bd 1
    pack  .slotlist.sb -fill x -padx 10 -side bottom -pady 4
    label .slotlist.sb.txt -text "" -font {Arial 9} \
        -bg "#F1F5F9" -fg "#475569" -anchor w
    pack .slotlist.sb.txt -padx 10 -pady 4 -anchor w

    # Load data from current editor filter
    populateSlotList

    applyThemeToWindow .slotlist
}

proc populateSlotList {} {
    global db
    if {![winfo exists .slotlist.tblframe.tree]} { return }
    set tid [resolveEditorTimetableId]
    if {$tid eq ""} {
        .slotlist.sb.txt configure -text "Load a timetable in the editor first."
        return
    }
    .slotlist.tblframe.tree delete [.slotlist.tblframe.tree children {}]
    set count 0
    db eval "SELECT slot_id, day_of_week, period_number, start_time,
                    slot_type, subject_name, staff_name, classroom,
                    section, COALESCE(locked,0) AS locked
             FROM timetable_slots WHERE timetable_id=$tid
             ORDER BY CASE day_of_week
               WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2
               WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4
               WHEN 'Friday' THEN 5 ELSE 6 END, period_number" row {
        set lbl [expr {$row(locked) ? "Yes" : ""}]
        if {$row(locked)} { set tag locked
        } elseif {[string equal -nocase $row(slot_type) "Lab"]} { set tag lab
        } elseif {[string equal -nocase $row(slot_type) "Break"]} { set tag brk
        } else { set tag class }
        .slotlist.tblframe.tree insert {} end -values [list \
            $row(slot_id) $row(day_of_week) $row(period_number) \
            $row(start_time) $row(slot_type) $row(subject_name) \
            $row(staff_name) $row(classroom) $row(section) $lbl] -tags $tag
        incr count
    }
    .slotlist.sb.txt configure -text "Loaded $count slot(s)  |  Double-click a row to edit in grid."
}

proc deleteSlotFromList {} {
    if {![requireEditTimetablePermission]} { return }
    set sel [.slotlist.tblframe.tree selection]
    if {$sel eq ""} { tk_messageBox -title "Delete" -message "Select a row first." -icon info ; return }
    set vals [.slotlist.tblframe.tree item $sel -values]
    set slotId [lindex $vals 0]
    if {[lindex $vals 9] eq "Yes"} {
        tk_messageBox -title "Locked" -message "Unlock this slot first." -icon warning ; return
    }
    if {[tk_messageBox -type yesno -icon question -title "Confirm Delete" \
            -message "Delete slot ID $slotId?"] ne "yes"} { return }
    global db
    if {[catch {db eval "DELETE FROM timetable_slots WHERE slot_id=$slotId"} err]} {
        tk_messageBox -title "Error" -message $err -icon error ; return
    }
    populateSlotList
    buildEditorGrid
    .slotlist.sb.txt configure -text "Slot $slotId deleted."
}

proc toggleLockFromList {} {
    if {![requireEditTimetablePermission]} { return }
    set sel [.slotlist.tblframe.tree selection]
    if {$sel eq ""} { tk_messageBox -title "Lock" -message "Select a row first." -icon info ; return }
    set vals [.slotlist.tblframe.tree item $sel -values]
    set slotId  [lindex $vals 0]
    set locked  [expr {[lindex $vals 9] eq "Yes" ? 1 : 0}]
    set newLock [expr {$locked ? 0 : 1}]
    global db currentUser
    set escUser [string map {"'" "''"} $currentUser]
    if {[catch {
        db eval "UPDATE timetable_slots SET locked=$newLock, modified_by='$escUser' WHERE slot_id=$slotId"
    } err]} { tk_messageBox -title "Error" -message $err -icon error ; return }
    populateSlotList
    buildEditorGrid
    .slotlist.sb.txt configure -text "Slot $slotId [expr {$newLock ? {locked} : {unlocked}}]."
}

# =============================================================================
#  FACULTY HOUR ASSIGNMENT  (standalone panel — unchanged, kept for
#  backward compatibility with dashboard / menu calls)
# =============================================================================
proc openFacultyHourAssignment {} {
    if {![requireEditTimetablePermission]} { return }
    set w .fhassign
    if {[winfo exists $w]} { raise $w ; return }
    toplevel $w
    wm title $w "Assign Faculty to Hours"
    wm geometry $w "980x640"
    $w configure -bg white

    label $w.title -text "FACULTY HOUR ASSIGNMENT" \
        -font {Arial 16 bold} -bg "#1565C0" -fg white -pady 8
    pack $w.title -fill x

    frame $w.infobar -bg "#E3F2FD" -relief flat
    pack  $w.infobar -fill x -padx 0
    label $w.infobar.txt \
        -text "  Select dept, year, semester, section -> Load Periods -> click a row -> pick faculty -> Assign." \
        -font {Arial 9} -bg "#E3F2FD" -fg "#0D47A1" -anchor w
    pack $w.infobar.txt -pady 4 -anchor w

    frame $w.filter -bg white -relief groove -bd 1
    pack  $w.filter -fill x -padx 10 -pady 6

    foreach {lbl vn def vals wd} {
        "Dept :"    fha_dept  ""         {}  20
        "Year :"    fha_year  "1st Year" {"1st Year" "2nd Year" "3rd Year" "4th Year"} 10
        "Sem :"     fha_sem   "1"        {1 2 3 4 5 6 7 8}  5
        "Section :" fha_sect  "A"        {A B C D}  5
    } {
        label $w.filter.l_$vn -text $lbl -bg white -font {Arial 10 bold}
        pack  $w.filter.l_$vn -side left -padx {10 2}
        ttk::combobox $w.filter.cb_$vn -width $wd
        if {[llength $vals]} { $w.filter.cb_$vn configure -values $vals }
        $w.filter.cb_$vn set $def
        pack $w.filter.cb_$vn -side left -padx 4
    }
    $w.filter.cb_fha_dept configure -values [loadTimetableDepartments]
    button $w.filter.load -text "Load Periods" -width 14 -command {loadFacultyHourSlots}
    pack   $w.filter.load -side left -padx 12

    frame $w.main -bg white
    pack  $w.main -fill both -expand 1 -padx 10 -pady 6

    frame $w.main.left -bg white
    pack  $w.main.left -side left -fill both -expand 1

    label $w.main.left.lbl -text "Periods / Slots  (click row -> assign faculty on right)" \
        -bg white -font {Arial 10 bold} -anchor w
    pack $w.main.left.lbl -anchor w -pady {0 4}

    frame $w.main.left.tf -bg white
    pack  $w.main.left.tf -fill both -expand 1

    ttk::treeview $w.main.left.tf.tree \
        -columns {SlotID Day Period Time Subject Faculty Type} \
        -show headings -selectmode browse \
        -yscrollcommand "$w.main.left.tf.ys set"
    scrollbar $w.main.left.tf.ys -orient vertical -command "$w.main.left.tf.tree yview"

    foreach {col txt cw anc} {
        SlotID "ID" 45 center  Day "Day" 85 center  Period "Pd" 50 center
        Time "Time" 75 center  Subject "Subject" 200 w  Faculty "Assigned Faculty" 180 w  Type "Type" 60 center
    } {
        $w.main.left.tf.tree heading $col -text $txt
        $w.main.left.tf.tree column  $col -width $cw -anchor $anc
    }
    $w.main.left.tf.tree tag configure assigned   -background "#E8F5E9"
    $w.main.left.tf.tree tag configure unassigned -background "#FFF3E0"

    grid $w.main.left.tf.tree -row 0 -column 0 -sticky nsew
    grid $w.main.left.tf.ys   -row 0 -column 1 -sticky ns
    grid rowconfigure    $w.main.left.tf 0 -weight 1
    grid columnconfigure $w.main.left.tf 0 -weight 1

    bind $w.main.left.tf.tree <<TreeviewSelect>> {fillFacultyAssignPanel}

    frame $w.main.right -bg "#F8FBFF" -relief solid -bd 1 -width 260
    pack  $w.main.right -side right -fill y -padx {10 0}
    pack propagate $w.main.right 0

    label $w.main.right.t1  -text "Assign Faculty" -font {Arial 12 bold} \
        -bg "#F8FBFF" -anchor w
    pack  $w.main.right.t1 -padx 14 -pady {14 4} -anchor w

    label $w.main.right.slotlbl -text "Selected period:" \
        -font {Arial 9} -bg "#F8FBFF" -fg "#64748B" -anchor w
    pack $w.main.right.slotlbl -padx 14 -anchor w

    label $w.main.right.slotinfo -text "-- none selected --" \
        -font {Arial 10 bold} -bg "#F8FBFF" -fg "#0F4C81" \
        -anchor w -wraplength 220 -justify left
    pack $w.main.right.slotinfo -padx 14 -pady {2 10} -anchor w

    label $w.main.right.fl -text "Faculty Member :" \
        -font {Arial 10 bold} -bg "#F8FBFF" -anchor w
    pack $w.main.right.fl -padx 14 -anchor w

    ttk::combobox $w.main.right.faculty -values [loadEditorFacultyList] -width 28
    pack $w.main.right.faculty -padx 14 -pady {4 12} -anchor w

    button $w.main.right.assign -text "Assign to This Period" -width 22 \
        -bg "#1565C0" -fg white -command {assignFacultyToSelectedSlot}
    pack $w.main.right.assign -padx 14 -pady 4

    button $w.main.right.clear -text "Clear Assignment" -width 22 \
        -command {clearFacultyFromSelectedSlot}
    pack $w.main.right.clear -padx 14 -pady 4

    frame $w.sb -bg "#F1F5F9" -relief solid -bd 1
    pack  $w.sb -fill x -padx 10 -side bottom -pady 4
    label $w.sb.txt -text "Load periods, pick a row, choose faculty, click Assign." \
        -font {Arial 9} -bg "#F1F5F9" -fg "#475569" -anchor w
    pack $w.sb.txt -padx 10 -pady 4

    frame $w.cb -bg white
    pack  $w.cb -pady 6 -side bottom
    button $w.cb.close -text "Close" -width 12 -command [list destroy $w]
    pack   $w.cb.close

    applyThemeToWindow $w
}

proc loadFacultyHourSlots {} {
    global db
    set w .fhassign
    if {![winfo exists $w.main.left.tf.tree]} { return }
    set dept [string trim [$w.filter.cb_fha_dept get]]
    set year [string trim [$w.filter.cb_fha_year get]]
    set sem  [string trim [$w.filter.cb_fha_sem  get]]
    set sect [string trim [$w.filter.cb_fha_sect get]]
    if {$dept eq "" || $sem eq ""} { fhaStatus "Select Dept and Semester first." ; return }
    $w.main.left.tf.tree delete [$w.main.left.tf.tree children {}]
    set escDept [string map {"'" "''"} $dept]
    set escYear [string map {"'" "''"} $year]
    set escSect [string map {"'" "''"} $sect]
    set count 0 ; set unassigned 0
    db eval "SELECT ts.slot_id, ts.day_of_week, ts.period_number, ts.start_time,
                    ts.subject_name, COALESCE(ts.staff_name,'') AS staff_name, ts.slot_type
             FROM timetable_slots ts JOIN timetables t ON t.timetable_id=ts.timetable_id
             WHERE t.semester=$sem AND t.year='$escYear' AND t.section='$escSect'
               AND ([departmentMatchSql t.department $dept])
               AND ts.slot_type IN ('Class','Lab')
             ORDER BY CASE ts.day_of_week
               WHEN 'Monday' THEN 1 WHEN 'Tuesday' THEN 2 WHEN 'Wednesday' THEN 3
               WHEN 'Thursday' THEN 4 WHEN 'Friday' THEN 5 ELSE 6 END,
               ts.period_number" row {
        set isA [expr {$row(staff_name) ne "" && $row(staff_name) ne "Not Assigned" && $row(staff_name) ne "TBA"}]
        $w.main.left.tf.tree insert {} end -values [list \
            $row(slot_id) $row(day_of_week) $row(period_number) \
            $row(start_time) $row(subject_name) $row(staff_name) $row(slot_type)] \
            -tags [expr {$isA ? "assigned" : "unassigned"}]
        incr count
        if {!$isA} { incr unassigned }
    }
    fhaStatus "Loaded $count period(s). Unassigned: $unassigned  |  Green=assigned  Amber=needs faculty"
}

proc fillFacultyAssignPanel {} {
    set w .fhassign
    if {![winfo exists $w.main.left.tf.tree]} { return }
    set sel [$w.main.left.tf.tree selection]
    if {$sel eq ""} { return }
    lassign [$w.main.left.tf.tree item $sel -values] slotId day period time subj faculty stype
    $w.main.right.slotinfo configure -text "$day  |  Period $period  ($time)\n$subj"
    $w.main.right.faculty set $faculty
}

proc assignFacultyToSelectedSlot {} {
    global db currentUser
    if {![requireEditTimetablePermission]} { return }
    set w .fhassign
    set sel [$w.main.left.tf.tree selection]
    if {$sel eq ""} { fhaStatus "Select a period row first." ; return }
    lassign [$w.main.left.tf.tree item $sel -values] slotId day period time subj _ stype
    set newFac [string trim [$w.main.right.faculty get]]
    if {$newFac eq ""} { fhaStatus "Choose a faculty member." ; return }
    set conflict [validateSlotConflicts "" $day $period $stype $subj $newFac "" "" "" $slotId]
    if {$conflict ne ""} { fhaStatus "Conflict: $conflict" ; return }
    set escFac  [string map {"'" "''"} $newFac]
    set escUser [string map {"'" "''"} $currentUser]
    if {[catch {
        db eval "UPDATE timetable_slots SET staff_name='$escFac', modified_by='$escUser' WHERE slot_id=$slotId"
    } err]} { fhaStatus "DB Error: $err" ; return }
    $w.main.left.tf.tree item $sel \
        -values [list $slotId $day $period $time $subj $newFac $stype] \
        -tags assigned
    fhaStatus "Period $period on $day -> assigned to \"$newFac\"."
}

proc clearFacultyFromSelectedSlot {} {
    global db currentUser
    if {![requireEditTimetablePermission]} { return }
    set w .fhassign
    set sel [$w.main.left.tf.tree selection]
    if {$sel eq ""} { fhaStatus "Select a row first." ; return }
    lassign [$w.main.left.tf.tree item $sel -values] slotId day period time subj oldFac stype
    if {[tk_messageBox -type yesno -icon question -title "Clear" \
            -message "Remove \"$oldFac\" from $day Period $period?"] ne "yes"} { return }
    set escUser [string map {"'" "''"} $currentUser]
    if {[catch {
        db eval "UPDATE timetable_slots SET staff_name='TBA', modified_by='$escUser' WHERE slot_id=$slotId"
    } err]} { fhaStatus "DB Error: $err" ; return }
    $w.main.left.tf.tree item $sel \
        -values [list $slotId $day $period $time $subj "TBA" $stype] \
        -tags unassigned
    $w.main.right.faculty set ""
    fhaStatus "Faculty cleared from Period $period on $day."
}

proc fhaStatus {msg} {
    if {[winfo exists .fhassign.sb.txt]} {
        .fhassign.sb.txt configure -text $msg
    }
}

# Legacy aliases so any old call sites still work
proc loadEditorSlots {} { buildEditorGrid }
proc editorStatus   {msg} { editorGridStatus $msg }
proc selectedEditorSlotId {} { return "" }
proc selectedEditorSlotValues {} { return {} }
