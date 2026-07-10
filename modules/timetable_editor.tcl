# ─────────────────────────────────────────────────────────────────────────────
#  Timetable Editor Module
#  Only users with can_edit_timetable = 1 may generate, edit, swap, delete
#  or save timetable slots.  Every write validates:
#   • Faculty conflict  – same faculty already assigned that day/period
#   • Classroom conflict – same room already booked that day/period
#   • Time-slot conflict – section already has a class that day/period
# ─────────────────────────────────────────────────────────────────────────────

# ── Permission guard ─────────────────────────────────────────────────────────

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

# Call this at the top of every write operation.
# Returns 1 if allowed, 0 if denied (and shows an error dialog).
proc requireEditTimetablePermission {} {
    if {[currentUserCanEditTimetable]} { return 1 }
    tk_messageBox \
        -title "Permission Denied" \
        -message "Your account does not have the \"Edit Timetable\" permission.\
\n\nAsk an Admin to enable it in User Management." \
        -icon error
    return 0
}

# ── Conflict validators ───────────────────────────────────────────────────────

# Returns a human-readable conflict message, or "" if no conflict.
# excludeSlotId: slot being edited (so it doesn't clash with itself)
proc validateSlotConflicts {timetableId day periodNumber slotType
                             subjectName staffName department section
                             classroom excludeSlotId} {
    global db
    set msgs {}

    # Only Class/Lab slots generate hard conflicts; Breaks are always safe
    if {[string equal -nocase $slotType "Break"]} { return "" }

    set excl [expr {$excludeSlotId ne "" ? "AND slot_id <> $excludeSlotId" : ""}]
    set qDay  [sqlQuote $day]
    set qSect [sqlQuote $section]
    set qDept [sqlQuote $department]

    # 1. Section conflict – same dept+section already has a slot this period
    if {$section ne "" && $department ne ""} {
        db eval "SELECT COUNT(*) AS n FROM timetable_slots
                 WHERE day_of_week = $qDay
                   AND period_number = $periodNumber
                   AND slot_type IN ('Class','Lab')
                   AND department = $qDept
                   AND section    = $qSect
                   $excl" row {
            if {$row(n) > 0} {
                lappend msgs "Section $department-$section already has a class in period $periodNumber on $day."
            }
        }
    }

    # 2. Faculty conflict – same staff_name this day/period across all timetables
    if {$staffName ne "" && $staffName ne "Not Assigned"} {
        set qStaff [sqlQuote $staffName]
        db eval "SELECT COUNT(*) AS n FROM timetable_slots
                 WHERE day_of_week  = $qDay
                   AND period_number = $periodNumber
                   AND slot_type IN ('Class','Lab')
                   AND staff_name   = $qStaff
                   $excl" row {
            if {$row(n) > 0} {
                lappend msgs "Faculty \"$staffName\" is already assigned to period $periodNumber on $day."
            }
        }
    }

    # 3. Classroom conflict – same room this day/period across all timetables
    if {$classroom ne ""} {
        set qRoom [sqlQuote $classroom]
        db eval "SELECT COUNT(*) AS n FROM timetable_slots
                 WHERE day_of_week   = $qDay
                   AND period_number  = $periodNumber
                   AND slot_type IN ('Class','Lab')
                   AND classroom      = $qRoom
                   $excl" row {
            if {$row(n) > 0} {
                lappend msgs "Classroom \"$classroom\" is already booked for period $periodNumber on $day."
            }
        }
    }

    return [join $msgs "\n"]
}

# ── Open the editor ───────────────────────────────────────────────────────────

proc openTimetableEditor {} {
    if {![requireEditTimetablePermission]} { return }

    if {[winfo exists .tteditor]} { raise .tteditor ; return }

    toplevel .tteditor
    wm title .tteditor "Timetable Editor"
    wm geometry .tteditor "1100x680"
    .tteditor configure -bg white

    label .tteditor.title -text "TIMETABLE EDITOR" \
        -font {Arial 18 bold} -bg "#1565C0" -fg white
    pack .tteditor.title -fill x -pady 10

    # ── Filter bar ────────────────────────────────────────────────────────────
    frame .tteditor.filter -bg white
    pack  .tteditor.filter -fill x -padx 14 -pady 6

    label .tteditor.filter.ld -text "Department :" -bg white
    pack  .tteditor.filter.ld -side left
    ttk::combobox .tteditor.filter.dept \
        -values [loadTimetableDepartments] -width 22
    pack .tteditor.filter.dept -side left -padx 6

    label .tteditor.filter.ly -text "Year :" -bg white
    pack  .tteditor.filter.ly -side left -padx {10 0}
    ttk::combobox .tteditor.filter.year \
        -values {"1st Year" "2nd Year" "3rd Year" "4th Year"} -width 10
    .tteditor.filter.year set "1st Year"
    pack .tteditor.filter.year -side left -padx 6

    label .tteditor.filter.ls -text "Semester :" -bg white
    pack  .tteditor.filter.ls -side left -padx {10 0}
    ttk::combobox .tteditor.filter.sem \
        -values {1 2 3 4 5 6 7 8} -width 6 -state readonly
    .tteditor.filter.sem set "1"
    pack .tteditor.filter.sem -side left -padx 6

    label .tteditor.filter.lsc -text "Section :" -bg white
    pack  .tteditor.filter.lsc -side left -padx {10 0}
    ttk::combobox .tteditor.filter.section \
        -values {A B C D} -width 6
    .tteditor.filter.section set "A"
    pack .tteditor.filter.section -side left -padx 6

    button .tteditor.filter.load -text "Load Slots" -width 12 \
        -command {loadEditorSlots}
    pack .tteditor.filter.load -side left -padx 10

    # ── Action buttons ────────────────────────────────────────────────────────
    frame .tteditor.actions -bg white
    pack  .tteditor.actions -fill x -padx 14 -pady 4

    button .tteditor.actions.edit   -text "Edit Selected"   -width 14 \
        -command {openEditSlotDialog}
    button .tteditor.actions.swap   -text "Swap Two Slots"  -width 14 \
        -command {openSwapSlotsDialog}
    button .tteditor.actions.del    -text "Delete Selected" -width 14 \
        -command {deleteSelectedEditorSlot}
    button .tteditor.actions.add    -text "Add New Slot"    -width 14 \
        -command {openAddSlotDialog}
    button .tteditor.actions.lock   -text "Lock Selected"   -width 14 \
        -command {toggleLockSelectedSlot}
    button .tteditor.actions.refresh -text "Refresh"        -width 10 \
        -command {loadEditorSlots}
    button .tteditor.actions.close  -text "Close"           -width 10 \
        -command {destroy .tteditor}

    foreach btn {edit swap del add lock refresh close} {
        pack .tteditor.actions.$btn -side left -padx 5
    }

    # ── Status bar ────────────────────────────────────────────────────────────
    frame .tteditor.statusbar -bg "#F1F5F9" -relief solid -bd 1
    pack  .tteditor.statusbar -fill x -padx 14 -pady 4
    label .tteditor.statusbar.txt \
        -text "Load slots using the filter above." \
        -font {Arial 9} -bg "#F1F5F9" -fg "#475569" -anchor w
    pack .tteditor.statusbar.txt -padx 10 -pady 4 -anchor w

    # ── Treeview ──────────────────────────────────────────────────────────────
    frame .tteditor.tblframe -bg white
    pack  .tteditor.tblframe -fill both -expand 1 -padx 14 -pady 6

    set cols {SlotID Day Period Time Type Subject Faculty Classroom Section Locked}
    ttk::style configure TTE.Treeview -font {Arial 9} -rowheight 25
    ttk::style configure TTE.Treeview.Heading \
        -font {Arial 9 bold} -background "#1565C0" -foreground white

    ttk::treeview .tteditor.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style TTE.Treeview \
        -yscrollcommand {.tteditor.tblframe.ys set} \
        -xscrollcommand {.tteditor.tblframe.xs set}

    scrollbar .tteditor.tblframe.ys -orient vertical   -command {.tteditor.tblframe.tree yview}
    scrollbar .tteditor.tblframe.xs -orient horizontal -command {.tteditor.tblframe.tree xview}

    foreach {col txt w} {
        SlotID   "ID"        45
        Day      "Day"       80
        Period   "Pd"        40
        Time     "Time"      75
        Type     "Type"      60
        Subject  "Subject"  180
        Faculty  "Faculty"  155
        Classroom "Room"     80
        Section  "Section"   65
        Locked   "Locked"    55
    } {
        .tteditor.tblframe.tree heading $col -text $txt
        .tteditor.tblframe.tree column  $col -width $w -anchor w
    }
    .tteditor.tblframe.tree column SlotID  -anchor center
    .tteditor.tblframe.tree column Period  -anchor center
    .tteditor.tblframe.tree column Type    -anchor center
    .tteditor.tblframe.tree column Locked  -anchor center

    .tteditor.tblframe.tree tag configure class  -background "#F7FBFF"
    .tteditor.tblframe.tree tag configure lab    -background "#E8F5E9"
    .tteditor.tblframe.tree tag configure brk    -background "#FFF3E0"
    .tteditor.tblframe.tree tag configure locked -background "#FEE2E2"

    grid .tteditor.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .tteditor.tblframe.ys   -row 0 -column 1 -sticky ns
    grid .tteditor.tblframe.xs   -row 1 -column 0 -sticky ew
    grid rowconfigure    .tteditor.tblframe 0 -weight 1
    grid columnconfigure .tteditor.tblframe 0 -weight 1

    applyThemeToWindow .tteditor
    # Re-apply heading colour after applyThemeToWindow may override it
    catch { ttk::style configure TTE.Treeview.Heading -background "#1565C0" -foreground white }
}

# ── Load slots into treeview ─────────────────────────────────────────────────

proc loadEditorSlots {} {
    global db
    if {![winfo exists .tteditor.tblframe.tree]} { return }

    set dept    [string trim [.tteditor.filter.dept    get]]
    set year    [string trim [.tteditor.filter.year    get]]
    set sem     [string trim [.tteditor.filter.sem     get]]
    set section [string trim [.tteditor.filter.section get]]

    if {$dept eq "" || $sem eq ""} {
        editorStatus "Select Department and Semester, then click Load Slots."
        return
    }

    .tteditor.tblframe.tree delete [.tteditor.tblframe.tree children {}]

    set escDept    [string map {"'" "''"} $dept]
    set escYear    [string map {"'" "''"} $year]
    set escSection [string map {"'" "''"} $section]

    set sql "SELECT ts.slot_id, ts.day_of_week, ts.period_number, ts.start_time,
                    ts.slot_type, ts.subject_name, ts.staff_name, ts.classroom,
                    ts.section, COALESCE(ts.locked,0) AS locked
             FROM timetable_slots ts
             JOIN timetables t ON t.timetable_id = ts.timetable_id
             WHERE t.semester = $sem
               AND t.year = '$escYear'
               AND (t.department = '$escDept'
                    OR t.department IN (SELECT department_name FROM departments WHERE short_name = '$escDept')
                    OR t.department IN (SELECT short_name      FROM departments WHERE department_name = '$escDept'))
               AND t.section = '$escSection'
             ORDER BY
               CASE ts.day_of_week
                 WHEN 'Monday'    THEN 1 WHEN 'Tuesday'  THEN 2
                 WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4
                 WHEN 'Friday'    THEN 5 ELSE 6 END,
               ts.period_number, ts.start_time"

    set count 0
    db eval $sql row {
        set lockedLbl [expr {$row(locked) ? "Yes" : ""}]
        if {$row(locked)} {
            set tag "locked"
        } elseif {[string equal -nocase $row(slot_type) "Lab"]} {
            set tag "lab"
        } elseif {[string equal -nocase $row(slot_type) "Break"]} {
            set tag "brk"
        } else {
            set tag "class"
        }
        .tteditor.tblframe.tree insert {} end -values [list \
            $row(slot_id) $row(day_of_week) $row(period_number) \
            $row(start_time) $row(slot_type) $row(subject_name) \
            $row(staff_name) $row(classroom) $row(section) \
            $lockedLbl] -tags $tag
        incr count
    }
    editorStatus "Loaded $count slot(s) for $dept / $year / Sem $sem / Section $section."
}

proc editorStatus {msg} {
    if {[winfo exists .tteditor.statusbar.txt]} {
        .tteditor.statusbar.txt configure -text $msg
    }
}

proc selectedEditorSlotId {} {
    if {![winfo exists .tteditor.tblframe.tree]} { return "" }
    set sel [.tteditor.tblframe.tree selection]
    if {$sel eq ""} { return "" }
    return [lindex [.tteditor.tblframe.tree item $sel -values] 0]
}

proc selectedEditorSlotValues {} {
    if {![winfo exists .tteditor.tblframe.tree]} { return {} }
    set sel [.tteditor.tblframe.tree selection]
    if {$sel eq ""} { return {} }
    return [.tteditor.tblframe.tree item $sel -values]
}

# ── Edit Slot Dialog ──────────────────────────────────────────────────────────

proc openEditSlotDialog {} {
    if {![requireEditTimetablePermission]} { return }
    set vals [selectedEditorSlotValues]
    if {[llength $vals] == 0} {
        tk_messageBox -title "Edit" -message "Select a slot row first." -icon info
        return
    }
    lassign $vals slotId day period time stype subject faculty classroom section locked
    if {$locked eq "Yes"} {
        tk_messageBox -title "Locked" \
            -message "This slot is locked and cannot be edited.\nUnlock it first." \
            -icon warning
        return
    }

    set w .editslot
    if {[winfo exists $w]} { destroy $w }
    toplevel $w
    wm title $w "Edit Slot — ID $slotId"
    wm geometry $w "460x420"
    wm resizable $w 0 0
    $w configure -bg white

    label $w.title -text "EDIT TIMETABLE SLOT" \
        -font {Arial 13 bold} -bg "#1565C0" -fg white
    pack $w.title -fill x -pady 10

    frame $w.form -bg white
    pack  $w.form -pady 8 -padx 20 -fill x

    set row 0
    foreach {lbl key defval widget} [list \
        "Day"        day       $day       "entry" \
        "Period No"  period    $period    "entry" \
        "Start Time" time      $time      "entry" \
        "Slot Type"  stype     $stype     "combo_type" \
        "Subject"    subject   $subject   "entry" \
        "Faculty"    faculty   $faculty   "combo_faculty" \
        "Classroom"  classroom $classroom "combo_classroom" \
    ] {
        label $w.form.l$row -text "$lbl :" -bg white -anchor e
        grid  $w.form.l$row -row $row -column 0 -padx 8 -pady 4 -sticky e

        switch $widget {
            "combo_type" {
                ttk::combobox $w.form.v$row \
                    -values {"Class" "Lab" "Break"} -width 30 -state readonly
                $w.form.v$row set $defval
            }
            "combo_faculty" {
                set facList [loadEditorFacultyList]
                ttk::combobox $w.form.v$row -values $facList -width 30
                $w.form.v$row set $defval
            }
            "combo_classroom" {
                set roomList [loadEditorClassroomList]
                ttk::combobox $w.form.v$row -values $roomList -width 30
                $w.form.v$row set $defval
            }
            default {
                entry $w.form.v$row -width 32
                $w.form.v$row insert 0 $defval
            }
        }
        grid $w.form.v$row -row $row -column 1 -padx 8 -pady 4 -sticky w
        incr row
    }
    grid columnconfigure $w.form 1 -weight 1

    # Status label inside dialog
    label $w.status -text "" -fg "#DC2626" -bg white -wraplength 400 -justify left
    pack  $w.status -padx 20 -pady 4 -anchor w

    frame $w.btns -bg white
    pack  $w.btns -pady 10

    button $w.btns.save -text "Save Changes" -width 14 -command [list saveEditedSlot $w $slotId $section]
    button $w.btns.cancel -text "Cancel" -width 10 -command [list destroy $w]
    pack $w.btns.save   -side left -padx 8
    pack $w.btns.cancel -side left -padx 8

    applyThemeToWindow $w
}

proc saveEditedSlot {w slotId section} {
    global db currentUser
    if {![requireEditTimetablePermission]} { return }

    set day       [string trim [$w.form.v0 get]]
    set period    [string trim [$w.form.v1 get]]
    set time      [string trim [$w.form.v2 get]]
    set stype     [string trim [$w.form.v3 get]]
    set subject   [string trim [$w.form.v4 get]]
    set faculty   [string trim [$w.form.v5 get]]
    set classroom [string trim [$w.form.v6 get]]

    if {$day eq "" || $period eq "" || $subject eq ""} {
        $w.status configure -text "Day, Period and Subject are required."
        return
    }
    if {![string is integer -strict $period]} {
        $w.status configure -text "Period must be a number."
        return
    }

    # Get dept from existing slot
    set dept ""
    db eval "SELECT department FROM timetable_slots WHERE slot_id = $slotId" r { set dept $r(department) }

    set conflict [validateSlotConflicts "" $day $period $stype \
        $subject $faculty $dept $section $classroom $slotId]
    if {$conflict ne ""} {
        $w.status configure -text "Conflict detected:\n$conflict"
        return
    }

    set escDay     [string map {"'" "''"} $day]
    set escTime    [string map {"'" "''"} $time]
    set escType    [string map {"'" "''"} $stype]
    set escSubject [string map {"'" "''"} $subject]
    set escFaculty [string map {"'" "''"} $faculty]
    set escRoom    [string map {"'" "''"} $classroom]
    set escUser    [string map {"'" "''"} $currentUser]

    if {[catch {
        db eval "UPDATE timetable_slots
                 SET day_of_week='$escDay', period_number=$period,
                     start_time='$escTime', slot_type='$escType',
                     subject_name='$escSubject', staff_name='$escFaculty',
                     classroom='$escRoom', modified_by='$escUser'
                 WHERE slot_id = $slotId"
    } err]} {
        $w.status configure -text "DB Error: $err"
        return
    }

    destroy $w
    loadEditorSlots
    editorStatus "Slot $slotId updated successfully."
}

# ── Add New Slot Dialog ───────────────────────────────────────────────────────

proc openAddSlotDialog {} {
    if {![requireEditTimetablePermission]} { return }

    # Resolve the timetable_id for the current filter
    set timetableId [resolveEditorTimetableId]
    if {$timetableId eq ""} {
        tk_messageBox -title "No Timetable" \
            -message "Load an existing timetable first before adding slots.\
\nUse the Timetable Generator to create one." -icon warning
        return
    }

    set w .addslot
    if {[winfo exists $w]} { destroy $w }
    toplevel $w
    wm title $w "Add New Slot"
    wm geometry $w "460x400"
    wm resizable $w 0 0
    $w configure -bg white

    label $w.title -text "ADD TIMETABLE SLOT" \
        -font {Arial 13 bold} -bg "#1565C0" -fg white
    pack $w.title -fill x -pady 10

    frame $w.form -bg white
    pack  $w.form -pady 8 -padx 20 -fill x

    set row 0
    foreach {lbl defval widget} [list \
        "Day"        "Monday"  "combo_day" \
        "Period No"  "1"       "entry" \
        "Start Time" "08:30"   "entry" \
        "Slot Type"  "Class"   "combo_type" \
        "Subject"    ""        "entry" \
        "Faculty"    ""        "combo_faculty" \
        "Classroom"  ""        "combo_classroom" \
    ] {
        label $w.form.l$row -text "$lbl :" -bg white -anchor e
        grid  $w.form.l$row -row $row -column 0 -padx 8 -pady 4 -sticky e
        switch $widget {
            "combo_day" {
                ttk::combobox $w.form.v$row \
                    -values {Monday Tuesday Wednesday Thursday Friday} \
                    -width 30 -state readonly
                $w.form.v$row set $defval
            }
            "combo_type" {
                ttk::combobox $w.form.v$row \
                    -values {"Class" "Lab" "Break"} -width 30 -state readonly
                $w.form.v$row set $defval
            }
            "combo_faculty" {
                ttk::combobox $w.form.v$row \
                    -values [loadEditorFacultyList] -width 30
                $w.form.v$row set $defval
            }
            "combo_classroom" {
                ttk::combobox $w.form.v$row \
                    -values [loadEditorClassroomList] -width 30
                $w.form.v$row set $defval
            }
            default {
                entry $w.form.v$row -width 32
                $w.form.v$row insert 0 $defval
            }
        }
        grid $w.form.v$row -row $row -column 1 -padx 8 -pady 4 -sticky w
        incr row
    }
    grid columnconfigure $w.form 1 -weight 1

    label $w.status -text "" -fg "#DC2626" -bg white -wraplength 400 -justify left
    pack  $w.status -padx 20 -pady 4 -anchor w

    frame $w.btns -bg white
    pack  $w.btns -pady 10

    set section [.tteditor.filter.section get]
    set dept    [.tteditor.filter.dept get]
    button $w.btns.save   -text "Add Slot"  -width 12 \
        -command [list saveNewSlot $w $timetableId $dept $section]
    button $w.btns.cancel -text "Cancel"    -width 10 -command [list destroy $w]
    pack $w.btns.save   -side left -padx 8
    pack $w.btns.cancel -side left -padx 8

    applyThemeToWindow $w
}

proc saveNewSlot {w timetableId dept section} {
    global db currentUser
    if {![requireEditTimetablePermission]} { return }

    set day       [string trim [$w.form.v0 get]]
    set period    [string trim [$w.form.v1 get]]
    set time      [string trim [$w.form.v2 get]]
    set stype     [string trim [$w.form.v3 get]]
    set subject   [string trim [$w.form.v4 get]]
    set faculty   [string trim [$w.form.v5 get]]
    set classroom [string trim [$w.form.v6 get]]

    if {$day eq "" || $period eq "" || $subject eq ""} {
        $w.status configure -text "Day, Period and Subject are required."
        return
    }
    if {![string is integer -strict $period]} {
        $w.status configure -text "Period must be a number."
        return
    }

    set conflict [validateSlotConflicts $timetableId $day $period $stype \
        $subject $faculty $dept $section $classroom ""]
    if {$conflict ne ""} {
        $w.status configure -text "Conflict:\n$conflict"
        return
    }

    set escDay     [string map {"'" "''"} $day]
    set escTime    [string map {"'" "''"} $time]
    set escType    [string map {"'" "''"} $stype]
    set escSubject [string map {"'" "''"} $subject]
    set escFaculty [string map {"'" "''"} $faculty]
    set escRoom    [string map {"'" "''"} $classroom]
    set escDept    [string map {"'" "''"} $dept]
    set escSect    [string map {"'" "''"} $section]
    set escUser    [string map {"'" "''"} $currentUser]

    if {[catch {
        db eval "INSERT INTO timetable_slots
                     (timetable_id, day_of_week, period_number, slot_type,
                      start_time, subject_name, staff_name, department,
                      section, classroom, modified_by, locked)
                 VALUES ($timetableId,'$escDay',$period,'$escType',
                         '$escTime','$escSubject','$escFaculty','$escDept',
                         '$escSect','$escRoom','$escUser',0)"
    } err]} {
        $w.status configure -text "DB Error: $err"
        return
    }

    destroy $w
    loadEditorSlots
    editorStatus "New slot added to timetable $timetableId."
}

# ── Swap Two Slots Dialog ─────────────────────────────────────────────────────

proc openSwapSlotsDialog {} {
    if {![requireEditTimetablePermission]} { return }
    set vals [selectedEditorSlotValues]
    if {[llength $vals] == 0} {
        tk_messageBox -title "Swap" -message "Select the FIRST slot to swap, then click Swap Two Slots." -icon info
        return
    }
    lassign $vals slotId1 day1 period1 time1 stype1 subject1 faculty1 room1 section1 locked1
    if {$locked1 eq "Yes"} {
        tk_messageBox -title "Locked" -message "Slot $slotId1 is locked. Unlock it first." -icon warning
        return
    }

    set w .swapslots
    if {[winfo exists $w]} { destroy $w }
    toplevel $w
    wm title $w "Swap Slots"
    wm geometry $w "500x320"
    wm resizable $w 0 0
    $w configure -bg white

    label $w.title -text "SWAP TWO SLOTS" \
        -font {Arial 13 bold} -bg "#1565C0" -fg white
    pack $w.title -fill x -pady 10

    frame $w.info -bg "#EAF3FC" -relief solid -bd 1
    pack  $w.info -padx 20 -pady 8 -fill x

    label $w.info.l1 \
        -text "Slot A (selected):  $day1  Period $period1  —  $subject1  |  $faculty1" \
        -bg "#EAF3FC" -font {Arial 10} -anchor w
    pack $w.info.l1 -padx 12 -pady 6 -anchor w

    frame $w.form -bg white
    pack  $w.form -padx 20 -pady 8 -fill x

    label $w.form.l1 -text "Slot B — ID to swap with :" -bg white -font {Arial 10 bold}
    grid  $w.form.l1 -row 0 -column 0 -padx 8 -pady 6 -sticky e
    entry $w.form.slotB -width 12
    grid  $w.form.slotB -row 0 -column 1 -padx 8 -sticky w

    label $w.form.hint \
        -text "(enter the Slot ID from the editor table)" \
        -bg white -font {Arial 8} -fg "#888888"
    grid $w.form.hint -row 1 -column 1 -padx 8 -sticky w

    label $w.status -text "" -fg "#DC2626" -bg white -wraplength 460 -justify left
    pack  $w.status -padx 20 -pady 4 -anchor w

    frame $w.btns -bg white
    pack  $w.btns -pady 12

    button $w.btns.swap   -text "Swap Now" -width 14 \
        -command [list executeSwapSlots $w $slotId1]
    button $w.btns.cancel -text "Cancel"   -width 10 \
        -command [list destroy $w]
    pack $w.btns.swap   -side left -padx 8
    pack $w.btns.cancel -side left -padx 8

    applyThemeToWindow $w
}

proc executeSwapSlots {w slotId1} {
    global db currentUser
    if {![requireEditTimetablePermission]} { return }

    set slotId2 [string trim [$w.form.slotB get]]
    if {$slotId2 eq "" || ![string is integer -strict $slotId2]} {
        $w.status configure -text "Enter a valid Slot ID for Slot B."
        return
    }
    if {$slotId1 == $slotId2} {
        $w.status configure -text "Slot A and Slot B must be different."
        return
    }

    # Read both slots
    set s1 {}; set s2 {}
    db eval "SELECT day_of_week, period_number, start_time, staff_name,
                    classroom, subject_name, locked
             FROM timetable_slots WHERE slot_id = $slotId1" r {
        set s1 [list $r(day_of_week) $r(period_number) $r(start_time) \
                     $r(staff_name) $r(classroom) $r(subject_name) $r(locked)]
    }
    db eval "SELECT day_of_week, period_number, start_time, staff_name,
                    classroom, subject_name, locked
             FROM timetable_slots WHERE slot_id = $slotId2" r {
        set s2 [list $r(day_of_week) $r(period_number) $r(start_time) \
                     $r(staff_name) $r(classroom) $r(subject_name) $r(locked)]
    }

    if {[llength $s1] == 0} { $w.status configure -text "Slot A (ID $slotId1) not found." ; return }
    if {[llength $s2] == 0} { $w.status configure -text "Slot B (ID $slotId2) not found." ; return }

    if {[lindex $s1 6]} { $w.status configure -text "Slot A is locked." ; return }
    if {[lindex $s2 6]} { $w.status configure -text "Slot B is locked." ; return }

    lassign $s1 day1 period1 time1 staff1 room1 subj1 _
    lassign $s2 day2 period2 time2 staff2 room2 subj2 _
    set escUser [string map {"'" "''"} $currentUser]

    # Swap day, period, start_time between the two slots
    if {[catch {
        db eval "UPDATE timetable_slots
                 SET day_of_week='[string map {"'" "''"} $day2]',
                     period_number=$period2,
                     start_time='[string map {"'" "''"} $time2]',
                     modified_by='$escUser'
                 WHERE slot_id = $slotId1"
        db eval "UPDATE timetable_slots
                 SET day_of_week='[string map {"'" "''"} $day1]',
                     period_number=$period1,
                     start_time='[string map {"'" "''"} $time1]',
                     modified_by='$escUser'
                 WHERE slot_id = $slotId2"
    } err]} {
        $w.status configure -text "DB Error: $err"
        return
    }

    destroy $w
    loadEditorSlots
    editorStatus "Slot $slotId1 and Slot $slotId2 swapped successfully."
}

# ── Delete Selected Slot ──────────────────────────────────────────────────────

proc deleteSelectedEditorSlot {} {
    if {![requireEditTimetablePermission]} { return }
    set vals [selectedEditorSlotValues]
    if {[llength $vals] == 0} {
        tk_messageBox -title "Delete" -message "Select a slot row first." -icon info
        return
    }
    lassign $vals slotId day period time stype subject faculty
    if {[lindex $vals 9] eq "Yes"} {
        tk_messageBox -title "Locked" \
            -message "This slot is locked and cannot be deleted.\nUnlock it first." \
            -icon warning
        return
    }
    set confirm [tk_messageBox -title "Confirm Delete" \
        -message "Delete slot:\n$day  Period $period  —  $subject  ($faculty)?\nThis cannot be undone." \
        -icon question -type yesno]
    if {$confirm ne "yes"} { return }

    global db
    if {[catch {db eval "DELETE FROM timetable_slots WHERE slot_id = $slotId"} err]} {
        tk_messageBox -title "DB Error" -message "Could not delete:\n$err" -icon error
        return
    }
    loadEditorSlots
    editorStatus "Slot $slotId deleted."
}

# ── Lock / Unlock Selected Slot ───────────────────────────────────────────────

proc toggleLockSelectedSlot {} {
    if {![requireEditTimetablePermission]} { return }
    set vals [selectedEditorSlotValues]
    if {[llength $vals] == 0} {
        tk_messageBox -title "Lock" -message "Select a slot row first." -icon info
        return
    }
    set slotId  [lindex $vals 0]
    set subject [lindex $vals 5]
    set day     [lindex $vals 1]
    set period  [lindex $vals 2]
    set locked  [expr {[lindex $vals 9] eq "Yes" ? 1 : 0}]
    set newLock [expr {$locked ? 0 : 1}]
    set action  [expr {$newLock ? "Lock" : "Unlock"}]

    set confirm [tk_messageBox -title "Confirm $action" \
        -message "$action slot:\n$day  Period $period  —  $subject?" \
        -icon question -type yesno]
    if {$confirm ne "yes"} { return }

    global db currentUser
    set escUser [string map {"'" "''"} $currentUser]
    if {[catch {
        db eval "UPDATE timetable_slots
                 SET locked=$newLock, modified_by='$escUser'
                 WHERE slot_id = $slotId"
    } err]} {
        tk_messageBox -title "DB Error" -message "Could not update lock:\n$err" -icon error
        return
    }
    loadEditorSlots
    editorStatus "Slot $slotId [string tolower $action]ed."
}

# ── Helpers: faculty and classroom lists ──────────────────────────────────────

proc loadEditorFacultyList {} {
    global db
    set list {}
    db eval {SELECT faculty_name FROM faculty ORDER BY faculty_name} row {
        lappend list $row(faculty_name)
    }
    return $list
}

proc loadEditorClassroomList {} {
    global db
    set list {}
    db eval {SELECT room_number, name FROM classrooms ORDER BY room_number} row {
        if {$row(name) ne ""} {
            lappend list "$row(room_number) - $row(name)"
        } else {
            lappend list $row(room_number)
        }
    }
    return $list
}

# Resolve the timetable_id matching the current editor filter
proc resolveEditorTimetableId {} {
    global db
    if {![winfo exists .tteditor.filter.dept]} { return "" }
    set dept    [string trim [.tteditor.filter.dept    get]]
    set year    [string trim [.tteditor.filter.year    get]]
    set sem     [string trim [.tteditor.filter.sem     get]]
    set section [string trim [.tteditor.filter.section get]]
    if {$dept eq "" || $sem eq ""} { return "" }

    set escDept    [string map {"'" "''"} $dept]
    set escYear    [string map {"'" "''"} $year]
    set escSection [string map {"'" "''"} $section]

    set tid ""
    db eval "SELECT timetable_id FROM timetables
             WHERE semester = $sem
               AND year = '$escYear'
               AND section = '$escSection'
               AND (department = '$escDept'
                    OR department IN (SELECT department_name FROM departments WHERE short_name = '$escDept')
                    OR department IN (SELECT short_name FROM departments WHERE department_name = '$escDept'))
             ORDER BY timetable_id DESC LIMIT 1" row {
        set tid $row(timetable_id)
    }
    return $tid
}

# ── Faculty Hour Assignment Panel ─────────────────────────────────────────────
# The timetable incharge selects a period slot and assigns a faculty member.
# This is the core "who handles which hour" workflow.

proc openFacultyHourAssignment {} {
    if {![requireEditTimetablePermission]} { return }

    set w .fhassign
    if {[winfo exists $w]} { raise $w ; return }

    toplevel $w
    wm title $w "Assign Faculty to Hours"
    wm geometry $w "980x640"
    $w configure -bg white

    label $w.title -text "FACULTY HOUR ASSIGNMENT" \
        -font {Arial 18 bold} -bg "#1565C0" -fg white
    pack $w.title -fill x -pady 10

    # ── Info strip ────────────────────────────────────────────────────────────
    frame $w.infobar -bg "#EAF3FC" -relief solid -bd 1
    pack  $w.infobar -fill x -padx 14 -pady 4
    label $w.infobar.txt \
        -text "Select a department, year, semester and section. Then click each slot row and assign a faculty member to that hour." \
        -bg "#EAF3FC" -font {Arial 9} -anchor w -justify left
    pack $w.infobar.txt -padx 10 -pady 6 -anchor w

    # ── Filter bar ────────────────────────────────────────────────────────────
    frame $w.filter -bg white
    pack  $w.filter -fill x -padx 14 -pady 6

    foreach {lbl varname defval vals wd} {
        "Department :" fha_dept    ""         {}                              22
        "Year :"       fha_year    "1st Year" {"1st Year" "2nd Year" "3rd Year" "4th Year"} 10
        "Semester :"   fha_sem     "1"        {1 2 3 4 5 6 7 8}               6
        "Section :"    fha_sect    "A"        {A B C D}                        6
    } {
        label $w.filter.l_$varname -text $lbl -bg white
        pack  $w.filter.l_$varname -side left -padx {10 2}
        ttk::combobox $w.filter.cb_$varname -width $wd
        if {[llength $vals] > 0} {
            $w.filter.cb_$varname configure -values $vals
        }
        $w.filter.cb_$varname set $defval
        pack $w.filter.cb_$varname -side left -padx {0 4}
    }
    # Load departments dynamically
    $w.filter.cb_fha_dept configure -values [loadTimetableDepartments]

    button $w.filter.load -text "Load Periods" -width 12 \
        -command {loadFacultyHourSlots}
    pack $w.filter.load -side left -padx 10

    # ── Assignment panel: left = slot list, right = assign form ──────────────
    frame $w.main -bg white
    pack  $w.main -fill both -expand 1 -padx 14 -pady 6

    # Left: period/slot list
    frame $w.main.left -bg white
    pack  $w.main.left -side left -fill both -expand 1

    label $w.main.left.lbl \
        -text "Periods / Slots  (click a row to assign faculty)" \
        -bg white -font {Arial 10 bold} -anchor w
    pack $w.main.left.lbl -anchor w -pady {0 4}

    frame $w.main.left.tblframe -bg white
    pack  $w.main.left.tblframe -fill both -expand 1

    set cols {SlotID Day Period Time Subject CurrentFaculty Type}
    ttk::style configure FHA.Treeview -font {Arial 10} -rowheight 26
    ttk::style configure FHA.Treeview.Heading \
        -font {Arial 10 bold} -background "#1565C0" -foreground white

    ttk::treeview $w.main.left.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style FHA.Treeview \
        -yscrollcommand "$w.main.left.tblframe.ys set"

    scrollbar $w.main.left.tblframe.ys -orient vertical \
        -command "$w.main.left.tblframe.tree yview"

    foreach {col txt cw anchor} {
        SlotID         "ID"              45  center
        Day            "Day"             85  center
        Period         "Period"          55  center
        Time           "Time"            75  center
        Subject        "Subject"        170  w
        CurrentFaculty "Assigned Faculty" 160 w
        Type           "Type"            55  center
    } {
        $w.main.left.tblframe.tree heading $col -text $txt
        $w.main.left.tblframe.tree column  $col -width $cw -anchor $anchor
    }

    $w.main.left.tblframe.tree tag configure assigned   -background "#E8F5E9"
    $w.main.left.tblframe.tree tag configure unassigned -background "#FFF3E0"
    $w.main.left.tblframe.tree tag configure brk        -background "#F1F5F9"

    grid $w.main.left.tblframe.tree -row 0 -column 0 -sticky nsew
    grid $w.main.left.tblframe.ys   -row 0 -column 1 -sticky ns
    grid rowconfigure    $w.main.left.tblframe 0 -weight 1
    grid columnconfigure $w.main.left.tblframe 0 -weight 1

    # When a row is selected → populate the right panel
    bind $w.main.left.tblframe.tree <<TreeviewSelect>> {fillFacultyAssignPanel}

    # Right: assign form
    frame $w.main.right -bg "#F8FBFF" -relief solid -bd 1 -width 260
    pack  $w.main.right -side right -fill y -padx {10 0}
    pack propagate $w.main.right 0

    label $w.main.right.title \
        -text "Assign Faculty" \
        -font {Arial 12 bold} -bg "#F8FBFF" -anchor w
    pack $w.main.right.title -padx 14 -pady {14 6} -anchor w

    label $w.main.right.slotlbl \
        -text "Selected slot:" \
        -font {Arial 9} -bg "#F8FBFF" -fg "#64748B" -anchor w
    pack $w.main.right.slotlbl -padx 14 -anchor w

    label $w.main.right.slotinfo \
        -text "— none —" \
        -font {Arial 10 bold} -bg "#F8FBFF" -fg "#0F4C81" \
        -anchor w -wraplength 220 -justify left
    pack $w.main.right.slotinfo -padx 14 -pady {2 12} -anchor w

    label $w.main.right.faclbl \
        -text "Faculty Member :" \
        -font {Arial 10 bold} -bg "#F8FBFF" -anchor w
    pack $w.main.right.faclbl -padx 14 -anchor w

    ttk::combobox $w.main.right.faculty \
        -values [loadEditorFacultyList] -width 28
    pack $w.main.right.faculty -padx 14 -pady {4 14} -anchor w

    button $w.main.right.assign \
        -text "Assign to This Hour" -width 22 \
        -command {assignFacultyToSelectedSlot}
    pack $w.main.right.assign -padx 14 -pady 4

    button $w.main.right.clear \
        -text "Clear Assignment" -width 22 \
        -command {clearFacultyFromSelectedSlot}
    pack $w.main.right.clear -padx 14 -pady 4

    # Status
    frame $w.statusbar -bg "#F1F5F9" -relief solid -bd 1
    pack  $w.statusbar -fill x -padx 14 -pady 6
    label $w.statusbar.txt \
        -text "Load periods, then select a row and assign a faculty member." \
        -font {Arial 9} -bg "#F1F5F9" -fg "#475569" -anchor w
    pack $w.statusbar.txt -padx 10 -pady 4 -anchor w

    frame $w.closebar -bg white
    pack  $w.closebar -pady 6
    button $w.closebar.close -text "Close" -width 12 \
        -command [list destroy $w]
    pack $w.closebar.close

    applyThemeToWindow $w
    catch { ttk::style configure FHA.Treeview.Heading -background "#1565C0" -foreground white }
}

proc loadFacultyHourSlots {} {
    global db
    set w .fhassign
    if {![winfo exists $w.main.left.tblframe.tree]} { return }

    set dept    [string trim [$w.filter.cb_fha_dept get]]
    set year    [string trim [$w.filter.cb_fha_year get]]
    set sem     [string trim [$w.filter.cb_fha_sem  get]]
    set section [string trim [$w.filter.cb_fha_sect get]]

    if {$dept eq "" || $sem eq ""} {
        fhaStatus "Select Department and Semester first."
        return
    }

    $w.main.left.tblframe.tree delete [$w.main.left.tblframe.tree children {}]

    set escDept [string map {"'" "''"} $dept]
    set escYear [string map {"'" "''"} $year]
    set escSect [string map {"'" "''"} $section]

    set sql "SELECT ts.slot_id, ts.day_of_week, ts.period_number,
                    ts.start_time, ts.subject_name,
                    COALESCE(ts.staff_name,'') AS staff_name,
                    ts.slot_type
             FROM timetable_slots ts
             JOIN timetables t ON t.timetable_id = ts.timetable_id
             WHERE t.semester = $sem
               AND t.year = '$escYear'
               AND t.section = '$escSect'
               AND (t.department = '$escDept'
                    OR t.department IN (SELECT department_name FROM departments WHERE short_name='$escDept')
                    OR t.department IN (SELECT short_name FROM departments WHERE department_name='$escDept'))
               AND ts.slot_type IN ('Class','Lab')
             ORDER BY
               CASE ts.day_of_week
                 WHEN 'Monday' THEN 1 WHEN 'Tuesday'  THEN 2
                 WHEN 'Wednesday' THEN 3 WHEN 'Thursday' THEN 4
                 WHEN 'Friday' THEN 5 ELSE 6 END,
               ts.period_number"

    set count 0
    set unassigned 0
    db eval $sql row {
        set isAssigned [expr {$row(staff_name) ne "" && $row(staff_name) ne "Not Assigned"}]
        set tag [expr {$isAssigned ? "assigned" : "unassigned"}]
        $w.main.left.tblframe.tree insert {} end -values [list \
            $row(slot_id) $row(day_of_week) $row(period_number) \
            $row(start_time) $row(subject_name) $row(staff_name) \
            $row(slot_type)] -tags $tag
        incr count
        if {!$isAssigned} { incr unassigned }
    }

    fhaStatus "Loaded $count period(s). Unassigned: $unassigned  |  Green = assigned, Amber = needs faculty."
}

proc fillFacultyAssignPanel {} {
    set w .fhassign
    if {![winfo exists $w.main.left.tblframe.tree]} { return }
    set sel [$w.main.left.tblframe.tree selection]
    if {$sel eq ""} { return }
    set vals [$w.main.left.tblframe.tree item $sel -values]
    lassign $vals slotId day period time subject faculty stype

    $w.main.right.slotinfo configure \
        -text "$day  |  Period $period  ($time)\n$subject"
    $w.main.right.faculty set $faculty
}

proc assignFacultyToSelectedSlot {} {
    global db currentUser
    if {![requireEditTimetablePermission]} { return }

    set w .fhassign
    set sel [$w.main.left.tblframe.tree selection]
    if {$sel eq ""} {
        fhaStatus "Select a period row first."
        return
    }
    set vals [$w.main.left.tblframe.tree item $sel -values]
    lassign $vals slotId day period time subject oldFaculty stype

    set newFaculty [string trim [$w.main.right.faculty get]]
    if {$newFaculty eq ""} {
        fhaStatus "Choose a faculty member from the dropdown."
        return
    }

    # Conflict check — faculty assigned elsewhere at same day/period
    set conflict [validateSlotConflicts "" $day $period $stype \
        $subject $newFaculty "" "" "" $slotId]
    if {$conflict ne ""} {
        fhaStatus "Conflict: $conflict"
        return
    }

    set escFac  [string map {"'" "''"} $newFaculty]
    set escUser [string map {"'" "''"} $currentUser]

    if {[catch {
        db eval "UPDATE timetable_slots
                 SET staff_name='$escFac', modified_by='$escUser'
                 WHERE slot_id = $slotId"
    } err]} {
        fhaStatus "DB Error: $err"
        return
    }

    # Update the treeview row in place
    $w.main.left.tblframe.tree item $sel \
        -values [list $slotId $day $period $time $subject $newFaculty $stype] \
        -tags assigned

    fhaStatus "Period $period on $day → assigned to \"$newFaculty\" successfully."
}

proc clearFacultyFromSelectedSlot {} {
    global db currentUser
    if {![requireEditTimetablePermission]} { return }

    set w .fhassign
    set sel [$w.main.left.tblframe.tree selection]
    if {$sel eq ""} { fhaStatus "Select a period row first." ; return }

    set vals [$w.main.left.tblframe.tree item $sel -values]
    lassign $vals slotId day period time subject oldFaculty stype

    set confirm [tk_messageBox -title "Clear Assignment" \
        -message "Remove faculty \"$oldFaculty\" from\n$day  Period $period  —  $subject?" \
        -icon question -type yesno]
    if {$confirm ne "yes"} { return }

    set escUser [string map {"'" "''"} $currentUser]
    if {[catch {
        db eval "UPDATE timetable_slots
                 SET staff_name='Not Assigned', modified_by='$escUser'
                 WHERE slot_id = $slotId"
    } err]} {
        fhaStatus "DB Error: $err"
        return
    }

    $w.main.left.tblframe.tree item $sel \
        -values [list $slotId $day $period $time $subject "Not Assigned" $stype] \
        -tags unassigned
    $w.main.right.faculty set ""
    fhaStatus "Faculty cleared from Period $period on $day."
}

proc fhaStatus {msg} {
    if {[winfo exists .fhassign.statusbar.txt]} {
        .fhassign.statusbar.txt configure -text $msg
    }
}
