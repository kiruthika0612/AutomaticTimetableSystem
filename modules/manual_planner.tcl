# =============================================================================
#  Manual Timetable Planner
#  Staff see the Day × Period grid and a subject list side-by-side.
#  They click a subject, then click a cell to assign it.
#  When done, click "Save as Timetable" — it writes to DB just like the
#  auto-generator, then shows the result grid.
# =============================================================================

proc openManualPlanner {} {
    if {![requireEditTimetablePermission]} { return }

    # Read values from the generator form
    set sem     [string trim [.timetable.form.e1      get]]
    set year    [string trim [.timetable.form.year    get]]
    set dept    [string trim [.timetable.form.dept    get]]
    set section [string trim [.timetable.form.section get]]
    set notes   [string trim [.timetable.form.e2      get]]

    if {$sem eq "" || $year eq "" || $dept eq ""} {
        tk_messageBox -title "Missing Info" \
            -message "Please select Semester, Year and Department in the generator form first." \
            -icon warning
        return
    }
    if {$section eq ""} { set section "General" }

    # Load periods (teaching slots only — breaks excluded)
    set periods [loadTimetablePeriods $year]
    if {[llength $periods] == 0} {
        tk_messageBox -title "No Periods" \
            -message "No period timings found for $year.\nOpen Settings and add periods first." \
            -icon warning
        return
    }

    # Load subjects
    set subjects [loadTimetableSubjects $sem $dept]
    if {[llength $subjects] == 0} {
        tk_messageBox -title "No Subjects" \
            -message "No subjects found for $dept, semester $sem." \
            -icon warning
        return
    }

    set days {Monday Tuesday Wednesday Thursday Friday}

    # ── Build window ─────────────────────────────────────────────────────────
    set w .manualplanner
    if {[winfo exists $w]} { destroy $w }
    toplevel $w
    wm title $w "Manual Timetable Planner — $dept  Sem $sem  $year  Sec $section"
    wm geometry $w "1300x720"
    $w configure -bg white

    # Header
    label $w.hdr \
        -text "MANUAL TIMETABLE PLANNER  —  $dept  |  Sem $sem  |  $year  |  Section $section" \
        -font {Arial 14 bold} -bg "#1565C0" -fg white -pady 8
    pack $w.hdr -fill x

    # Instruction bar
    frame $w.info -bg "#E3F2FD"
    pack  $w.info -fill x
    label $w.info.txt \
        -text "  1. Click a subject on the LEFT   2. Click a grid cell to assign it   3. Right-click a cell to clear it   4. Click  Save as Timetable  when done  |  Blended subjects are split into Theory + Lab buttons" \
        -font {Arial 9} -bg "#E3F2FD" -fg "#0D47A1" -anchor w
    pack $w.info.txt -pady 5 -anchor w

    # ── Main pane ─────────────────────────────────────────────────────────────
    frame $w.main -bg white
    pack  $w.main -fill both -expand 1 -padx 8 -pady 6

    # ── LEFT: subject palette ─────────────────────────────────────────────────
    frame $w.main.left -bg white -relief groove -bd 1 -width 230
    pack  $w.main.left -side left -fill y -padx {0 6}
    pack propagate $w.main.left 0

    label $w.main.left.hdr -text "Subjects" \
        -font {Arial 11 bold} -bg "#37474F" -fg white -pady 6
    pack $w.main.left.hdr -fill x

    label $w.main.left.hint \
        -text "Click one to select,\nthen click a grid cell.\n\nYellow = Blended Theory\nTeal   = Lab / Blended Lab\nGreen  = Theory" \
        -font {Arial 8} -bg white -fg "#666" -justify left
    pack $w.main.left.hint -pady 4 -padx 8 -anchor w

    # scrollable subject list
    frame $w.main.left.sf -bg white
    pack  $w.main.left.sf -fill both -expand 1

    canvas $w.main.left.sf.c -bg white -highlightthickness 0 \
        -yscrollcommand "$w.main.left.sf.ys set" -width 218
    scrollbar $w.main.left.sf.ys -orient vertical \
        -command "$w.main.left.sf.c yview"
    frame $w.main.left.sf.c.inner -bg white
    $w.main.left.sf.c create window 0 0 -anchor nw \
        -window $w.main.left.sf.c.inner -tags inner
    bind $w.main.left.sf.c.inner <Configure> \
        "$w.main.left.sf.c configure -scrollregion \[$w.main.left.sf.c bbox all\]"
    pack $w.main.left.sf.c  -side left -fill both -expand 1
    pack $w.main.left.sf.ys -side right -fill y

    # Build subject buttons (one per subject × credits repetitions visible as count)
    global mp_selected mp_plan mp_subjects mp_sem mp_year mp_dept mp_section mp_periods mp_days mp_notes mp_clearMode
    set mp_selected ""
    set mp_clearMode 0
    array unset mp_plan
    set mp_sem     $sem
    set mp_year    $year
    set mp_dept    $dept
    set mp_section $section
    set mp_notes   $notes
    set mp_periods $periods
    set mp_days    $days

    # Store subjects as {subjectName facultyName subjectType credits labPeriods}
    set mp_subjects {}
    set palette $w.main.left.sf.c.inner
    set si 0
    foreach subj $subjects {
        lassign $subj sName sCode sDept sCredits _ sType sLabP _ _
        set facName [lindex $subj 4]
        if {$sCredits eq "" || ![string is integer -strict $sCredits]} { set sCredits 3 }
        if {$sLabP   eq "" || ![string is integer -strict $sLabP]}   { set sLabP 3 }

        if {[string equal -nocase $sType "Blended"]} {
            # ── Blended: create TWO separate buttons ─────────────────────────

            # 1. Theory part (yellow header)
            set btnT "$palette.s${si}t"
            button $btnT \
                -text "${sName}\n($facName)\nTheory  Cr:$sCredits" \
                -font {Arial 8} -bg "#FFF9C4" -fg "#5D4037" \
                -width 26 -wraplength 200 -justify left \
                -relief raised -bd 2 -pady 4 \
                -command [list mp_selectSubject $sName $facName "Theory" $sCredits 1 $btnT]
            pack $btnT -fill x -padx 4 -pady 1

            # 2. Lab part (teal header)
            set btnL "$palette.s${si}l"
            button $btnL \
                -text "${sName} Lab\n($facName)\nLab  Periods:$sLabP" \
                -font {Arial 8} -bg "#E0F7FA" -fg "#006064" \
                -width 26 -wraplength 200 -justify left \
                -relief raised -bd 2 -pady 4 \
                -command [list mp_selectSubject "$sName Lab" $facName "Lab" $sCredits $sLabP $btnL]
            pack $btnL -fill x -padx 4 -pady 1

            lappend mp_subjects [list $sName       $facName "Theory" $sCredits 1     $sCode]
            lappend mp_subjects [list "$sName Lab"  $facName "Lab"   $sCredits $sLabP $sCode]

        } else {
            # ── Theory or pure Lab: single button ────────────────────────────
            set bg [expr {[string equal -nocase $sType "Lab"] ? "#E0F7FA" : "#E8F5E9"}]
            set fg [expr {[string equal -nocase $sType "Lab"] ? "#006064" : "#1B5E20"}]

            set btnName "$palette.s$si"
            set dispType $sType
            set dispExtra [expr {[string equal -nocase $sType "Lab"] ? "Periods:$sLabP" : "Cr:$sCredits"}]
            button $btnName \
                -text "$sName\n($facName)\n$dispType  $dispExtra" \
                -font {Arial 8} -bg $bg -fg $fg \
                -width 26 -wraplength 200 -justify left \
                -relief raised -bd 2 -pady 4 \
                -command [list mp_selectSubject $sName $facName $sType $sCredits $sLabP $btnName]
            pack $btnName -fill x -padx 4 -pady 2

            lappend mp_subjects [list $sName $facName $sType $sCredits $sLabP $sCode]
        }

        # Separator line between subjects
        frame $palette.sep$si -bg "#CCCCCC" -height 1
        pack  $palette.sep$si -fill x -padx 4 -pady 1

        incr si
    }

    # ── RIGHT: planning grid ──────────────────────────────────────────────────
    frame $w.main.right -bg white
    pack  $w.main.right -side right -fill both -expand 1

    # Scrollable canvas for the grid
    canvas $w.main.right.c -bg white -highlightthickness 0 \
        -yscrollcommand "$w.main.right.ys set" \
        -xscrollcommand "$w.main.right.xs set"
    scrollbar $w.main.right.ys -orient vertical   -command "$w.main.right.c yview"
    scrollbar $w.main.right.xs -orient horizontal -command "$w.main.right.c xview"

    frame $w.main.right.c.grid -bg white
    $w.main.right.c create window 0 0 -anchor nw \
        -window $w.main.right.c.grid -tags grid
    bind $w.main.right.c.grid <Configure> \
        "$w.main.right.c configure -scrollregion \[$w.main.right.c bbox all\]"

    grid $w.main.right.c  -row 0 -column 0 -sticky nsew
    grid $w.main.right.ys -row 0 -column 1 -sticky ns
    grid $w.main.right.xs -row 1 -column 0 -sticky ew
    grid rowconfigure    $w.main.right 0 -weight 1
    grid columnconfigure $w.main.right 0 -weight 1

    set gridW $w.main.right.c.grid

    # Column headers (Period times)
    label $gridW.corner -text "Day / Period" \
        -font {Arial 10 bold} -bg "#1565C0" -fg white \
        -width 11 -relief solid -bd 1 -pady 10
    grid $gridW.corner -row 0 -column 0 -sticky nsew

    set pIdx 1
    foreach pdata $periods {
        lassign $pdata pNum pStart pEnd
        set pLabel "P$pNum\n$pStart"
        label $gridW.ph_$pIdx \
            -text $pLabel -font {Arial 9 bold} \
            -bg "#1565C0" -fg white -width 16 \
            -relief solid -bd 1 -justify center -pady 6
        grid $gridW.ph_$pIdx -row 0 -column $pIdx -sticky nsew
        incr pIdx
    }

    # Day rows with clickable cells
    set dIdx 1
    foreach day $days {
        label $gridW.dl_$dIdx -text $day \
            -font {Arial 10 bold} -bg "#E3F2FD" -fg "#0D47A1" \
            -width 11 -relief solid -bd 1 -pady 18
        grid $gridW.dl_$dIdx -row $dIdx -column 0 -sticky nsew

        set pIdx 1
        foreach pdata $periods {
            lassign $pdata pNum _ _
            set cname "$gridW.cell_${dIdx}_${pIdx}"
            label $cname -text "" \
                -font {Arial 8} -bg "#F5F5F5" -fg "#111" \
                -width 16 -wraplength 115 -justify center \
                -relief solid -bd 1 -pady 10 -cursor hand2
            grid $cname -row $dIdx -column $pIdx -sticky nsew -padx 1 -pady 1

            # Left-click: assign selected subject
            bind $cname <Button-1> [list mp_assignCell $day $pNum $dIdx $pIdx $gridW]
            # Right-click: clear cell
            bind $cname <Button-3> [list mp_clearCell  $day $pNum $dIdx $pIdx $gridW]

            incr pIdx
        }
        incr dIdx
    }

    # Column sizing
    set totalPCols [expr {[llength $periods] + 1}]
    for {set c 0} {$c < $totalPCols} {incr c} {
        grid columnconfigure $gridW $c -minsize 130 -weight 1
    }
    set totalDRows [expr {[llength $days] + 1}]
    for {set r 0} {$r < $totalDRows} {incr r} {
        grid rowconfigure $gridW $r -minsize 65
    }

    # ── Bottom action bar ──────────────────────────────────────────────────────
    frame $w.btns -bg white -relief groove -bd 1
    pack  $w.btns -fill x -padx 8 -pady 6

    # selected-subject indicator
    label $w.btns.selind \
        -text "Selected:  none  (click a subject on the left)" \
        -font {Arial 10} -bg "#FFFDE7" -fg "#333" \
        -relief solid -bd 1 -pady 4 -padx 10 -anchor w
    pack $w.btns.selind -side left -fill x -expand 1 -padx 6

    button $w.btns.clearcell -text "Clear Cell" -width 12 \
        -bg "#E53935" -fg white -font {Arial 10 bold} \
        -command {mp_activateClearMode}
    pack $w.btns.clearcell -side right -padx 6

    button $w.btns.clear -text "Clear All Cells" -width 14 \
        -command [list mp_clearAll $gridW $days $periods]
    pack $w.btns.clear -side right -padx 6

    button $w.btns.save -text "Save as Timetable" -width 18 \
        -bg "#1565C0" -fg white -font {Arial 10 bold} \
        -command [list mp_saveTimetable $w]
    pack $w.btns.save -side right -padx 6

    button $w.btns.close -text "Cancel" -width 10 \
        -command [list destroy $w]
    pack $w.btns.close -side right -padx 6

    applyThemeToWindow $w
}

# =============================================================================
#  Subject selection — highlight chosen subject button
# =============================================================================
proc mp_selectSubject {sName facName sType credits labPeriods btnName} {
    global mp_selected mp_selectedData mp_clearMode

    # Deactivate clear mode when a subject is picked
    set mp_clearMode 0
    if {[winfo exists .manualplanner.btns.clearcell]} {
        .manualplanner.btns.clearcell configure -relief raised -bg "#E53935"
    }

    # Un-highlight previous button — restore its original colour
    if {$mp_selected ne "" && [winfo exists $mp_selected]} {
        set prevType [lindex $mp_selectedData 2]
        set prevBg [expr {[string equal -nocase $prevType "Lab"] ? "#E0F7FA" : \
                          [string equal -nocase $prevType "Theory"] ? "#FFF9C4" : "#E8F5E9"}]
        # If it was a Theory part of a blended, restore yellow; Lab part → teal
        $mp_selected configure -bg $prevBg -relief raised
    }

    set mp_selected $btnName
    set mp_selectedData [list $sName $facName $sType $credits $labPeriods]
    $btnName configure -bg "#FFE082" -relief sunken

    set typeLabel [expr {$labPeriods > 1 ? "$sType ($labPeriods periods)" : "$sType"}]
    if {[winfo exists .manualplanner.btns.selind]} {
        .manualplanner.btns.selind configure \
            -text "Selected:  $sName  ($facName)  — $typeLabel  Credits: $credits"
    }
}

# =============================================================================
#  Activate "Clear Cell" mode — next cell click will clear that cell
# =============================================================================
proc mp_activateClearMode {} {
    global mp_clearMode mp_selected mp_selectedData

    set mp_clearMode 1

    # Deselect any selected subject
    if {$mp_selected ne "" && [winfo exists $mp_selected]} {
        set prevType [lindex $mp_selectedData 2]
        set prevBg [expr {[string equal -nocase $prevType "Lab"] ? "#E0F7FA" : \
                          [string equal -nocase $prevType "Theory"] ? "#FFF9C4" : "#E8F5E9"}]
        $mp_selected configure -bg $prevBg -relief raised
    }
    set mp_selected ""

    if {[winfo exists .manualplanner.btns.selind]} {
        .manualplanner.btns.selind configure \
            -text "  CLEAR MODE active — click any filled cell to clear it  (click a subject to cancel)"
    }
    if {[winfo exists .manualplanner.btns.clearcell]} {
        .manualplanner.btns.clearcell configure -relief sunken -bg "#B71C1C"
    }
}

# =============================================================================
#  Assign selected subject to a grid cell
# =============================================================================
proc mp_assignCell {day pNum dIdx pIdx gridW} {
    global mp_selected mp_selectedData mp_plan mp_periods mp_days mp_clearMode

    # If clear mode is active — clear this cell instead of assigning
    if {[info exists mp_clearMode] && $mp_clearMode} {
        mp_clearCell $day $pNum $dIdx $pIdx $gridW
        if {[winfo exists .manualplanner.btns.selind]} {
            .manualplanner.btns.selind configure \
                -text "  Cleared: $day  Period $pIdx  — Click another cell or select a subject."
        }
        return
    }

    if {$mp_selected eq "" || ![info exists mp_selectedData]} {
        .manualplanner.btns.selind configure \
            -text "  Click a subject on the LEFT first, then click a cell."
        return
    }

    lassign $mp_selectedData sName facName sType credits labPeriods

    # Lab → fill consecutive periods; Theory → single cell
    if {[string equal -nocase $sType "Lab"]} {
        # Find how many consecutive periods available from pIdx
        set maxP [llength $mp_periods]
        if {$pIdx + $labPeriods - 1 > $maxP} {
            .manualplanner.btns.selind configure \
                -text "  Not enough consecutive periods on $day for lab block ($labPeriods periods needed)."
            return
        }
        # Check they are all free
        for {set i 0} {$i < $labPeriods} {incr i} {
            set checkP [expr {$pIdx + $i}]
            set pdata  [lindex $mp_periods [expr {$checkP - 1}]]
            set pN     [lindex $pdata 0]
            if {[info exists mp_plan($day,$pN)] && $mp_plan($day,$pN) ne ""} {
                .manualplanner.btns.selind configure \
                    -text "  Period [expr {$pIdx+$i}] on $day is already filled. Clear it first."
                return
            }
        }
        # Assign all consecutive
        for {set i 0} {$i < $labPeriods} {incr i} {
            set checkP [expr {$pIdx + $i}]
            set pdata  [lindex $mp_periods [expr {$checkP - 1}]]
            set pN     [lindex $pdata 0]
            set mp_plan($day,$pN) [list $sName $facName "Lab"]
            set cname "$gridW.cell_${dIdx}_${checkP}"
            if {[winfo exists $cname]} {
                $cname configure -text "$sName\n$facName" \
                    -bg "#80DEEA" -fg "#004D40"
            }
        }
        .manualplanner.btns.selind configure \
            -text "  Assigned (Lab):  $sName  →  $day  Periods $pIdx – [expr {$pIdx+$labPeriods-1}]"
    } else {
        # Theory — single cell
        set pdata [lindex $mp_periods [expr {$pIdx - 1}]]
        set pN    [lindex $pdata 0]
        if {[info exists mp_plan($day,$pN)] && $mp_plan($day,$pN) ne ""} {
            .manualplanner.btns.selind configure \
                -text "  Period $pIdx on $day is already filled. Right-click to clear it first."
            return
        }
        set mp_plan($day,$pN) [list $sName $facName "Class"]
        set cname "$gridW.cell_${dIdx}_${pIdx}"
        if {[winfo exists $cname]} {
            $cname configure -text "$sName\n$facName" \
                -bg "#A5D6A7" -fg "#1B5E20"
        }
        .manualplanner.btns.selind configure \
            -text "  Assigned (Theory):  $sName  →  $day  Period $pIdx"
    }
}

# =============================================================================
#  Clear a single cell  (right-click)
# =============================================================================
proc mp_clearCell {day pNum dIdx pIdx gridW} {
    global mp_plan mp_periods
    set pdata [lindex $mp_periods [expr {$pIdx - 1}]]
    set pN    [lindex $pdata 0]
    if {[info exists mp_plan($day,$pN)]} {
        unset mp_plan($day,$pN)
    }
    set cname "$gridW.cell_${dIdx}_${pIdx}"
    if {[winfo exists $cname]} {
        $cname configure -text "" -bg "#F5F5F5" -fg "#111"
    }
}

# =============================================================================
#  Clear all cells
# =============================================================================
proc mp_clearAll {gridW days periods} {
    global mp_plan
    array unset mp_plan
    set dIdx 1
    foreach day $days {
        set pIdx 1
        foreach pdata $periods {
            set cname "$gridW.cell_${dIdx}_${pIdx}"
            if {[winfo exists $cname]} {
                $cname configure -text "" -bg "#F5F5F5" -fg "#111"
            }
            incr pIdx
        }
        incr dIdx
    }
}

# =============================================================================
#  Save the manual plan as a real timetable in the database
# =============================================================================
proc mp_saveTimetable {w} {
    global db mp_plan mp_periods mp_days mp_sem mp_year mp_dept mp_section mp_notes

    if {![requireEditTimetablePermission]} { return }

    if {[array size mp_plan] == 0} {
        tk_messageBox -title "Empty Plan" \
            -message "You have not assigned any subjects to the grid yet.\nPlease fill in at least one cell." \
            -icon warning
        return
    }

    # Confirm
    set ans [tk_messageBox -title "Save Timetable" \
        -message "Save this manual plan as the timetable for:\n$mp_dept  |  Sem $mp_sem  |  $mp_year  |  Section $mp_section\n\nThis will create a new timetable record." \
        -type yesno -icon question]
    if {$ans ne "yes"} { return }

    ensureTimetableTables

    # Create timetable record
    set timetableId [createTimetableRecord $mp_sem $mp_year $mp_dept $mp_section $mp_notes]
    if {$timetableId eq ""} { return }

    # Load classrooms for the dept (round-robin assignment)
    set classrooms [loadTimetableClassrooms $mp_dept]
    set roomIdx 0

    # Write each planned slot
    set inserted 0
    foreach day $mp_days {
        set pIdx 1
        foreach pdata $mp_periods {
            lassign $pdata pNum pStart pEnd
            if {[info exists mp_plan($day,$pNum)]} {
                lassign $mp_plan($day,$pNum) sName facName sType

                # Pick classroom round-robin
                set room ""
                if {[llength $classrooms] > 0} {
                    set room [lindex $classrooms [expr {$roomIdx % [llength $classrooms]}]]
                    incr roomIdx
                }

                set remarks ""
                if {$pEnd ne ""} { set remarks "Ends: $pEnd" }

                insertTimetableSlot $timetableId $day $pNum $sType \
                    $pStart $sName $facName $mp_dept $mp_section $room $remarks
                incr inserted
            }
            incr pIdx
        }
    }

    # Add break slots
    insertBreakSlots $timetableId $mp_year $mp_days

    tk_messageBox -title "Saved" \
        -message "Manual timetable saved successfully!\n$inserted slots created for $mp_dept, Sem $mp_sem, Section $mp_section." \
        -icon info

    # Show in generator window
    global currentTimetableId
    set currentTimetableId $timetableId
    if {[winfo exists .timetable]} {
        showGeneratedTimetable $timetableId
    }

    destroy $w
}
