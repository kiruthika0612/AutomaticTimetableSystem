# ─────────────────────────────────────────────────────────────────────────────
#  Classroom Management Module
#  - Department field: combobox loaded from departments table
#  - ttk::treeview table (replaces listbox)
#  - Delete confirmation dialog
# ─────────────────────────────────────────────────────────────────────────────

proc loadClassroomDepartmentOptions {} {
    global db
    set names {}
    db eval {SELECT department_name, short_name FROM departments ORDER BY department_name} row {
        set label $row(department_name)
        if {$row(short_name) ne ""} { set label $row(short_name) }
        if {[lsearch -exact $names $label] < 0} { lappend names $label }
    }
    # also include "Shared / Common" option
    if {[lsearch -exact $names "Shared"] < 0} { lappend names "Shared" }
    return $names
}

proc openClassroomManagement {} {
    global editingClassroomId
    set editingClassroomId ""

    if {[winfo exists .classroom]} { raise .classroom ; return }

    toplevel .classroom
    wm title .classroom "Classroom Management"
    wm geometry .classroom "980x580"
    .classroom configure -bg white

    label .classroom.title -text "CLASSROOM MANAGEMENT" \
        -font {Arial 18 bold} -bg "#1565C0" -fg white
    pack .classroom.title -fill x -pady 10

    # ── Form ─────────────────────────────────────────────────────────────────
    frame .classroom.form -bg white
    pack  .classroom.form -pady 10

    label .classroom.form.l1 -text "Room Number :" -bg white
    grid  .classroom.form.l1 -row 0 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e1 -width 20
    grid  .classroom.form.e1 -row 0 -column 1 -padx 10 -sticky w

    label .classroom.form.l2 -text "Name / Label :" -bg white
    grid  .classroom.form.l2 -row 1 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e2 -width 30
    grid  .classroom.form.e2 -row 1 -column 1 -padx 10 -sticky w

    label .classroom.form.l3 -text "Building :" -bg white
    grid  .classroom.form.l3 -row 2 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e3 -width 20
    grid  .classroom.form.e3 -row 2 -column 1 -padx 10 -sticky w

    label .classroom.form.l4 -text "Capacity :" -bg white
    grid  .classroom.form.l4 -row 3 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e4 -width 8
    grid  .classroom.form.e4 -row 3 -column 1 -padx 10 -sticky w

    # Department: combobox from departments table
    label .classroom.form.l5 -text "Department :" -bg white
    grid  .classroom.form.l5 -row 4 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .classroom.form.dept \
        -values [loadClassroomDepartmentOptions] -width 28
    grid  .classroom.form.dept -row 4 -column 1 -padx 10 -sticky w

    label .classroom.form.l6 -text "Lab Location :" -bg white
    grid  .classroom.form.l6 -row 5 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e6 -width 30
    grid  .classroom.form.e6 -row 5 -column 1 -padx 10 -sticky w

    # ── Buttons ───────────────────────────────────────────────────────────────
    frame .classroom.actions -bg white
    pack  .classroom.actions -pady 10

    button .classroom.add     -text "Add Classroom"    -width 14 -command {addClassroom}
    button .classroom.clear   -text "Clear"            -width 10 -command {clearClassroomForm}
    button .classroom.edit    -text "Edit Selected"    -width 13 -command {editSelectedClassroom}
    button .classroom.update  -text "Update Selected"  -width 15 -command {updateSelectedClassroom}
    button .classroom.refresh -text "Refresh"          -width 10 -command {refreshClassroomList}
    button .classroom.delete  -text "Delete Selected"  -width 14 -command {deleteSelectedClassroom}
    button .classroom.close   -text "Close"                       -command {destroy .classroom}

    foreach btn {.classroom.add .classroom.clear .classroom.edit .classroom.update
                 .classroom.refresh .classroom.delete .classroom.close} {
        pack $btn -in .classroom.actions -side left -padx 6
    }

    # ── Treeview ──────────────────────────────────────────────────────────────
    frame .classroom.tblframe -bg white
    pack  .classroom.tblframe -fill both -expand 1 -padx 10 -pady 8

    set cols {ClassroomID RoomNumber Name Building Capacity Department LabLocation}
    ttk::style configure Classroom.Treeview -font {Arial 10} -rowheight 26
    ttk::style configure Classroom.Treeview.Heading \
        -font {Arial 10 bold} -background "#1565C0" -foreground white

    ttk::treeview .classroom.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style Classroom.Treeview \
        -yscrollcommand {.classroom.tblframe.ys set} \
        -xscrollcommand {.classroom.tblframe.xs set}

    scrollbar .classroom.tblframe.ys -orient vertical   -command {.classroom.tblframe.tree yview}
    scrollbar .classroom.tblframe.xs -orient horizontal -command {.classroom.tblframe.tree xview}

    .classroom.tblframe.tree heading ClassroomID  -text "ID"
    .classroom.tblframe.tree heading RoomNumber   -text "Room No."
    .classroom.tblframe.tree heading Name         -text "Name / Label"
    .classroom.tblframe.tree heading Building     -text "Building"
    .classroom.tblframe.tree heading Capacity     -text "Capacity"
    .classroom.tblframe.tree heading Department   -text "Department"
    .classroom.tblframe.tree heading LabLocation  -text "Lab Location"

    .classroom.tblframe.tree column ClassroomID  -width 45  -anchor center
    .classroom.tblframe.tree column RoomNumber   -width 90  -anchor w
    .classroom.tblframe.tree column Name         -width 160 -anchor w
    .classroom.tblframe.tree column Building     -width 110 -anchor w
    .classroom.tblframe.tree column Capacity     -width 70  -anchor center
    .classroom.tblframe.tree column Department   -width 130 -anchor w
    .classroom.tblframe.tree column LabLocation  -width 180 -anchor w

    .classroom.tblframe.tree tag configure odd  -background "#F7FBFF"
    .classroom.tblframe.tree tag configure even -background "#EAF3FC"
    .classroom.tblframe.tree tag configure lab  -background "#E8F5E9"

    grid .classroom.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .classroom.tblframe.ys   -row 0 -column 1 -sticky ns
    grid .classroom.tblframe.xs   -row 1 -column 0 -sticky ew
    grid rowconfigure    .classroom.tblframe 0 -weight 1
    grid columnconfigure .classroom.tblframe 0 -weight 1

    applyThemeToWindow .classroom
    refreshClassroomList
}

# ── Form helpers ──────────────────────────────────────────────────────────────

proc clearClassroomForm {} {
    global editingClassroomId
    set editingClassroomId ""
    .classroom.form.e1   delete 0 end
    .classroom.form.e2   delete 0 end
    .classroom.form.e3   delete 0 end
    .classroom.form.e4   delete 0 end
    .classroom.form.dept configure -values [loadClassroomDepartmentOptions]
    .classroom.form.dept set ""
    .classroom.form.e6   delete 0 end
}

proc readClassroomForm {} {
    set room  [string trim [.classroom.form.e1   get]]
    set name  [string trim [.classroom.form.e2   get]]
    set build [string trim [.classroom.form.e3   get]]
    set cap   [string trim [.classroom.form.e4   get]]
    set dept  [string trim [.classroom.form.dept get]]
    set lab   [string trim [.classroom.form.e6   get]]

    if {$room eq ""} {
        tk_messageBox -title "Validation Error" \
            -message "Room Number is required." -icon warning
        return "__INVALID__"
    }
    if {$cap eq ""} {
        set cap "NULL"
    } elseif {![string is integer -strict $cap]} {
        tk_messageBox -title "Validation Error" \
            -message "Capacity must be a whole number." -icon warning
        return "__INVALID__"
    }

    return [list \
        [string map {"'" "''"} $room]  \
        [string map {"'" "''"} $name]  \
        [string map {"'" "''"} $build] \
        $cap \
        [string map {"'" "''"} $dept]  \
        [string map {"'" "''"} $lab]]
}

# ── CRUD ──────────────────────────────────────────────────────────────────────

proc addClassroom {} {
    global db
    set values [readClassroomForm]
    if {$values eq "__INVALID__"} { return }
    lassign $values escRoom escName escBuild cap escDept escLab

    set sql "INSERT INTO classrooms
                 (room_number, name, building, capacity, department, lab_location)
             VALUES ('$escRoom','$escName','$escBuild',$cap,'$escDept','$escLab')"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" \
            -message "Failed to add classroom:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Classroom added successfully." -icon info
        clearClassroomForm
        refreshClassroomList
    }
}

proc selectedClassroomId {} {
    set sel [.classroom.tblframe.tree selection]
    if {$sel eq ""} { return "" }
    return [lindex [.classroom.tblframe.tree item $sel -values] 0]
}

proc editSelectedClassroom {} {
    global db editingClassroomId
    set cid [selectedClassroomId]
    if {$cid eq ""} {
        tk_messageBox -title "Edit" -message "Select a classroom row first." -icon info
        return
    }
    set found 0
    db eval "SELECT room_number, name, building,
                    COALESCE(capacity,'')     AS capacity,
                    COALESCE(department,'')   AS department,
                    COALESCE(lab_location,'') AS lab_location
             FROM classrooms WHERE classroom_id = $cid" row {
        set found 1
        clearClassroomForm
        set editingClassroomId $cid
        .classroom.form.e1   insert 0 $row(room_number)
        .classroom.form.e2   insert 0 $row(name)
        .classroom.form.e3   insert 0 $row(building)
        .classroom.form.e4   insert 0 $row(capacity)
        .classroom.form.dept set      $row(department)
        .classroom.form.e6   insert 0 $row(lab_location)
    }
    if {!$found} {
        tk_messageBox -title "Edit" \
            -message "Selected classroom was not found." -icon warning
    }
}

proc updateSelectedClassroom {} {
    global db editingClassroomId
    if {$editingClassroomId eq ""} { set editingClassroomId [selectedClassroomId] }
    if {$editingClassroomId eq ""} {
        tk_messageBox -title "Update" \
            -message "Select a row, then click Edit Selected." -icon info
        return
    }
    set values [readClassroomForm]
    if {$values eq "__INVALID__"} { return }
    lassign $values escRoom escName escBuild cap escDept escLab

    set sql "UPDATE classrooms
             SET room_number='$escRoom', name='$escName', building='$escBuild',
                 capacity=$cap, department='$escDept', lab_location='$escLab'
             WHERE classroom_id = $editingClassroomId"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" \
            -message "Could not update classroom:\n$err" -icon error
        return
    }
    tk_messageBox -title "Success" -message "Classroom updated successfully." -icon info
    clearClassroomForm
    refreshClassroomList
}

proc deleteSelectedClassroom {} {
    global db
    set cid [selectedClassroomId]
    if {$cid eq ""} {
        tk_messageBox -title "Delete" -message "Select a classroom row first." -icon info
        return
    }
    set rnum ""
    db eval "SELECT room_number FROM classrooms WHERE classroom_id = $cid" row {
        set rnum $row(room_number)
    }
    set confirm [tk_messageBox -title "Confirm Delete" \
        -message "Delete classroom \"$rnum\"?\nThis cannot be undone." \
        -icon question -type yesno]
    if {$confirm ne "yes"} { return }

    if {[catch {db eval "DELETE FROM classrooms WHERE classroom_id = $cid"} err]} {
        tk_messageBox -title "Database Error" \
            -message "Could not delete classroom:\n$err" -icon error
        return
    }
    refreshClassroomList
}

proc refreshClassroomList {} {
    global db
    if {![winfo exists .classroom.tblframe.tree]} { return }
    .classroom.tblframe.tree delete [.classroom.tblframe.tree children {}]

    set rowIdx 0
    db eval {SELECT classroom_id, room_number, name, building,
                    COALESCE(capacity,'')     AS capacity,
                    COALESCE(department,'')   AS department,
                    COALESCE(lab_location,'') AS lab_location
             FROM classrooms ORDER BY department, room_number} row {
        set tag [expr {$rowIdx % 2 == 0 ? "even" : "odd"}]
        if {$row(lab_location) ne ""} { set tag "lab" }
        .classroom.tblframe.tree insert {} end -values [list \
            $row(classroom_id) $row(room_number) $row(name) \
            $row(building) $row(capacity) $row(department) \
            $row(lab_location)] -tags $tag
        incr rowIdx
    }
}
