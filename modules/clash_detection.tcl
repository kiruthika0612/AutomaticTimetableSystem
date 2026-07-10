# ─────────────────────────────────────────────────────────────────────────────
#  Clash Detection Module
#  - Three clash types: Faculty, Classroom, Section
#  - ttk::treeview table (replaces plain text widget)
#  - Filter combobox to show All / Faculty / Classroom / Section clashes
#  - Summary counts in status bar
# ─────────────────────────────────────────────────────────────────────────────

proc openClashDetection {} {
    if {[winfo exists .clash]} { raise .clash ; return }

    toplevel .clash
    wm title .clash "Clash Detection"
    wm geometry .clash "920x560"
    .clash configure -bg white

    label .clash.title -text "CLASH DETECTION" \
        -font {Arial 18 bold} -bg "#1565C0" -fg white
    pack .clash.title -fill x -pady 10

    # ── Controls ──────────────────────────────────────────────────────────────
    frame .clash.controls -bg white
    pack  .clash.controls -pady 8 -fill x -padx 14

    label .clash.controls.lf -text "Show :" -bg white
    pack  .clash.controls.lf -side left

    ttk::combobox .clash.controls.filter \
        -values {"All Clashes" "Faculty Clashes" "Classroom Clashes" "Section Clashes"} \
        -width 22 -state readonly
    .clash.controls.filter set "All Clashes"
    pack .clash.controls.filter -side left -padx 8

    button .clash.controls.check -text "Check Now" -width 14 \
        -command {checkTimetableClashes}
    pack .clash.controls.check -side left -padx 6

    button .clash.controls.export -text "Export to CSV" -width 14 \
        -command {exportClashReport}
    pack .clash.controls.export -side left -padx 6

    button .clash.controls.close -text "Close" -width 10 \
        -command {destroy .clash}
    pack .clash.controls.close -side left -padx 6

    bind .clash.controls.filter <<ComboboxSelected>> { filterClashView }

    # ── Treeview ──────────────────────────────────────────────────────────────
    frame .clash.tblframe -bg white
    pack  .clash.tblframe -fill both -expand 1 -padx 14 -pady 4

    set cols {ClashType Day Period Time Conflicting Count}

    ttk::style configure Clash.Treeview -font {Arial 10} -rowheight 26
    ttk::style configure Clash.Treeview.Heading \
        -font {Arial 10 bold} -background "#DC2626" -foreground white

    ttk::treeview .clash.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style Clash.Treeview \
        -yscrollcommand {.clash.tblframe.ys set} \
        -xscrollcommand {.clash.tblframe.xs set}

    scrollbar .clash.tblframe.ys -orient vertical   -command {.clash.tblframe.tree yview}
    scrollbar .clash.tblframe.xs -orient horizontal -command {.clash.tblframe.tree xview}

    .clash.tblframe.tree heading ClashType   -text "Clash Type"
    .clash.tblframe.tree heading Day         -text "Day"
    .clash.tblframe.tree heading Period      -text "Period"
    .clash.tblframe.tree heading Time        -text "Time"
    .clash.tblframe.tree heading Conflicting -text "Conflicting Item"
    .clash.tblframe.tree heading Count       -text "Count"

    .clash.tblframe.tree column ClashType   -width 120 -anchor center
    .clash.tblframe.tree column Day         -width 90  -anchor center
    .clash.tblframe.tree column Period      -width 60  -anchor center
    .clash.tblframe.tree column Time        -width 80  -anchor center
    .clash.tblframe.tree column Conflicting -width 380 -anchor w
    .clash.tblframe.tree column Count       -width 60  -anchor center

    # Tag colours per clash type
    .clash.tblframe.tree tag configure faculty   -background "#FEE2E2" -foreground "#7F1D1D"
    .clash.tblframe.tree tag configure classroom -background "#FEF3C7" -foreground "#78350F"
    .clash.tblframe.tree tag configure section   -background "#EDE9FE" -foreground "#4C1D95"
    .clash.tblframe.tree tag configure none      -background "#DCFCE7" -foreground "#14532D"

    grid .clash.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .clash.tblframe.ys   -row 0 -column 1 -sticky ns
    grid .clash.tblframe.xs   -row 1 -column 0 -sticky ew
    grid rowconfigure    .clash.tblframe 0 -weight 1
    grid columnconfigure .clash.tblframe 0 -weight 1

    # ── Status bar ────────────────────────────────────────────────────────────
    frame .clash.status -bg "#F1F5F9" -relief solid -bd 1
    pack  .clash.status -fill x -padx 14 -pady 6

    label .clash.status.txt \
        -text "Click 'Check Now' to scan for clashes." \
        -bg "#F1F5F9" -fg "#475569" -font {Arial 9} -anchor w
    pack .clash.status.txt -padx 10 -pady 4 -anchor w

    applyThemeToWindow .clash
    # Override heading background — applyTheme would clobber the red
    catch {
        ttk::style configure Clash.Treeview.Heading \
            -background "#DC2626" -foreground white
    }
    checkTimetableClashes
}

# ── Internal clash data store (list of dicts as flat lists) ──────────────────
# Each entry: {clashType day period time conflicting count}
set ::clashRows {}

proc checkTimetableClashes {} {
    global db
    set ::clashRows {}

    if {![winfo exists .clash.tblframe.tree]} { return }
    .clash.tblframe.tree delete [.clash.tblframe.tree children {}]

    set facultyCount   0
    set classroomCount 0
    set sectionCount   0

    # ── Faculty clashes ───────────────────────────────────────────────────────
    db eval {
        SELECT day_of_week, period_number, start_time, staff_name,
               COUNT(*) AS total
        FROM   timetable_slots
        WHERE  slot_type IN ('Class','Lab')
          AND  staff_name IS NOT NULL
          AND  trim(staff_name) <> ''
          AND  staff_name <> 'Not Assigned'
        GROUP  BY day_of_week, period_number, start_time, staff_name
        HAVING COUNT(*) > 1
        ORDER  BY day_of_week, period_number
    } row {
        lappend ::clashRows [list "Faculty" \
            $row(day_of_week) $row(period_number) $row(start_time) \
            $row(staff_name) $row(total)]
        incr facultyCount
    }

    # ── Classroom clashes ─────────────────────────────────────────────────────
    db eval {
        SELECT day_of_week, period_number, start_time, classroom,
               COUNT(*) AS total
        FROM   timetable_slots
        WHERE  slot_type IN ('Class','Lab')
          AND  classroom IS NOT NULL
          AND  trim(classroom) <> ''
        GROUP  BY day_of_week, period_number, start_time, classroom
        HAVING COUNT(*) > 1
        ORDER  BY day_of_week, period_number
    } row {
        lappend ::clashRows [list "Classroom" \
            $row(day_of_week) $row(period_number) $row(start_time) \
            $row(classroom) $row(total)]
        incr classroomCount
    }

    # ── Section clashes ───────────────────────────────────────────────────────
    db eval {
        SELECT day_of_week, period_number, start_time,
               department || ' / Sec ' || section AS sec_label,
               COUNT(*) AS total
        FROM   timetable_slots
        WHERE  slot_type IN ('Class','Lab')
          AND  department IS NOT NULL AND trim(department) <> ''
          AND  section    IS NOT NULL AND trim(section)    <> ''
        GROUP  BY day_of_week, period_number, start_time, department, section
        HAVING COUNT(*) > 1
        ORDER  BY day_of_week, period_number
    } row {
        lappend ::clashRows [list "Section" \
            $row(day_of_week) $row(period_number) $row(start_time) \
            $row(sec_label) $row(total)]
        incr sectionCount
    }

    # Populate treeview using current filter
    filterClashView

    # Update status bar
    set total [expr {$facultyCount + $classroomCount + $sectionCount}]
    if {$total == 0} {
        set msg "No clashes found.  All clear."
    } else {
        set msg "Found $total clash(es):  \
Faculty: $facultyCount   \
Classroom: $classroomCount   \
Section: $sectionCount"
    }
    if {[winfo exists .clash.status.txt]} {
        .clash.status.txt configure -text $msg
    }
}

proc filterClashView {} {
    if {![winfo exists .clash.tblframe.tree]} { return }
    .clash.tblframe.tree delete [.clash.tblframe.tree children {}]

    set filter "All Clashes"
    if {[winfo exists .clash.controls.filter]} {
        set filter [.clash.controls.filter get]
    }

    if {[llength $::clashRows] == 0} {
        .clash.tblframe.tree insert {} end \
            -values [list "" "" "" "" "No clashes found — timetable is clean." ""] \
            -tags none
        return
    }

    set rowIdx 0
    foreach entry $::clashRows {
        lassign $entry ctype day period time conflicting count

        # Apply filter
        if {$filter eq "Faculty Clashes"   && $ctype ne "Faculty"}   { continue }
        if {$filter eq "Classroom Clashes" && $ctype ne "Classroom"} { continue }
        if {$filter eq "Section Clashes"   && $ctype ne "Section"}   { continue }

        set tag [string tolower $ctype]
        .clash.tblframe.tree insert {} end \
            -values [list $ctype $day $period $time $conflicting $count] \
            -tags $tag
        incr rowIdx
    }

    if {$rowIdx == 0} {
        .clash.tblframe.tree insert {} end \
            -values [list "" "" "" "" "No clashes in this category." ""] \
            -tags none
    }
}

# ── CSV Export ────────────────────────────────────────────────────────────────
proc exportClashReport {} {
    if {[llength $::clashRows] == 0} {
        tk_messageBox -parent .clash -title "Nothing to Export" \
            -message "Run 'Check Now' first, or there are no clashes to export." \
            -icon info
        return
    }

    set savePath [tk_getSaveFile \
        -parent .clash \
        -title  "Save Clash Report As" \
        -initialfile "clash_report.csv" \
        -filetypes {{"CSV Files" {.csv}} {"All Files" *}}]
    if {$savePath eq ""} { return }

    if {[catch {
        set fh [open $savePath w]
        puts $fh "Clash Type,Day,Period,Time,Conflicting Item,Count"
        foreach entry $::clashRows {
            lassign $entry ctype day period time conflicting count
            set line "$ctype,$day,$period,$time,"
            # Quote conflicting field (may contain commas)
            append line "\"[string map {\" \"\"} $conflicting]\""
            append line ",$count"
            puts $fh $line
        }
        close $fh
    } err]} {
        tk_messageBox -parent .clash -title "Export Error" \
            -message "Could not save file:\n$err" -icon error
        return
    }
    tk_messageBox -parent .clash -title "Exported" \
        -message "Clash report saved to:\n$savePath" -icon info
}
