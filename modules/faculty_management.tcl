proc openFacultyManagement {} {
    if {[winfo exists .faculty]} {
        raise .faculty
        return
    }

    toplevel .faculty
    wm title .faculty "Faculty Management"
    wm geometry .faculty "600x450"
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

    button .faculty.close \
        -text "Close" \
        -command {destroy .faculty}
    pack .faculty.close -in .faculty.actions -side left -padx 10

    applyThemeToWindow .faculty
}

proc clearFacultyForm {} {
    .faculty.form.e1 delete 0 end
    .faculty.form.e2 delete 0 end
    .faculty.form.e3 delete 0 end
    .faculty.form.e4 delete 0 end
    .faculty.form.e5 delete 0 end
}

proc addFaculty {} {
    global db

    set name [.faculty.form.e1 get]
    set dept [.faculty.form.e2 get]
    set desig [.faculty.form.e3 get]
    set email [.faculty.form.e4 get]
    set phone [.faculty.form.e5 get]

    if {$name eq ""} {
        tk_messageBox -title "Validation Error" -message "Faculty Name is required." -icon warning
        return
    }

    # Escape single quotes for SQL
    set escName [string map {"'" "''"} $name]
    set escDept [string map {"'" "''"} $dept]
    set escDesig [string map {"'" "''"} $desig]
    set escEmail [string map {"'" "''"} $email]
    set escPhone [string map {"'" "''"} $phone]

    set sql "INSERT INTO faculty (faculty_name, department, designation, email, phone) VALUES ('$escName','$escDept','$escDesig','$escEmail','$escPhone')"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Failed to add faculty:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Faculty added successfully." -icon info
        clearFacultyForm
    }
}
