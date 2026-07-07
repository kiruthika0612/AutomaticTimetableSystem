proc openClassroomManagement {} {
    if {[winfo exists .classroom]} {
        raise .classroom
        return
    }

    toplevel .classroom
    wm title .classroom "Classroom Management"
    wm geometry .classroom "600x380"
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

    button .classroom.close \
        -text "Close" \
        -command {destroy .classroom}
    pack .classroom.close -in .classroom.actions -side left -padx 8

    applyThemeToWindow .classroom
}

proc clearClassroomForm {} {
    .classroom.form.e1 delete 0 end
    .classroom.form.e2 delete 0 end
    .classroom.form.e3 delete 0 end
    .classroom.form.e4 delete 0 end
    .classroom.form.e5 delete 0 end
}

proc addClassroom {} {
    global db

    set room  [.classroom.form.e1 get]
    set name  [.classroom.form.e2 get]
    set build [.classroom.form.e3 get]
    set cap   [.classroom.form.e4 get]
    set dept  [.classroom.form.e5 get]

    if {$room eq ""} {
        tk_messageBox -title "Validation Error" -message "Room Number is required." -icon warning
        return
    }

    if {$cap eq ""} {
        set cap "NULL"
    } else {
        catch {set cap [expr {int($cap)}]} result
        if {[string is integer -strict $cap] == 0 && $cap ne "NULL"} {
            tk_messageBox -title "Validation Error" -message "Capacity must be an integer." -icon warning
            return
        }
    }

    set escRoom  [string map {"'" "''"} $room]
    set escName  [string map {"'" "''"} $name]
    set escBuild [string map {"'" "''"} $build]
    set escDept  [string map {"'" "''"} $dept]

    if {$cap eq "NULL"} {
        set sql "INSERT INTO classrooms (room_number, name, building, capacity, department) VALUES ('$escRoom','$escName','$escBuild',NULL,'$escDept')"
    } else {
        set sql "INSERT INTO classrooms (room_number, name, building, capacity, department) VALUES ('$escRoom','$escName','$escBuild',$cap,'$escDept')"
    }

    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" -message "Failed to add classroom:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Classroom added successfully." -icon info
        clearClassroomForm
    }
}
