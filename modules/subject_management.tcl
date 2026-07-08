proc openSubjectManagement {} {
    global editingSubjectId
    set editingSubjectId ""

    if {[winfo exists .subject]} {
        raise .subject
        return
    }

    toplevel .subject
    wm title .subject "Subject Management"
    wm geometry .subject "820x620"
    .subject configure -bg white

    label .subject.title \
        -text "SUBJECT MANAGEMENT" \
        -font {Arial 18 bold} \
        -bg "#1565C0" \
        -fg white
    pack .subject.title -fill x -pady 10

    frame .subject.form -bg white
    pack .subject.form -pady 12

    label .subject.form.l1 -text "Subject Name :" -bg white
    grid .subject.form.l1 -row 0 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.e1 -width 30
    grid .subject.form.e1 -row 0 -column 1 -padx 10

    label .subject.form.l2 -text "Subject Code :" -bg white
    grid .subject.form.l2 -row 1 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.e2 -width 20
    grid .subject.form.e2 -row 1 -column 1 -padx 10 -sticky w

    label .subject.form.l3 -text "Department :" -bg white
    grid .subject.form.l3 -row 2 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.e3 -values [loadSubjectDepartmentOptions] -width 28 -state readonly
    grid .subject.form.e3 -row 2 -column 1 -padx 10

    label .subject.form.l4 -text "Credits :" -bg white
    grid .subject.form.l4 -row 3 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.e4 -values {1 2 3 4 5 6} -width 8 -state readonly
    .subject.form.e4 set "3"
    grid .subject.form.e4 -row 3 -column 1 -padx 10 -sticky w

    label .subject.form.l5 -text "Semester :" -bg white
    grid .subject.form.l5 -row 4 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.e5 -values {1 2 3 4 5 6 7 8} -width 8 -state readonly
    grid .subject.form.e5 -row 4 -column 1 -padx 10 -sticky w

    label .subject.form.l6 -text "Assigned Faculty ID :" -bg white
    grid .subject.form.l6 -row 5 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.e6 -width 12
    grid .subject.form.e6 -row 5 -column 1 -padx 10 -sticky w

    label .subject.form.l7 -text "Subject Type :" -bg white
    grid .subject.form.l7 -row 6 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.type -values {"Theory" "Lab" "Blended"} -width 12 -state readonly
    .subject.form.type set "Theory"
    grid .subject.form.type -row 6 -column 1 -padx 10 -sticky w

    label .subject.form.l8 -text "Lab Periods :" -bg white
    grid .subject.form.l8 -row 7 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.lab -width 8
    .subject.form.lab insert 0 "3"
    grid .subject.form.lab -row 7 -column 1 -padx 10 -sticky w

    frame .subject.actions -bg white
    pack .subject.actions -pady 12

    button .subject.add \
        -text "Add Subject" \
        -width 14 \
        -command {addSubject}
    pack .subject.add -in .subject.actions -side left -padx 8

    button .subject.clear \
        -text "Clear" \
        -width 10 \
        -command {clearSubjectForm}
    pack .subject.clear -in .subject.actions -side left -padx 8

    button .subject.edit \
        -text "Edit Selected" \
        -width 13 \
        -command {editSelectedSubject}
    pack .subject.edit -in .subject.actions -side left -padx 8

    button .subject.update \
        -text "Update Selected" \
        -width 15 \
        -command {updateSelectedSubject}
    pack .subject.update -in .subject.actions -side left -padx 8

    button .subject.refresh \
        -text "Refresh" \
        -width 10 \
        -command {refreshSubjectList}
    pack .subject.refresh -in .subject.actions -side left -padx 8

    button .subject.delete \
        -text "Delete Selected" \
        -width 14 \
        -command {deleteSelectedSubject}
    pack .subject.delete -in .subject.actions -side left -padx 8

    button .subject.close \
        -text "Close" \
        -command {destroy .subject}
    pack .subject.close -in .subject.actions -side left -padx 8

    listbox .subject.list -width 110 -height 10
    pack .subject.list -fill both -expand 1 -padx 10 -pady 8

    applyThemeToWindow .subject
    refreshSubjectList
}

proc loadSubjectDepartmentOptions {} {
    global db
    set departments {}

    foreach query {
        {SELECT COALESCE(NULLIF(trim(short_name), ''), department_name) AS department FROM departments WHERE department_name IS NOT NULL AND trim(department_name) <> ''}
        {SELECT DISTINCT department FROM faculty WHERE department IS NOT NULL AND trim(department) <> ''}
        {SELECT DISTINCT department FROM subjects WHERE department IS NOT NULL AND trim(department) <> ''}
        {SELECT DISTINCT department FROM classrooms WHERE department IS NOT NULL AND trim(department) <> ''}
    } {
        db eval $query row {
            if {[lsearch -exact $departments $row(department)] < 0} {
                lappend departments $row(department)
            }
        }
    }

    return [lsort -dictionary $departments]
}

proc clearSubjectForm {} {
    global editingSubjectId
    set editingSubjectId ""
    .subject.form.e1 delete 0 end
    .subject.form.e2 delete 0 end
    .subject.form.e3 configure -values [loadSubjectDepartmentOptions]
    .subject.form.e3 set ""
    .subject.form.e4 set "3"
    .subject.form.e5 set ""
    .subject.form.e6 delete 0 end
    .subject.form.type set "Theory"
    .subject.form.lab delete 0 end
    .subject.form.lab insert 0 "3"
}

proc subjectOptionalInteger {value label} {
    set value [string trim $value]
    if {$value eq ""} {
        return "NULL"
    }
    if {![string is integer -strict $value]} {
        tk_messageBox -title "Validation Error" -message "$label must be a number." -icon warning
        return "__INVALID__"
    }
    return $value
}

proc readSubjectForm {} {
    set name   [string trim [.subject.form.e1 get]]
    set code   [string trim [.subject.form.e2 get]]
    set dept   [string trim [.subject.form.e3 get]]
    set credits [string trim [.subject.form.e4 get]]
    set sem    [string trim [.subject.form.e5 get]]
    set faculty_id [string trim [.subject.form.e6 get]]
    set subject_type [string trim [.subject.form.type get]]
    set lab_hours [string trim [.subject.form.lab get]]

    if {$name eq ""} {
        tk_messageBox -title "Validation Error" -message "Subject Name is required." -icon warning
        return "__INVALID__"
    }

    if {$subject_type eq ""} { set subject_type "Theory" }

    set credits [subjectOptionalInteger $credits "Credits"]
    if {$credits eq "__INVALID__"} { return }
    set sem [subjectOptionalInteger $sem "Semester"]
    if {$sem eq "__INVALID__"} { return }
    set faculty_id [subjectOptionalInteger $faculty_id "Assigned Faculty ID"]
    if {$faculty_id eq "__INVALID__"} { return }
    set lab_hours [subjectOptionalInteger $lab_hours "Lab Periods"]
    if {$lab_hours eq "__INVALID__"} { return }
    if {$lab_hours eq "NULL"} { set lab_hours 3 }

    set escName [string map {"'" "''"} $name]
    set escCode [string map {"'" "''"} $code]
    set escDept [string map {"'" "''"} $dept]
    set escType [string map {"'" "''"} $subject_type]

    return [list $escName $escCode $escDept $credits $sem $faculty_id $escType $lab_hours]
}

proc addSubject {} {
    global db

    set values [readSubjectForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values escName escCode escDept credits sem faculty_id escType lab_hours

    set vals "'$escName','$escCode','$escDept',${credits},${sem},${faculty_id},'$escType',${lab_hours}"
    set sql "INSERT INTO subjects (subject_name, subject_code, department, credits, semester, faculty_id, subject_type, lab_hours) VALUES ($vals)"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Failed to add subject:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Subject added successfully." -icon info
        clearSubjectForm
        refreshSubjectList
    }
}

proc selectedSubjectId {} {
    set sel [.subject.list curselection]
    if {$sel eq ""} {
        return ""
    }

    set line [.subject.list get $sel]
    if {[regexp {^([0-9]+) \|} $line -> subjectId]} {
        return $subjectId
    }
    return ""
}

proc editSelectedSubject {} {
    global db editingSubjectId
    set subjectId [selectedSubjectId]
    if {$subjectId eq ""} {
        tk_messageBox -title "Edit" -message "Select a subject row." -icon info
        return
    }

    set found 0
    db eval "SELECT subject_name, subject_code, department, COALESCE(credits, '') AS credits, COALESCE(semester, '') AS semester, COALESCE(faculty_id, '') AS faculty_id, COALESCE(subject_type, 'Theory') AS subject_type, COALESCE(lab_hours, 3) AS lab_hours FROM subjects WHERE subject_id = $subjectId" row {
        set found 1
        clearSubjectForm
        set editingSubjectId $subjectId
        .subject.form.e1 insert 0 $row(subject_name)
        .subject.form.e2 insert 0 $row(subject_code)
        .subject.form.e3 set $row(department)
        .subject.form.e4 set $row(credits)
        .subject.form.e5 set $row(semester)
        .subject.form.e6 insert 0 $row(faculty_id)
        .subject.form.type set $row(subject_type)
        .subject.form.lab delete 0 end
        .subject.form.lab insert 0 $row(lab_hours)
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Selected subject was not found." -icon warning
    }
}

proc updateSelectedSubject {} {
    global db editingSubjectId
    if {$editingSubjectId eq ""} {
        set editingSubjectId [selectedSubjectId]
    }
    if {$editingSubjectId eq ""} {
        tk_messageBox -title "Update" -message "Select a subject row, then click Edit Selected." -icon info
        return
    }

    set values [readSubjectForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values escName escCode escDept credits sem faculty_id escType lab_hours

    set sql "UPDATE subjects SET subject_name='$escName', subject_code='$escCode', department='$escDept', credits=$credits, semester=$sem, faculty_id=$faculty_id, subject_type='$escType', lab_hours=$lab_hours WHERE subject_id = $editingSubjectId"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Could not update subject:\n$err" -icon error
        return
    }

    tk_messageBox -title "Success" -message "Subject updated successfully." -icon info
    clearSubjectForm
    refreshSubjectList
}

proc refreshSubjectList {} {
    global db
    if {![winfo exists .subject.list]} {
        return
    }

    .subject.list delete 0 end
    db eval {
        SELECT subject_id, subject_name, subject_code, department, credits, semester,
               COALESCE(subject_type, 'Theory') AS subject_type,
               COALESCE(lab_hours, 3) AS lab_hours
        FROM subjects
        ORDER BY department, semester, subject_name
    } row {
        .subject.list insert end "[format {%d | %s | %s | Dept:%s | Credits:%s | Sem:%s | %s | Lab:%s} $row(subject_id) $row(subject_name) $row(subject_code) $row(department) $row(credits) $row(semester) $row(subject_type) $row(lab_hours)]"
    }
}

proc deleteSelectedSubject {} {
    global db
    set subjectId [selectedSubjectId]
    if {$subjectId eq ""} {
        tk_messageBox -title "Delete" -message "Select a subject row." -icon info
        return
    }

    if {[catch {db eval "DELETE FROM subjects WHERE subject_id = $subjectId"} err]} {
        tk_messageBox -title "Database Error" -message "Could not delete subject:\n$err" -icon error
        return
    }

    refreshSubjectList
}
