proc openFacultyManagement {} {
    global editingFacultyId
    set editingFacultyId ""

    if {[winfo exists .faculty]} {
        raise .faculty
        return
    }

    toplevel .faculty
    wm title .faculty "Faculty Management"
    wm geometry .faculty "820x600"
    .faculty configure -bg white

    label .faculty.title \
        -text "FACULTY MANAGEMENT" \
        -font {Arial 18 bold} \
        -bg "#1565C0" \
        -fg white
    pack .faculty.title -fill x -pady 10

    frame .faculty.form -bg white
    pack .faculty.form -pady 20

    label .faculty.form.l1 -text "Faculty Name :" -bg white
    grid .faculty.form.l1 -row 0 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.e1 -width 30
    grid .faculty.form.e1 -row 0 -column 1 -padx 10

    label .faculty.form.l2 -text "Department :" -bg white
    grid .faculty.form.l2 -row 1 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.e2 -width 30
    grid .faculty.form.e2 -row 1 -column 1 -padx 10

    label .faculty.form.l3 -text "Designation :" -bg white
    grid .faculty.form.l3 -row 2 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.e3 -width 30
    grid .faculty.form.e3 -row 2 -column 1 -padx 10

    label .faculty.form.l4 -text "Email :" -bg white
    grid .faculty.form.l4 -row 3 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.e4 -width 30
    grid .faculty.form.e4 -row 3 -column 1 -padx 10

    label .faculty.form.l5 -text "Phone :" -bg white
    grid .faculty.form.l5 -row 4 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.e5 -width 30
    grid .faculty.form.e5 -row 4 -column 1 -padx 10

    label .faculty.form.l6 -text "Hours Allotted :" -bg white
    grid .faculty.form.l6 -row 5 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.e6 -width 8
    grid .faculty.form.e6 -row 5 -column 1 -padx 10 -sticky w

    frame .faculty.actions -bg white
    pack .faculty.actions -pady 15

    button .faculty.add \
        -text "Add Faculty" \
        -width 15 \
        -command {addFaculty}
    pack .faculty.add -in .faculty.actions -side left -padx 10

    button .faculty.clear \
        -text "Clear" \
        -width 10 \
        -command {clearFacultyForm}
    pack .faculty.clear -in .faculty.actions -side left -padx 10

    button .faculty.edit \
        -text "Edit Selected" \
        -width 13 \
        -command {editSelectedFaculty}
    pack .faculty.edit -in .faculty.actions -side left -padx 10

    button .faculty.update \
        -text "Update Selected" \
        -width 15 \
        -command {updateSelectedFaculty}
    pack .faculty.update -in .faculty.actions -side left -padx 10

    button .faculty.refresh \
        -text "Refresh" \
        -width 10 \
        -command {refreshFacultyList}
    pack .faculty.refresh -in .faculty.actions -side left -padx 10

    button .faculty.delete \
        -text "Delete Selected" \
        -width 14 \
        -command {deleteSelectedFaculty}
    pack .faculty.delete -in .faculty.actions -side left -padx 10

    button .faculty.close \
        -text "Close" \
        -command {destroy .faculty}
    pack .faculty.close -in .faculty.actions -side left -padx 10

    listbox .faculty.list -width 110 -height 12
    pack .faculty.list -fill both -expand 1 -padx 10 -pady 8

    applyThemeToWindow .faculty
    refreshFacultyList
}

proc clearFacultyForm {} {
    global editingFacultyId
    set editingFacultyId ""
    .faculty.form.e1 delete 0 end
    .faculty.form.e2 delete 0 end
    .faculty.form.e3 delete 0 end
    .faculty.form.e4 delete 0 end
    .faculty.form.e5 delete 0 end
    .faculty.form.e6 delete 0 end
}

proc readFacultyForm {} {
    set name [string trim [.faculty.form.e1 get]]
    set dept [string trim [.faculty.form.e2 get]]
    set desig [string trim [.faculty.form.e3 get]]
    set email [string trim [.faculty.form.e4 get]]
    set phone [string trim [.faculty.form.e5 get]]
    set hours [string trim [.faculty.form.e6 get]]

    if {$name eq ""} {
        tk_messageBox -title "Validation Error" -message "Faculty Name is required." -icon warning
        return "__INVALID__"
    }

    if {$hours eq ""} {
        set hours "NULL"
    } elseif {![string is integer -strict $hours]} {
        tk_messageBox -title "Validation Error" -message "Hours Allotted must be a number." -icon warning
        return "__INVALID__"
    }

    set escName [string map {"'" "''"} $name]
    set escDept [string map {"'" "''"} $dept]
    set escDesig [string map {"'" "''"} $desig]
    set escEmail [string map {"'" "''"} $email]
    set escPhone [string map {"'" "''"} $phone]

    return [list $escName $escDept $escDesig $escEmail $escPhone $hours]
}

proc addFaculty {} {
    global db

    set values [readFacultyForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values escName escDept escDesig escEmail escPhone hours

    set sql "INSERT INTO faculty (faculty_name, department, designation, email, phone, hours_allotted) VALUES ('$escName','$escDept','$escDesig','$escEmail','$escPhone',$hours)"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Failed to add faculty:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Faculty added successfully." -icon info
        clearFacultyForm
        refreshFacultyList
    }
}

proc selectedFacultyId {} {
    set sel [.faculty.list curselection]
    if {$sel eq ""} {
        return ""
    }

    set line [.faculty.list get $sel]
    if {[regexp {^([0-9]+) \|} $line -> facultyId]} {
        return $facultyId
    }
    return ""
}

proc editSelectedFaculty {} {
    global db editingFacultyId
    set facultyId [selectedFacultyId]
    if {$facultyId eq ""} {
        tk_messageBox -title "Edit" -message "Select a faculty row." -icon info
        return
    }

    set found 0
    db eval "SELECT faculty_name, department, designation, email, phone, COALESCE(hours_allotted, '') AS hours_allotted FROM faculty WHERE faculty_id = $facultyId" row {
        set found 1
        clearFacultyForm
        set editingFacultyId $facultyId
        .faculty.form.e1 insert 0 $row(faculty_name)
        .faculty.form.e2 insert 0 $row(department)
        .faculty.form.e3 insert 0 $row(designation)
        .faculty.form.e4 insert 0 $row(email)
        .faculty.form.e5 insert 0 $row(phone)
        .faculty.form.e6 insert 0 $row(hours_allotted)
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Selected faculty was not found." -icon warning
    }
}

proc updateSelectedFaculty {} {
    global db editingFacultyId
    if {$editingFacultyId eq ""} {
        set editingFacultyId [selectedFacultyId]
    }
    if {$editingFacultyId eq ""} {
        tk_messageBox -title "Update" -message "Select a faculty row, then click Edit Selected." -icon info
        return
    }

    set values [readFacultyForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values escName escDept escDesig escEmail escPhone hours

    set sql "UPDATE faculty SET faculty_name='$escName', department='$escDept', designation='$escDesig', email='$escEmail', phone='$escPhone', hours_allotted=$hours WHERE faculty_id = $editingFacultyId"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Could not update faculty:\n$err" -icon error
        return
    }

    tk_messageBox -title "Success" -message "Faculty updated successfully." -icon info
    clearFacultyForm
    refreshFacultyList
}

proc refreshFacultyList {} {
    global db
    if {![winfo exists .faculty.list]} {
        return
    }

    .faculty.list delete 0 end
    db eval {SELECT faculty_id, faculty_name, department, designation, email, phone, COALESCE(hours_allotted, '') AS hours_allotted FROM faculty ORDER BY department, faculty_name} row {
        .faculty.list insert end "[format {%d | %s | Dept:%s | %s | %s | %s | Hours:%s} $row(faculty_id) $row(faculty_name) $row(department) $row(designation) $row(email) $row(phone) $row(hours_allotted)]"
    }
}

proc deleteSelectedFaculty {} {
    global db
    set facultyId [selectedFacultyId]
    if {$facultyId eq ""} {
        tk_messageBox -title "Delete" -message "Select a faculty row." -icon info
        return
    }

    if {[catch {db eval "DELETE FROM faculty WHERE faculty_id = $facultyId"} err]} {
        tk_messageBox -title "Database Error" -message "Could not delete faculty:\n$err" -icon error
        return
    }

    refreshFacultyList
}
