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

    # ── Treeview ──────────────────────────────────────────────────────────────
    frame .department.tblframe -bg white
    pack  .department.tblframe -fill both -expand 1 -padx 10 -pady 8

    set cols {RowKey Type Name ShortOrYear Extra}
    ttk::style configure Dept.Treeview -font {Arial 10} -rowheight 26
    ttk::style configure Dept.Treeview.Heading \
        -font {Arial 10 bold} -background "#1565C0" -foreground white

    ttk::treeview .department.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style Dept.Treeview \
        -yscrollcommand {.department.tblframe.ys set} \
        -xscrollcommand {.department.tblframe.xs set}

    scrollbar .department.tblframe.ys -orient vertical   -command {.department.tblframe.tree yview}
    scrollbar .department.tblframe.xs -orient horizontal -command {.department.tblframe.tree xview}

    .department.tblframe.tree heading RowKey    -text "ID"
    .department.tblframe.tree heading Type      -text "Type"
    .department.tblframe.tree heading Name      -text "Name"
    .department.tblframe.tree heading ShortOrYear -text "Short / Year"
    .department.tblframe.tree heading Extra     -text "Description / Section"

    .department.tblframe.tree column RowKey      -width 60  -anchor center
    .department.tblframe.tree column Type        -width 90  -anchor center
    .department.tblframe.tree column Name        -width 200 -anchor w
    .department.tblframe.tree column ShortOrYear -width 120 -anchor center
    .department.tblframe.tree column Extra       -width 280 -anchor w

    .department.tblframe.tree tag configure dept -background "#EAF3FC"
    .department.tblframe.tree tag configure sec  -background "#F7FBFF"

    grid .department.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .department.tblframe.ys   -row 0 -column 1 -sticky ns
    grid .department.tblframe.xs   -row 1 -column 0 -sticky ew
    grid rowconfigure    .department.tblframe 0 -weight 1
    grid columnconfigure .department.tblframe 0 -weight 1

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
    if {![winfo exists .department.tblframe.tree]} { return {} }
    set sel [.department.tblframe.tree selection]
    if {$sel eq ""} { return {} }
    set values [.department.tblframe.tree item $sel -values]
    set rowKey [lindex $values 0]   ;# e.g. "D:3" or "S:7"
    if {[regexp {^D:([0-9]+)$} $rowKey -> id]} { return [list D $id] }
    if {[regexp {^S:([0-9]+)$} $rowKey -> id]} { return [list S $id] }
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
    if {![winfo exists .department.tblframe.tree]} { return }
    .department.tblframe.tree delete [.department.tblframe.tree children {}]

    db eval {SELECT department_id, department_name, short_name, description
             FROM departments ORDER BY department_name} row {
        .department.tblframe.tree insert {} end \
            -values [list "D:$row(department_id)" "Department" \
                $row(department_name) $row(short_name) $row(description)] \
            -tags dept
    }
    db eval {SELECT section_id, department, year, section_name
             FROM sections ORDER BY department, year, section_name} row {
        .department.tblframe.tree insert {} end \
            -values [list "S:$row(section_id)" "Section" \
                $row(department) $row(year) "Section $row(section_name)"] \
            -tags sec
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
        resetTableSequence departments department_id
    } elseif {$type eq "S"} {
        db eval "DELETE FROM sections WHERE section_id = $id"
        resetTableSequence sections section_id
    } else {
        return
    }
    refreshDepartmentCombos
    refreshDepartmentList
}
