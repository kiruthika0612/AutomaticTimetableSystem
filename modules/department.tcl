proc openDepartmentManagement {} {
    global editingDepartmentId editingSectionId
    set editingDepartmentId ""
    set editingSectionId ""

    if {[winfo exists .department]} {
        raise .department
        return
    }

    toplevel .department
    wm title .department "Department and Section Management"
    wm geometry .department "760x520"
    .department configure -bg white

    label .department.title -text "DEPARTMENT AND SECTION MANAGEMENT" -font {Arial 16 bold} -bg "#1565C0" -fg white
    pack .department.title -fill x -pady 10

    frame .department.forms -bg white
    pack .department.forms -pady 8 -fill x

    frame .department.forms.dept -bg white
    grid .department.forms.dept -row 0 -column 0 -padx 15 -sticky n

    label .department.forms.dept.title -text "Department" -font {Arial 12 bold} -bg white
    grid .department.forms.dept.title -row 0 -column 0 -columnspan 2 -pady 5
    label .department.forms.dept.l1 -text "Name :" -bg white
    grid .department.forms.dept.l1 -row 1 -column 0 -padx 8 -pady 5 -sticky e
    entry .department.forms.dept.name -width 28
    grid .department.forms.dept.name -row 1 -column 1 -padx 8
    label .department.forms.dept.l2 -text "Short Name :" -bg white
    grid .department.forms.dept.l2 -row 2 -column 0 -padx 8 -pady 5 -sticky e
    entry .department.forms.dept.short -width 14
    grid .department.forms.dept.short -row 2 -column 1 -padx 8 -sticky w
    label .department.forms.dept.l3 -text "Description :" -bg white
    grid .department.forms.dept.l3 -row 3 -column 0 -padx 8 -pady 5 -sticky e
    entry .department.forms.dept.desc -width 28
    grid .department.forms.dept.desc -row 3 -column 1 -padx 8
    button .department.forms.dept.save -text "Add Department" -width 16 -command {addDepartment}
    grid .department.forms.dept.save -row 4 -column 0 -pady 8
    button .department.forms.dept.update -text "Update Department" -width 17 -command {updateSelectedDepartment}
    grid .department.forms.dept.update -row 4 -column 1 -pady 8

    frame .department.forms.sec -bg white
    grid .department.forms.sec -row 0 -column 1 -padx 15 -sticky n

    label .department.forms.sec.title -text "Section" -font {Arial 12 bold} -bg white
    grid .department.forms.sec.title -row 0 -column 0 -columnspan 2 -pady 5
    label .department.forms.sec.l1 -text "Department :" -bg white
    grid .department.forms.sec.l1 -row 1 -column 0 -padx 8 -pady 5 -sticky e
    ttk::combobox .department.forms.sec.dept -values [loadDepartmentNames] -width 25
    grid .department.forms.sec.dept -row 1 -column 1 -padx 8
    label .department.forms.sec.l2 -text "Year :" -bg white
    grid .department.forms.sec.l2 -row 2 -column 0 -padx 8 -pady 5 -sticky e
    ttk::combobox .department.forms.sec.year -values {"1st Year" "2nd Year" "3rd Year" "4th Year"} -width 12
    .department.forms.sec.year set "1st Year"
    grid .department.forms.sec.year -row 2 -column 1 -padx 8 -sticky w
    label .department.forms.sec.l3 -text "Section :" -bg white
    grid .department.forms.sec.l3 -row 3 -column 0 -padx 8 -pady 5 -sticky e
    entry .department.forms.sec.name -width 10
    grid .department.forms.sec.name -row 3 -column 1 -padx 8 -sticky w
    button .department.forms.sec.save -text "Add Section" -width 16 -command {addSection}
    grid .department.forms.sec.save -row 4 -column 0 -pady 8
    button .department.forms.sec.update -text "Update Section" -width 16 -command {updateSelectedSection}
    grid .department.forms.sec.update -row 4 -column 1 -pady 8

    listbox .department.list -width 100 -height 14
    pack .department.list -fill both -expand 1 -padx 10 -pady 8

    frame .department.actions -bg white
    pack .department.actions -pady 6
    button .department.refresh -text "Refresh" -width 12 -command {refreshDepartmentList}
    pack .department.refresh -in .department.actions -side left -padx 5
    button .department.edit -text "Edit Selected" -width 13 -command {editSelectedDepartmentItem}
    pack .department.edit -in .department.actions -side left -padx 5
    button .department.delete -text "Delete Selected" -width 14 -command {deleteSelectedDepartmentItem}
    pack .department.delete -in .department.actions -side left -padx 5
    button .department.close -text "Close" -width 10 -command {destroy .department}
    pack .department.close -in .department.actions -side left -padx 5

    applyThemeToWindow .department
    refreshDepartmentList
}

proc clearDepartmentForm {} {
    global editingDepartmentId
    set editingDepartmentId ""
    .department.forms.dept.name delete 0 end
    .department.forms.dept.short delete 0 end
    .department.forms.dept.desc delete 0 end
}

proc clearSectionForm {} {
    global editingSectionId
    set editingSectionId ""
    .department.forms.sec.dept set ""
    .department.forms.sec.year set "1st Year"
    .department.forms.sec.name delete 0 end
}

proc loadDepartmentNames {} {
    global db
    set names {}
    db eval {SELECT department_name, short_name FROM departments ORDER BY department_name} row {
        set dept $row(department_name)
        if {$row(short_name) ne ""} {
            set dept $row(short_name)
        }
        if {[lsearch -exact $names $dept] < 0} {
            lappend names $dept
        }
    }
    return $names
}

proc refreshDepartmentCombos {} {
    if {[winfo exists .department.forms.sec.dept]} {
        .department.forms.sec.dept configure -values [loadDepartmentNames]
    }
}

proc addDepartment {} {
    global db
    set name [.department.forms.dept.name get]
    set short [.department.forms.dept.short get]
    set desc [.department.forms.dept.desc get]

    if {$name eq ""} {
        tk_messageBox -title "Validation" -message "Department name is required." -icon warning
        return
    }

    set escName [string map {"'" "''"} $name]
    set escShort [string map {"'" "''"} $short]
    set escDesc [string map {"'" "''"} $desc]

    if {[catch {db eval "INSERT INTO departments(department_name, short_name, description) VALUES('$escName', '$escShort', '$escDesc')"} err]} {
        tk_messageBox -title "Database Error" -message "Could not add department:\n$err" -icon error
        return
    }

    clearDepartmentForm
    refreshDepartmentCombos
    refreshDepartmentList
}

proc addSection {} {
    global db
    set dept [.department.forms.sec.dept get]
    set year [.department.forms.sec.year get]
    set section [.department.forms.sec.name get]

    if {$dept eq "" || $section eq ""} {
        tk_messageBox -title "Validation" -message "Department and section are required." -icon warning
        return
    }

    set escDept [string map {"'" "''"} $dept]
    set escYear [string map {"'" "''"} $year]
    set escSection [string map {"'" "''"} $section]

    db eval "INSERT INTO sections(department, year, section_name) VALUES('$escDept', '$escYear', '$escSection')"
    clearSectionForm
    refreshDepartmentList
}

proc selectedDepartmentListItem {} {
    set sel [.department.list curselection]
    if {$sel eq ""} {
        return {}
    }
    set line [.department.list get $sel]
    if {[regexp {^D:([0-9]+)} $line -> id]} {
        return [list D $id]
    }
    if {[regexp {^S:([0-9]+)} $line -> id]} {
        return [list S $id]
    }
    return {}
}

proc editSelectedDepartmentItem {} {
    global db editingDepartmentId editingSectionId
    set item [selectedDepartmentListItem]
    if {[llength $item] == 0} {
        tk_messageBox -title "Edit" -message "Select a department or section row." -icon info
        return
    }

    lassign $item type id
    if {$type eq "D"} {
        set found 0
        db eval "SELECT department_name, short_name, description FROM departments WHERE department_id = $id" row {
            set found 1
            clearDepartmentForm
            set editingDepartmentId $id
            set editingSectionId ""
            .department.forms.dept.name insert 0 $row(department_name)
            .department.forms.dept.short insert 0 $row(short_name)
            .department.forms.dept.desc insert 0 $row(description)
        }
        if {!$found} {
            tk_messageBox -title "Edit" -message "Selected department was not found." -icon warning
        }
    } else {
        set found 0
        db eval "SELECT department, year, section_name FROM sections WHERE section_id = $id" row {
            set found 1
            clearSectionForm
            set editingSectionId $id
            set editingDepartmentId ""
            .department.forms.sec.dept set $row(department)
            .department.forms.sec.year set $row(year)
            .department.forms.sec.name insert 0 $row(section_name)
        }
        if {!$found} {
            tk_messageBox -title "Edit" -message "Selected section was not found." -icon warning
        }
    }
}

proc updateSelectedDepartment {} {
    global db editingDepartmentId
    if {$editingDepartmentId eq ""} {
        set item [selectedDepartmentListItem]
        if {[llength $item] == 2 && [lindex $item 0] eq "D"} {
            set editingDepartmentId [lindex $item 1]
        }
    }
    if {$editingDepartmentId eq ""} {
        tk_messageBox -title "Update" -message "Select a department row, then click Edit Selected." -icon info
        return
    }

    set name [.department.forms.dept.name get]
    set short [.department.forms.dept.short get]
    set desc [.department.forms.dept.desc get]
    if {$name eq ""} {
        tk_messageBox -title "Validation" -message "Department name is required." -icon warning
        return
    }

    set escName [string map {"'" "''"} $name]
    set escShort [string map {"'" "''"} $short]
    set escDesc [string map {"'" "''"} $desc]

    if {[catch {db eval "UPDATE departments SET department_name='$escName', short_name='$escShort', description='$escDesc' WHERE department_id = $editingDepartmentId"} err]} {
        tk_messageBox -title "Database Error" -message "Could not update department:\n$err" -icon error
        return
    }

    clearDepartmentForm
    refreshDepartmentCombos
    refreshDepartmentList
}

proc updateSelectedSection {} {
    global db editingSectionId
    if {$editingSectionId eq ""} {
        set item [selectedDepartmentListItem]
        if {[llength $item] == 2 && [lindex $item 0] eq "S"} {
            set editingSectionId [lindex $item 1]
        }
    }
    if {$editingSectionId eq ""} {
        tk_messageBox -title "Update" -message "Select a section row, then click Edit Selected." -icon info
        return
    }

    set dept [.department.forms.sec.dept get]
    set year [.department.forms.sec.year get]
    set section [.department.forms.sec.name get]
    if {$dept eq "" || $section eq ""} {
        tk_messageBox -title "Validation" -message "Department and section are required." -icon warning
        return
    }

    set escDept [string map {"'" "''"} $dept]
    set escYear [string map {"'" "''"} $year]
    set escSection [string map {"'" "''"} $section]

    db eval "UPDATE sections SET department='$escDept', year='$escYear', section_name='$escSection' WHERE section_id = $editingSectionId"
    clearSectionForm
    refreshDepartmentList
}

proc refreshDepartmentList {} {
    global db
    .department.list delete 0 end
    .department.list insert end "DEPARTMENTS"
    db eval {SELECT department_id, department_name, short_name, description FROM departments ORDER BY department_name} row {
        .department.list insert end "[format {D:%d | %s | %s | %s} $row(department_id) $row(department_name) $row(short_name) $row(description)]"
    }
    .department.list insert end ""
    .department.list insert end "SECTIONS"
    db eval {SELECT section_id, department, year, section_name FROM sections ORDER BY department, year, section_name} row {
        .department.list insert end "[format {S:%d | %s | %s | Section %s} $row(section_id) $row(department) $row(year) $row(section_name)]"
    }
}

proc deleteSelectedDepartmentItem {} {
    global db
    set item [selectedDepartmentListItem]
    if {[llength $item] == 0} {
        tk_messageBox -title "Delete" -message "Select a department or section row." -icon info
        return
    }
    lassign $item type id
    if {$type eq "D"} {
        db eval "DELETE FROM departments WHERE department_id = $id"
    } elseif {$type eq "S"} {
        db eval "DELETE FROM sections WHERE section_id = $id"
    } else {
        return
    }
    refreshDepartmentCombos
    refreshDepartmentList
}
