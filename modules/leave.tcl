proc openLeaveManagement {} {
    global editingLeaveId
    set editingLeaveId ""

    if {[winfo exists .leave]} {
        raise .leave
        return
    }

    toplevel .leave
    wm title .leave "Faculty Leave Management"
    wm geometry .leave "640x460"
    .leave configure -bg white

    label .leave.title -text "FACULTY LEAVE MANAGEMENT" -font {Arial 16 bold} -bg "#1565C0" -fg white
    pack .leave.title -fill x -pady 10

    frame .leave.form -bg white
    pack .leave.form -pady 8

    label .leave.form.l1 -text "Faculty :" -bg white
    grid .leave.form.l1 -row 0 -column 0 -padx 8 -pady 5 -sticky e
    ttk::combobox .leave.form.faculty -values [loadFacultyOptions] -width 35
    grid .leave.form.faculty -row 0 -column 1 -padx 8

    label .leave.form.l2 -text "Date (YYYY-MM-DD) :" -bg white
    grid .leave.form.l2 -row 1 -column 0 -padx 8 -pady 5 -sticky e
    entry .leave.form.date -width 16
    grid .leave.form.date -row 1 -column 1 -padx 8 -sticky w

    label .leave.form.l3 -text "Reason :" -bg white
    grid .leave.form.l3 -row 2 -column 0 -padx 8 -pady 5 -sticky e
    entry .leave.form.reason -width 40
    grid .leave.form.reason -row 2 -column 1 -padx 8

    frame .leave.actions -bg white
    pack .leave.actions -pady 8
    button .leave.add -text "Add Leave" -width 12 -command {addLeave}
    pack .leave.add -in .leave.actions -side left -padx 5
    button .leave.edit -text "Edit Selected" -width 13 -command {editSelectedLeave}
    pack .leave.edit -in .leave.actions -side left -padx 5
    button .leave.update -text "Update Selected" -width 15 -command {updateSelectedLeave}
    pack .leave.update -in .leave.actions -side left -padx 5
    button .leave.refresh -text "Refresh" -width 10 -command {refreshLeaveList}
    pack .leave.refresh -in .leave.actions -side left -padx 5
    button .leave.delete -text "Delete Selected" -width 14 -command {deleteSelectedLeave}
    pack .leave.delete -in .leave.actions -side left -padx 5
    button .leave.close -text "Close" -width 10 -command {destroy .leave}
    pack .leave.close -in .leave.actions -side left -padx 5

    listbox .leave.list -width 85 -height 12
    pack .leave.list -fill both -expand 1 -padx 10 -pady 8
    applyThemeToWindow .leave
    refreshLeaveList
}

proc loadFacultyOptions {} {
    global db
    set options {}
    db eval {SELECT faculty_id, faculty_name FROM faculty ORDER BY faculty_name} row {
        lappend options "$row(faculty_id) | $row(faculty_name)"
    }
    return $options
}

proc clearLeaveForm {} {
    global editingLeaveId
    set editingLeaveId ""
    .leave.form.faculty set ""
    .leave.form.date delete 0 end
    .leave.form.reason delete 0 end
}

proc readLeaveForm {} {
    set faculty [string trim [.leave.form.faculty get]]
    set date [string trim [.leave.form.date get]]
    set reason [string trim [.leave.form.reason get]]

    if {$faculty eq "" || $date eq ""} {
        tk_messageBox -title "Validation" -message "Faculty and date are required." -icon warning
        return "__INVALID__"
    }

    if {![regexp {^([0-9]+) \| (.+)$} $faculty -> facultyId facultyName]} {
        tk_messageBox -title "Validation" -message "Select a valid faculty row." -icon warning
        return "__INVALID__"
    }

    set escName [string map {"'" "''"} $facultyName]
    set escDate [string map {"'" "''"} $date]
    set escReason [string map {"'" "''"} $reason]

    return [list $facultyId $escName $escDate $escReason]
}

proc addLeave {} {
    global db
    set values [readLeaveForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values facultyId escName escDate escReason

    db eval "INSERT INTO leaves(faculty_id, faculty_name, leave_date, reason) VALUES($facultyId, '$escName', '$escDate', '$escReason')"
    clearLeaveForm
    refreshLeaveList
}

proc selectedLeaveId {} {
    set sel [.leave.list curselection]
    if {$sel eq ""} {
        return ""
    }
    set line [.leave.list get $sel]
    if {[regexp {^([0-9]+) \|} $line -> leaveId]} {
        return $leaveId
    }
    return ""
}

proc editSelectedLeave {} {
    global db editingLeaveId
    set leaveId [selectedLeaveId]
    if {$leaveId eq ""} {
        tk_messageBox -title "Edit" -message "Select a leave row." -icon info
        return
    }

    .leave.form.faculty configure -values [loadFacultyOptions]
    set found 0
    db eval "SELECT faculty_id, faculty_name, leave_date, reason FROM leaves WHERE leave_id = $leaveId" row {
        set found 1
        clearLeaveForm
        set editingLeaveId $leaveId
        .leave.form.faculty set "$row(faculty_id) | $row(faculty_name)"
        .leave.form.date insert 0 $row(leave_date)
        .leave.form.reason insert 0 $row(reason)
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Selected leave was not found." -icon warning
    }
}

proc updateSelectedLeave {} {
    global db editingLeaveId
    if {$editingLeaveId eq ""} {
        set editingLeaveId [selectedLeaveId]
    }
    if {$editingLeaveId eq ""} {
        tk_messageBox -title "Update" -message "Select a leave row, then click Edit Selected." -icon info
        return
    }

    set values [readLeaveForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values facultyId escName escDate escReason

    db eval "UPDATE leaves SET faculty_id=$facultyId, faculty_name='$escName', leave_date='$escDate', reason='$escReason' WHERE leave_id = $editingLeaveId"
    clearLeaveForm
    refreshLeaveList
}

proc refreshLeaveList {} {
    global db
    .leave.list delete 0 end
    db eval {SELECT leave_id, faculty_name, leave_date, reason FROM leaves ORDER BY leave_date DESC, faculty_name} row {
        .leave.list insert end "[format {%d | %s | %s | %s} $row(leave_id) $row(faculty_name) $row(leave_date) $row(reason)]"
    }
}

proc deleteSelectedLeave {} {
    global db
    set leaveId [selectedLeaveId]
    if {$leaveId eq ""} {
        tk_messageBox -title "Delete" -message "Select a leave row." -icon info
        return
    }
    db eval "DELETE FROM leaves WHERE leave_id = $leaveId"
    refreshLeaveList
}
