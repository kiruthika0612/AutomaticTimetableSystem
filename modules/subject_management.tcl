proc openSubjectManagement {} {
    if {[winfo exists .subject]} {
        raise .subject
        return
    }

    toplevel .subject
    wm title .subject "Subject Management"
    wm geometry .subject "640x520"
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
    entry .subject.form.e3 -width 30
    grid .subject.form.e3 -row 2 -column 1 -padx 10

    label .subject.form.l4 -text "Credits :" -bg white
    grid .subject.form.l4 -row 3 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.e4 -width 8
    grid .subject.form.e4 -row 3 -column 1 -padx 10 -sticky w

    label .subject.form.l5 -text "Semester :" -bg white
    grid .subject.form.l5 -row 4 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.e5 -width 8
    grid .subject.form.e5 -row 4 -column 1 -padx 10 -sticky w

    label .subject.form.l6 -text "Assigned Faculty ID :" -bg white
    grid .subject.form.l6 -row 5 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.e6 -width 12
    grid .subject.form.e6 -row 5 -column 1 -padx 10 -sticky w

    label .subject.form.l7 -text "Subject Type :" -bg white
    grid .subject.form.l7 -row 6 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.type -values {"Theory" "Lab"} -width 12
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

    button .subject.close \
        -text "Close" \
        -command {destroy .subject}
    pack .subject.close -in .subject.actions -side left -padx 8

    applyThemeToWindow .subject
}

proc clearSubjectForm {} {
    .subject.form.e1 delete 0 end
    .subject.form.e2 delete 0 end
    .subject.form.e3 delete 0 end
    .subject.form.e4 delete 0 end
    .subject.form.e5 delete 0 end
    .subject.form.e6 delete 0 end
    .subject.form.type set "Theory"
    .subject.form.lab delete 0 end
    .subject.form.lab insert 0 "3"
}

proc addSubject {} {
    global db

    set name   [.subject.form.e1 get]
    set code   [.subject.form.e2 get]
    set dept   [.subject.form.e3 get]
    set credits [.subject.form.e4 get]
    set sem    [.subject.form.e5 get]
    set faculty_id [.subject.form.e6 get]
    set subject_type [.subject.form.type get]
    set lab_hours [.subject.form.lab get]

    if {$name eq ""} {
        tk_messageBox -title "Validation Error" -message "Subject Name is required." -icon warning
        return
    }

    if {$credits eq ""} { set credits "NULL" } else { set credits [expr {int($credits)}] }
    if {$sem eq ""} { set sem "NULL" } else { set sem [expr {int($sem)}] }
    if {$faculty_id eq ""} { set faculty_id "NULL" } else { set faculty_id [expr {int($faculty_id)}] }
    if {$subject_type eq ""} { set subject_type "Theory" }
    if {$lab_hours eq ""} { set lab_hours 3 } else { set lab_hours [expr {int($lab_hours)}] }

    set escName [string map {"'" "''"} $name]
    set escCode [string map {"'" "''"} $code]
    set escDept [string map {"'" "''"} $dept]
    set escType [string map {"'" "''"} $subject_type]

    set vals "'$escName','$escCode','$escDept',${credits},${sem},${faculty_id},'$escType',${lab_hours}"
    set sql "INSERT INTO subjects (subject_name, subject_code, department, credits, semester, faculty_id, subject_type, lab_hours) VALUES ($vals)"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Failed to add subject:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Subject added successfully." -icon info
        clearSubjectForm
    }
}
