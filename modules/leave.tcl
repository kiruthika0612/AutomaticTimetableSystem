# ─────────────────────────────────────────────────────────────────────────────
#  Faculty Leave Management Module
#  - Uses loadLeaveFacultyOptions (private, avoids conflict with subject module)
#  - ttk::treeview table (replaces listbox)
#  - Delete confirmation dialog
# ─────────────────────────────────────────────────────────────────────────────

# Private helper — format: "ID | Name" used only inside leave module
proc loadLeaveFacultyOptions {} {
    global db
    set options {}
    db eval {SELECT faculty_id, faculty_name FROM faculty ORDER BY faculty_name} row {
        lappend options "$row(faculty_id) | $row(faculty_name)"
    }
    return $options
}

proc openLeaveManagement {} {
    global editingLeaveId
    set editingLeaveId ""

    if {[winfo exists .leave]} { raise .leave ; return }

    toplevel .leave
    wm title .leave "Faculty Leave Management"
    wm geometry .leave "800x520"
    .leave configure -bg white

    label .leave.title -text "FACULTY LEAVE MANAGEMENT" \
        -font {Arial 18 bold} -bg "#1565C0" -fg white
    pack .leave.title -fill x -pady 10

    # ── Form ─────────────────────────────────────────────────────────────────
    frame .leave.form -bg white
    pack  .leave.form -pady 10

    label .leave.form.l1 -text "Faculty :" -bg white
    grid  .leave.form.l1 -row 0 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .leave.form.faculty \
        -values [loadLeaveFacultyOptions] -width 38
    grid  .leave.form.faculty -row 0 -column 1 -padx 10 -sticky w

    label .leave.form.l2 -text "Date (YYYY-MM-DD) :" -bg white
    grid  .leave.form.l2 -row 1 -column 0 -padx 10 -pady 5 -sticky e
    entry .leave.form.date -width 16
    grid  .leave.form.date -row 1 -column 1 -padx 10 -sticky w

    label .leave.form.l3 -text "Reason :" -bg white
    grid  .leave.form.l3 -row 2 -column 0 -padx 10 -pady 5 -sticky e
    entry .leave.form.reason -width 42
    grid  .leave.form.reason -row 2 -column 1 -padx 10 -sticky w

    # ── Buttons ───────────────────────────────────────────────────────────────
    frame .leave.actions -bg white
    pack  .leave.actions -pady 8

    button .leave.add    -text "Add Leave"       -width 12 -command {addLeave}
    button .leave.edit   -text "Edit Selected"   -width 13 -command {editSelectedLeave}
    button .leave.update -text "Update Selected" -width 15 -command {updateSelectedLeave}
    button .leave.refresh -text "Refresh"        -width 10 -command {refreshLeaveList}
    button .leave.delete -text "Delete Selected" -width 14 -command {deleteSelectedLeave}
    button .leave.close  -text "Close"           -width 10 -command {destroy .leave}

    foreach btn {.leave.add .leave.edit .leave.update .leave.refresh
                 .leave.delete .leave.close} {
        pack $btn -in .leave.actions -side left -padx 5
    }

    # ── Treeview ──────────────────────────────────────────────────────────────
    frame .leave.tblframe -bg white
    pack  .leave.tblframe -fill both -expand 1 -padx 10 -pady 8

    set cols {LeaveID FacultyName Date Reason}
    ttk::style configure Leave.Treeview -font {Arial 10} -rowheight 26
    ttk::style configure Leave.Treeview.Heading \
        -font {Arial 10 bold} -background "#1565C0" -foreground white

    ttk::treeview .leave.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style Leave.Treeview \
        -yscrollcommand {.leave.tblframe.ys set} \
        -xscrollcommand {.leave.tblframe.xs set}

    scrollbar .leave.tblframe.ys -orient vertical   -command {.leave.tblframe.tree yview}
    scrollbar .leave.tblframe.xs -orient horizontal -command {.leave.tblframe.tree xview}

    .leave.tblframe.tree heading LeaveID     -text "ID"
    .leave.tblframe.tree heading FacultyName -text "Faculty Name"
    .leave.tblframe.tree heading Date        -text "Leave Date"
    .leave.tblframe.tree heading Reason      -text "Reason"

    .leave.tblframe.tree column LeaveID     -width 45  -anchor center
    .leave.tblframe.tree column FacultyName -width 200 -anchor w
    .leave.tblframe.tree column Date        -width 110 -anchor center
    .leave.tblframe.tree column Reason      -width 380 -anchor w

    .leave.tblframe.tree tag configure odd  -background "#F7FBFF"
    .leave.tblframe.tree tag configure even -background "#EAF3FC"

    grid .leave.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .leave.tblframe.ys   -row 0 -column 1 -sticky ns
    grid .leave.tblframe.xs   -row 1 -column 0 -sticky ew
    grid rowconfigure    .leave.tblframe 0 -weight 1
    grid columnconfigure .leave.tblframe 0 -weight 1

    applyThemeToWindow .leave
    refreshLeaveList
}

# ── Form helpers ──────────────────────────────────────────────────────────────

proc clearLeaveForm {} {
    global editingLeaveId
    set editingLeaveId ""
    .leave.form.faculty set ""
    .leave.form.date    delete 0 end
    .leave.form.reason  delete 0 end
}

proc readLeaveForm {} {
    set faculty [string trim [.leave.form.faculty get]]
    set date    [string trim [.leave.form.date    get]]
    set reason  [string trim [.leave.form.reason  get]]

    if {$faculty eq "" || $date eq ""} {
        tk_messageBox -title "Validation" \
            -message "Faculty and date are required." -icon warning
        return "__INVALID__"
    }
    if {![regexp {^([0-9]+) \| (.+)$} $faculty -> facultyId facultyName]} {
        tk_messageBox -title "Validation" \
            -message "Select a faculty from the dropdown." -icon warning
        return "__INVALID__"
    }
    if {![regexp {^\d{4}-\d{2}-\d{2}$} $date]} {
        tk_messageBox -title "Validation" \
            -message "Date must be in YYYY-MM-DD format." -icon warning
        return "__INVALID__"
    }

    return [list $facultyId \
        [string map {"'" "''"} $facultyName] \
        [string map {"'" "''"} $date] \
        [string map {"'" "''"} $reason]]
}

# ── CRUD ──────────────────────────────────────────────────────────────────────

proc addLeave {} {
    global db
    set values [readLeaveForm]
    if {$values eq "__INVALID__"} { return }
    lassign $values facultyId escName escDate escReason

    if {[catch {
        db eval "INSERT INTO leaves(faculty_id, faculty_name, leave_date, reason)
                 VALUES($facultyId,'$escName','$escDate','$escReason')"
    } err]} {
        tk_messageBox -title "Database Error" \
            -message "Could not add leave:\n$err" -icon error
        return
    }
    clearLeaveForm
    refreshLeaveList
}

proc selectedLeaveId {} {
    set sel [.leave.tblframe.tree selection]
    if {$sel eq ""} { return "" }
    return [lindex [.leave.tblframe.tree item $sel -values] 0]
}

proc editSelectedLeave {} {
    global db editingLeaveId
    set lid [selectedLeaveId]
    if {$lid eq ""} {
        tk_messageBox -title "Edit" -message "Select a leave row first." -icon info
        return
    }
    .leave.form.faculty configure -values [loadLeaveFacultyOptions]
    set found 0
    db eval "SELECT faculty_id, faculty_name, leave_date, reason
             FROM leaves WHERE leave_id = $lid" row {
        set found 1
        clearLeaveForm
        set editingLeaveId $lid
        .leave.form.faculty set "$row(faculty_id) | $row(faculty_name)"
        .leave.form.date    insert 0 $row(leave_date)
        .leave.form.reason  insert 0 $row(reason)
    }
    if {!$found} {
        tk_messageBox -title "Edit" \
            -message "Selected leave was not found." -icon warning
    }
}

proc updateSelectedLeave {} {
    global db editingLeaveId
    if {$editingLeaveId eq ""} { set editingLeaveId [selectedLeaveId] }
    if {$editingLeaveId eq ""} {
        tk_messageBox -title "Update" \
            -message "Select a row, then click Edit Selected." -icon info
        return
    }
    set values [readLeaveForm]
    if {$values eq "__INVALID__"} { return }
    lassign $values facultyId escName escDate escReason

    db eval "UPDATE leaves
             SET faculty_id=$facultyId, faculty_name='$escName',
                 leave_date='$escDate', reason='$escReason'
             WHERE leave_id = $editingLeaveId"
    clearLeaveForm
    refreshLeaveList
}

proc deleteSelectedLeave {} {
    global db
    set lid [selectedLeaveId]
    if {$lid eq ""} {
        tk_messageBox -title "Delete" -message "Select a leave row first." -icon info
        return
    }
    set fname ""
    set fdate ""
    db eval "SELECT faculty_name, leave_date FROM leaves WHERE leave_id = $lid" row {
        set fname $row(faculty_name)
        set fdate $row(leave_date)
    }
    set confirm [tk_messageBox -title "Confirm Delete" \
        -message "Delete leave for \"$fname\" on $fdate?" \
        -icon question -type yesno]
    if {$confirm ne "yes"} { return }

    db eval "DELETE FROM leaves WHERE leave_id = $lid"
    resetTableSequence leaves leave_id
    refreshLeaveList
}

proc refreshLeaveList {} {
    global db
    if {![winfo exists .leave.tblframe.tree]} { return }
    .leave.tblframe.tree delete [.leave.tblframe.tree children {}]

    set rowIdx 0
    db eval {SELECT leave_id, faculty_name, leave_date, reason
             FROM leaves ORDER BY leave_date DESC, faculty_name} row {
        set tag [expr {$rowIdx % 2 == 0 ? "even" : "odd"}]
        .leave.tblframe.tree insert {} end -values [list \
            $row(leave_id) $row(faculty_name) \
            $row(leave_date) $row(reason)] -tags $tag
        incr rowIdx
    }
}
