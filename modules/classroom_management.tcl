proc openClassroomManagement {} {
    global editingClassroomId
    set editingClassroomId ""

    if {[winfo exists .classroom]} {
        raise .classroom
        return
    }

    toplevel .classroom
    wm title .classroom "Classroom Management"
    wm geometry .classroom "820x560"
    .classroom configure -bg white

    label .classroom.title \
        -text "CLASSROOM MANAGEMENT" \
        -font {Arial 18 bold} \
        -bg "#1565C0" \
        -fg white
    pack .classroom.title -fill x -pady 10

    frame .classroom.form -bg white
    pack .classroom.form -pady 10

    label .classroom.form.l1 -text "Room Number :" -bg white
    grid .classroom.form.l1 -row 0 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e1 -width 20
    grid .classroom.form.e1 -row 0 -column 1 -padx 10 -sticky w

    label .classroom.form.l2 -text "Name / Label :" -bg white
    grid .classroom.form.l2 -row 1 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e2 -width 30
    grid .classroom.form.e2 -row 1 -column 1 -padx 10

    label .classroom.form.l3 -text "Building :" -bg white
    grid .classroom.form.l3 -row 2 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e3 -width 20
    grid .classroom.form.e3 -row 2 -column 1 -padx 10 -sticky w

    label .classroom.form.l4 -text "Capacity :" -bg white
    grid .classroom.form.l4 -row 3 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e4 -width 8
    grid .classroom.form.e4 -row 3 -column 1 -padx 10 -sticky w

    label .classroom.form.l5 -text "Department :" -bg white
    grid .classroom.form.l5 -row 4 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e5 -width 25
    grid .classroom.form.e5 -row 4 -column 1 -padx 10

    label .classroom.form.l6 -text "Lab Location :" -bg white
    grid .classroom.form.l6 -row 5 -column 0 -padx 10 -pady 5 -sticky e
    entry .classroom.form.e6 -width 30
    grid .classroom.form.e6 -row 5 -column 1 -padx 10

    frame .classroom.actions -bg white
    pack .classroom.actions -pady 12

    button .classroom.add \
        -text "Add Classroom" \
        -width 14 \
        -command {addClassroom}
    pack .classroom.add -in .classroom.actions -side left -padx 8

    button .classroom.clear \
        -text "Clear" \
        -width 10 \
        -command {clearClassroomForm}
    pack .classroom.clear -in .classroom.actions -side left -padx 8

    button .classroom.edit \
        -text "Edit Selected" \
        -width 13 \
        -command {editSelectedClassroom}
    pack .classroom.edit -in .classroom.actions -side left -padx 8

    button .classroom.update \
        -text "Update Selected" \
        -width 15 \
        -command {updateSelectedClassroom}
    pack .classroom.update -in .classroom.actions -side left -padx 8

    button .classroom.refresh \
        -text "Refresh" \
        -width 10 \
        -command {refreshClassroomList}
    pack .classroom.refresh -in .classroom.actions -side left -padx 8

    button .classroom.delete \
        -text "Delete Selected" \
        -width 14 \
        -command {deleteSelectedClassroom}
    pack .classroom.delete -in .classroom.actions -side left -padx 8

    button .classroom.close \
        -text "Close" \
        -command {destroy .classroom}
    pack .classroom.close -in .classroom.actions -side left -padx 8

    listbox .classroom.list -width 105 -height 10
    pack .classroom.list -fill both -expand 1 -padx 10 -pady 8

    applyThemeToWindow .classroom
    refreshClassroomList
}

proc clearClassroomForm {} {
    global editingClassroomId
    set editingClassroomId ""
    .classroom.form.e1 delete 0 end
    .classroom.form.e2 delete 0 end
    .classroom.form.e3 delete 0 end
    .classroom.form.e4 delete 0 end
    .classroom.form.e5 delete 0 end
    .classroom.form.e6 delete 0 end
}

proc readClassroomForm {} {
    set room  [string trim [.classroom.form.e1 get]]
    set name  [string trim [.classroom.form.e2 get]]
    set build [string trim [.classroom.form.e3 get]]
    set cap   [string trim [.classroom.form.e4 get]]
    set dept  [string trim [.classroom.form.e5 get]]
    set labLocation [string trim [.classroom.form.e6 get]]

    if {$room eq ""} {
        tk_messageBox -title "Validation Error" -message "Room Number is required." -icon warning
        return "__INVALID__"
    }

    if {$cap eq ""} {
        set cap "NULL"
    } elseif {![string is integer -strict $cap]} {
        tk_messageBox -title "Validation Error" -message "Capacity must be an integer." -icon warning
        return "__INVALID__"
    }

    set escRoom  [string map {"'" "''"} $room]
    set escName  [string map {"'" "''"} $name]
    set escBuild [string map {"'" "''"} $build]
    set escDept  [string map {"'" "''"} $dept]
    set escLab   [string map {"'" "''"} $labLocation]

    return [list $escRoom $escName $escBuild $cap $escDept $escLab]
}

proc addClassroom {} {
    global db

    set values [readClassroomForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values escRoom escName escBuild cap escDept escLab

    set sql "INSERT INTO classrooms (room_number, name, building, capacity, department, lab_location) VALUES ('$escRoom','$escName','$escBuild',$cap,'$escDept','$escLab')"

    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Failed to add classroom:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Classroom added successfully." -icon info
        clearClassroomForm
        refreshClassroomList
    }
}

proc selectedClassroomId {} {
    set sel [.classroom.list curselection]
    if {$sel eq ""} {
        return ""
    }

    set line [.classroom.list get $sel]
    if {[regexp {^([0-9]+) \|} $line -> classroomId]} {
        return $classroomId
    }
    return ""
}

proc editSelectedClassroom {} {
    global db editingClassroomId
    set classroomId [selectedClassroomId]
    if {$classroomId eq ""} {
        tk_messageBox -title "Edit" -message "Select a classroom row." -icon info
        return
    }

    set found 0
    db eval "SELECT room_number, name, building, COALESCE(capacity, '') AS capacity, department, COALESCE(lab_location, '') AS lab_location FROM classrooms WHERE classroom_id = $classroomId" row {
        set found 1
        clearClassroomForm
        set editingClassroomId $classroomId
        .classroom.form.e1 insert 0 $row(room_number)
        .classroom.form.e2 insert 0 $row(name)
        .classroom.form.e3 insert 0 $row(building)
        .classroom.form.e4 insert 0 $row(capacity)
        .classroom.form.e5 insert 0 $row(department)
        .classroom.form.e6 insert 0 $row(lab_location)
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Selected classroom was not found." -icon warning
    }
}

proc updateSelectedClassroom {} {
    global db editingClassroomId
    if {$editingClassroomId eq ""} {
        set editingClassroomId [selectedClassroomId]
    }
    if {$editingClassroomId eq ""} {
        tk_messageBox -title "Update" -message "Select a classroom row, then click Edit Selected." -icon info
        return
    }

    set values [readClassroomForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values escRoom escName escBuild cap escDept escLab

    set sql "UPDATE classrooms SET room_number='$escRoom', name='$escName', building='$escBuild', capacity=$cap, department='$escDept', lab_location='$escLab' WHERE classroom_id = $editingClassroomId"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Could not update classroom:\n$err" -icon error
        return
    }

    tk_messageBox -title "Success" -message "Classroom updated successfully." -icon info
    clearClassroomForm
    refreshClassroomList
}

proc refreshClassroomList {} {
    global db
    if {![winfo exists .classroom.list]} {
        return
    }

    .classroom.list delete 0 end
    db eval {SELECT classroom_id, room_number, name, building, capacity, department, COALESCE(lab_location, '') AS lab_location FROM classrooms ORDER BY department, room_number} row {
        .classroom.list insert end "[format {%d | Room:%s | %s | Building:%s | Capacity:%s | Dept:%s | Lab:%s} $row(classroom_id) $row(room_number) $row(name) $row(building) $row(capacity) $row(department) $row(lab_location)]"
    }
}

proc deleteSelectedClassroom {} {
    global db
    set classroomId [selectedClassroomId]
    if {$classroomId eq ""} {
        tk_messageBox -title "Delete" -message "Select a classroom row." -icon info
        return
    }

    if {[catch {db eval "DELETE FROM classrooms WHERE classroom_id = $classroomId"} err]} {
        tk_messageBox -title "Database Error" -message "Could not delete classroom:\n$err" -icon error
        return
    }

    refreshClassroomList
}
