# =============================================================================
#  FACULTY MANAGEMENT MODULE
#  File  : modules/faculty_management.tcl
#
#  HOW TO EDIT THIS FILE (quick reference)
#  ─────────────────────────────────────────
#  Change default hours per designation  → DESIGNATION_HOURS array below
#  Add / remove designation options      → FACULTY_DESIGNATIONS list below
#  Change form fields                    → openFacultyManagement  proc
#  Change table columns / widths         → TABLE COLUMNS section
#  Change add/save/delete logic          → addFaculty / updateSelectedFaculty
#  Change CSV import logic               → parseAndImportFacultyCsv
# =============================================================================

# -----------------------------------------------------------------------------
#  DESIGNATION → DEFAULT HOURS
#  Edit the number next to each title to change the auto-filled hours value.
# -----------------------------------------------------------------------------
array set DESIGNATION_HOURS {
    "Professor"            20
    "Associate Professor"  22
    "Assistant Professor"  24
    "Senior Lecturer"      24
    "Lecturer"             26
    "Guest Faculty"        16
    "Lab Instructor"       28
    "Teaching Assistant"   30
}

# -----------------------------------------------------------------------------
#  DESIGNATION DROPDOWN LIST
#  Add or remove a line here to change what appears in the Designation dropdown.
# -----------------------------------------------------------------------------
set FACULTY_DESIGNATIONS {
    "Professor"
    "Associate Professor"
    "Assistant Professor"
    "Senior Lecturer"
    "Lecturer"
    "Guest Faculty"
    "Lab Instructor"
    "Teaching Assistant"
}

# =============================================================================
#  HELPERS
# =============================================================================

# Load department names from DB for the Department dropdown
proc loadFacultyDepartments {} {
    global db
    set names {}
    db eval {SELECT department_name, short_name FROM departments
             ORDER BY department_name} row {
        set label $row(department_name)
        if {$row(short_name) ne ""} { set label $row(short_name) }
        if {[lsearch -exact $names $label] < 0} { lappend names $label }
    }
    return $names
}

# Return default hours for a designation (used to auto-fill the Hours field)
proc defaultHoursForDesignation {designation} {
    global DESIGNATION_HOURS
    if {[info exists DESIGNATION_HOURS($designation)]} {
        return $DESIGNATION_HOURS($designation)
    }
    return ""
}

# =============================================================================
#  FORM HELPERS
# =============================================================================

# Clear all input fields in the main form
proc clearFacultyForm {} {
    global editingFacultyId
    set editingFacultyId ""
    .faculty.form.name  delete 0 end
    .faculty.form.dept  set ""
    .faculty.form.desig set ""
    .faculty.form.email delete 0 end
    .faculty.form.phone delete 0 end
    .faculty.form.hours delete 0 end
}

# Read all fields, validate, and return a list for SQL use.
# Returns "__INVALID__" if any field fails validation.
proc readFacultyForm {} {
    set name  [string trim [.faculty.form.name  get]]
    set dept  [string trim [.faculty.form.dept  get]]
    set desig [string trim [.faculty.form.desig get]]
    set email [string trim [.faculty.form.email get]]
    set phone [string trim [.faculty.form.phone get]]
    set hours [string trim [.faculty.form.hours get]]

    if {$name eq ""} {
        tk_messageBox -title "Validation" \
            -message "Faculty Name is required." -icon warning
        return "__INVALID__"
    }
    if {$hours eq ""} {
        set hours "NULL"
    } elseif {![string is integer -strict $hours]} {
        tk_messageBox -title "Validation" \
            -message "Hours Allotted must be a whole number." -icon warning
        return "__INVALID__"
    }

    # Escape single-quotes so names like "O'Brien" don't break SQL
    return [list \
        [string map {"'" "''"} $name]  \
        [string map {"'" "''"} $dept]  \
        [string map {"'" "''"} $desig] \
        [string map {"'" "''"} $email] \
        [string map {"'" "''"} $phone] \
        $hours]
}

# =============================================================================
#  ADD / EDIT / UPDATE / DELETE
# =============================================================================

proc addFaculty {} {
    global db
    set values [readFacultyForm]
    if {$values eq "__INVALID__"} { return }
    lassign $values name dept desig email phone hours

    set sql "INSERT INTO faculty
                 (faculty_name, department, designation, email, phone, hours_allotted)
             VALUES ('$name','$dept','$desig','$email','$phone',$hours)"

    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" \
            -message "Could not add faculty:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Faculty member added." -icon info
        clearFacultyForm
        refreshFacultyList
    }
}

# Get the faculty_id of the selected row in the table
proc selectedFacultyId {} {
    set sel [.faculty.table.tree selection]
    if {$sel eq ""} { return "" }
    return [lindex [.faculty.table.tree item $sel -values] 0]
}

proc editSelectedFaculty {} {
    global db editingFacultyId
    set fid [selectedFacultyId]
    if {$fid eq ""} {
        tk_messageBox -title "Edit" -message "Select a faculty row first." -icon info
        return
    }
    set found 0
    db eval "SELECT faculty_name, department, designation, email, phone,
                    COALESCE(hours_allotted,'') AS hours_allotted
             FROM   faculty WHERE faculty_id = $fid" row {
        set found 1
        clearFacultyForm
        set editingFacultyId $fid
        .faculty.form.name  insert 0 $row(faculty_name)
        .faculty.form.dept  set      $row(department)
        .faculty.form.desig set      $row(designation)
        .faculty.form.email insert 0 $row(email)
        .faculty.form.phone insert 0 $row(phone)
        .faculty.form.hours insert 0 $row(hours_allotted)
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Faculty not found." -icon warning
    }
}

proc updateSelectedFaculty {} {
    global db editingFacultyId
    if {$editingFacultyId eq ""} { set editingFacultyId [selectedFacultyId] }
    if {$editingFacultyId eq ""} {
        tk_messageBox -title "Update" \
            -message "Select a row, then click Edit Selected." -icon info
        return
    }
    set values [readFacultyForm]
    if {$values eq "__INVALID__"} { return }
    lassign $values name dept desig email phone hours

    set sql "UPDATE faculty
             SET    faculty_name='$name', department='$dept',
                    designation='$desig', email='$email',
                    phone='$phone', hours_allotted=$hours
             WHERE  faculty_id = $editingFacultyId"

    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" \
            -message "Could not update:\n$err" -icon error
        return
    }
    tk_messageBox -title "Success" -message "Faculty updated." -icon info
    clearFacultyForm
    refreshFacultyList
}

proc deleteSelectedFaculty {} {
    global db
    set fid [selectedFacultyId]
    if {$fid eq ""} {
        tk_messageBox -title "Delete" -message "Select a row first." -icon info
        return
    }
    set name ""
    db eval "SELECT faculty_name FROM faculty WHERE faculty_id = $fid" row {
        set name $row(faculty_name)
    }
    set confirm [tk_messageBox -title "Confirm Delete" \
        -message "Delete \"$name\"?\nThis cannot be undone." \
        -icon question -type yesno]
    if {$confirm ne "yes"} { return }

    if {[catch {db eval "DELETE FROM faculty WHERE faculty_id = $fid"} err]} {
        tk_messageBox -title "Database Error" -message "Could not delete:\n$err" -icon error
        return
    }
    resetTableSequence faculty faculty_id
    refreshFacultyList
}

# Reload the table from the database
proc refreshFacultyList {} {
    global db
    if {![winfo exists .faculty.table.tree]} { return }
    .faculty.table.tree delete [.faculty.table.tree children {}]
    set rowIdx 0
    db eval {SELECT faculty_id, faculty_name, department, designation,
                    email, phone, COALESCE(hours_allotted,'') AS hours_allotted
             FROM   faculty ORDER BY department, faculty_name} row {
        set tag [expr {$rowIdx % 2 == 0 ? "even" : "odd"}]
        .faculty.table.tree insert {} end -values [list \
            $row(faculty_id)   $row(faculty_name) $row(department) \
            $row(designation)  $row(email)        $row(phone) \
            $row(hours_allotted)] -tags $tag
        incr rowIdx
    }
}

# =============================================================================
#  MAIN WINDOW
# =============================================================================
proc openFacultyManagement {} {
    global editingFacultyId
    set editingFacultyId ""

    if {[winfo exists .faculty]} { raise .faculty ; return }

    toplevel .faculty
    wm title    .faculty "Faculty Management"
    wm geometry .faculty "1050x700"
    .faculty configure -bg white

    # Header bar
    label .faculty.header -text "FACULTY MANAGEMENT" \
        -font {Arial 18 bold} -bg "#1565C0" -fg white
    pack .faculty.header -fill x -pady 10

    # ── INPUT FORM ───────────────────────────────────────────────────────────
    #  Each widget has a descriptive name (e.g. .faculty.form.name not .e1)
    frame .faculty.form -bg white
    pack  .faculty.form -pady 8

    label .faculty.form.namelbl  -text "Faculty Name :"  -bg white
    grid  .faculty.form.namelbl  -row 0 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.name     -width 30
    grid  .faculty.form.name     -row 0 -column 1 -padx 10 -sticky w

    label .faculty.form.deptlbl  -text "Department :"   -bg white
    grid  .faculty.form.deptlbl  -row 1 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .faculty.form.dept -values [loadFacultyDepartments] -width 28
    grid  .faculty.form.dept     -row 1 -column 1 -padx 10 -sticky w

    label .faculty.form.desiglbl -text "Designation :"  -bg white
    grid  .faculty.form.desiglbl -row 2 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .faculty.form.desig -values $::FACULTY_DESIGNATIONS -width 28
    grid  .faculty.form.desig    -row 2 -column 1 -padx 10 -sticky w

    # Picking a designation auto-fills the Hours field
    bind .faculty.form.desig <<ComboboxSelected>> {
        set _hrs [defaultHoursForDesignation [.faculty.form.desig get]]
        if {$_hrs ne ""} {
            .faculty.form.hours delete 0 end
            .faculty.form.hours insert 0 $_hrs
        }
    }

    label .faculty.form.emaillbl -text "Email :"         -bg white
    grid  .faculty.form.emaillbl -row 3 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.email    -width 30
    grid  .faculty.form.email    -row 3 -column 1 -padx 10 -sticky w

    label .faculty.form.phonelbl -text "Phone :"         -bg white
    grid  .faculty.form.phonelbl -row 4 -column 0 -padx 10 -pady 5 -sticky e
    entry .faculty.form.phone    -width 30
    grid  .faculty.form.phone    -row 4 -column 1 -padx 10 -sticky w

    label .faculty.form.hourslbl -text "Hours Allotted :" -bg white
    grid  .faculty.form.hourslbl -row 5 -column 0 -padx 10 -pady 5 -sticky e

    frame .faculty.form.hoursrow -bg white
    grid  .faculty.form.hoursrow -row 5 -column 1 -padx 10 -sticky w
    entry .faculty.form.hours -width 8
    pack  .faculty.form.hours -in .faculty.form.hoursrow -side left
    label .faculty.form.hourshint \
        -text "(auto-filled by designation — you can change it)" \
        -font {Arial 8} -bg white -fg "#888888"
    pack  .faculty.form.hourshint -in .faculty.form.hoursrow -side left -padx 6

    # ── BUTTONS ──────────────────────────────────────────────────────────────
    frame .faculty.buttons -bg white
    pack  .faculty.buttons -pady 6

    button .faculty.buttons.add        -text "Add Faculty"          -width 15 -command {addFaculty}
    button .faculty.buttons.individual -text "Add Individual Staff" -width 20 -command {openAddIndividualStaff}
    button .faculty.buttons.import     -text "Import from CSV"      -width 18 -command {openImportFaculty}
    button .faculty.buttons.clear      -text "Clear Form"           -width 10 -command {clearFacultyForm}
    button .faculty.buttons.edit       -text "Edit Selected"        -width 13 -command {editSelectedFaculty}
    button .faculty.buttons.update     -text "Update Selected"      -width 15 -command {updateSelectedFaculty}
    button .faculty.buttons.refresh    -text "Refresh"              -width 10 -command {refreshFacultyList}
    button .faculty.buttons.delete     -text "Delete Selected"      -width 14 -command {deleteSelectedFaculty}
    button .faculty.buttons.close      -text "Close"                           -command {destroy .faculty}

    foreach btn {add individual import clear edit update refresh delete close} {
        pack .faculty.buttons.$btn -in .faculty.buttons -side left -padx 5
    }

    # ── TABLE COLUMNS ────────────────────────────────────────────────────────
    #  To add a column  : add the name to $cols, add a heading and column line
    #  To remove a col  : remove from $cols and delete its heading/column lines
    #  To rename header : change -text in the heading line
    #  To resize column : change -width in the column line
    frame .faculty.table -bg white
    pack  .faculty.table -fill both -expand 1 -padx 10 -pady 8

    set cols {FacultyID Name Department Designation Email Phone Hours}

    ttk::style configure Faculty.Treeview \
        -font {Arial 10} -rowheight 26
    ttk::style configure Faculty.Treeview.Heading \
        -font {Arial 10 bold} -background "#1565C0" -foreground white

    ttk::treeview .faculty.table.tree \
        -columns      $cols \
        -show         headings \
        -selectmode   browse \
        -style        Faculty.Treeview \
        -yscrollcommand {.faculty.table.yscroll set} \
        -xscrollcommand {.faculty.table.xscroll set}

    scrollbar .faculty.table.yscroll \
        -orient vertical   -command {.faculty.table.tree yview}
    scrollbar .faculty.table.xscroll \
        -orient horizontal -command {.faculty.table.tree xview}

    # Column headers
    .faculty.table.tree heading FacultyID   -text "ID"
    .faculty.table.tree heading Name        -text "Faculty Name"
    .faculty.table.tree heading Department  -text "Department"
    .faculty.table.tree heading Designation -text "Designation"
    .faculty.table.tree heading Email       -text "Email"
    .faculty.table.tree heading Phone       -text "Phone"
    .faculty.table.tree heading Hours       -text "Hrs"

    # Column widths
    .faculty.table.tree column FacultyID   -width 45  -anchor center
    .faculty.table.tree column Name        -width 185 -anchor w
    .faculty.table.tree column Department  -width 130 -anchor w
    .faculty.table.tree column Designation -width 165 -anchor w
    .faculty.table.tree column Email       -width 195 -anchor w
    .faculty.table.tree column Phone       -width 110 -anchor w
    .faculty.table.tree column Hours       -width 45  -anchor center

    # Alternating row colours
    .faculty.table.tree tag configure odd  -background "#F7FBFF"
    .faculty.table.tree tag configure even -background "#EAF3FC"

    grid .faculty.table.tree    -row 0 -column 0 -sticky nsew
    grid .faculty.table.yscroll -row 0 -column 1 -sticky ns
    grid .faculty.table.xscroll -row 1 -column 0 -sticky ew
    grid rowconfigure    .faculty.table 0 -weight 1
    grid columnconfigure .faculty.table 0 -weight 1

    applyThemeToWindow .faculty
    refreshFacultyList
}

# =============================================================================
#  ADD INDIVIDUAL STAFF  (quick single-person dialog)
# =============================================================================
proc openAddIndividualStaff {} {
    if {[winfo exists .addstaff]} { raise .addstaff ; return }

    toplevel .addstaff
    wm title     .addstaff "Add Individual Staff"
    wm geometry  .addstaff "430x420"
    wm resizable .addstaff 0 0
    .addstaff configure -bg white

    label .addstaff.header -text "ADD INDIVIDUAL STAFF" \
        -font {Arial 14 bold} -bg "#1565C0" -fg white
    pack .addstaff.header -fill x -pady 10

    frame .addstaff.form -bg white
    pack  .addstaff.form -pady 10 -padx 20 -fill x

    label .addstaff.form.namelbl -text "Faculty Name *" -bg white -anchor w
    grid  .addstaff.form.namelbl -row 0 -column 0 -columnspan 2 -sticky w -pady {8 2}
    entry .addstaff.form.name    -width 36
    grid  .addstaff.form.name    -row 1 -column 0 -columnspan 2 -sticky ew -pady {0 6}

    label .addstaff.form.deptlbl -text "Department *" -bg white -anchor w
    grid  .addstaff.form.deptlbl -row 2 -column 0 -columnspan 2 -sticky w -pady {4 2}
    ttk::combobox .addstaff.form.dept -values [loadFacultyDepartments] -width 33
    grid  .addstaff.form.dept    -row 3 -column 0 -columnspan 2 -sticky ew -pady {0 6}

    label .addstaff.form.desiglbl -text "Designation" -bg white -anchor w
    grid  .addstaff.form.desiglbl -row 4 -column 0 -columnspan 2 -sticky w -pady {4 2}
    ttk::combobox .addstaff.form.desig -values $::FACULTY_DESIGNATIONS -width 33
    grid  .addstaff.form.desig   -row 5 -column 0 -columnspan 2 -sticky ew -pady {0 6}

    bind .addstaff.form.desig <<ComboboxSelected>> {
        set _hrs [defaultHoursForDesignation [.addstaff.form.desig get]]
        if {$_hrs ne ""} {
            .addstaff.form.hours delete 0 end
            .addstaff.form.hours insert 0 $_hrs
        }
    }

    label .addstaff.form.emaillbl -text "Email" -bg white -anchor w
    grid  .addstaff.form.emaillbl -row 6 -column 0 -sticky w -pady {4 2}
    entry .addstaff.form.email    -width 22
    grid  .addstaff.form.email    -row 7 -column 0 -sticky ew -pady {0 6} -padx {0 8}

    label .addstaff.form.phonelbl -text "Phone" -bg white -anchor w
    grid  .addstaff.form.phonelbl -row 6 -column 1 -sticky w -pady {4 2}
    entry .addstaff.form.phone    -width 14
    grid  .addstaff.form.phone    -row 7 -column 1 -sticky ew -pady {0 6}

    label .addstaff.form.hourslbl -text "Hours Allotted" -bg white -anchor w
    grid  .addstaff.form.hourslbl -row 8 -column 0 -sticky w -pady {4 2}
    entry .addstaff.form.hours    -width 8
    grid  .addstaff.form.hours    -row 9 -column 0 -sticky w -pady {0 8}

    grid columnconfigure .addstaff.form 0 -weight 1
    grid columnconfigure .addstaff.form 1 -weight 1

    frame .addstaff.buttons -bg white
    pack  .addstaff.buttons -pady 10

    button .addstaff.buttons.save  -text "Save Staff" -width 14 -command {saveIndividualStaff}
    button .addstaff.buttons.clear -text "Clear"      -width 10 -command {clearIndividualStaffForm}
    button .addstaff.buttons.close -text "Close"      -width 10 -command {destroy .addstaff}

    pack .addstaff.buttons.save  -side left -padx 8
    pack .addstaff.buttons.clear -side left -padx 8
    pack .addstaff.buttons.close -side left -padx 8

    applyThemeToWindow .addstaff
    focus .addstaff.form.name
}

proc clearIndividualStaffForm {} {
    .addstaff.form.name  delete 0 end
    .addstaff.form.dept  set ""
    .addstaff.form.desig set ""
    .addstaff.form.email delete 0 end
    .addstaff.form.phone delete 0 end
    .addstaff.form.hours delete 0 end
    focus .addstaff.form.name
}

proc saveIndividualStaff {} {
    global db
    set name  [string trim [.addstaff.form.name  get]]
    set dept  [string trim [.addstaff.form.dept  get]]
    set desig [string trim [.addstaff.form.desig get]]
    set email [string trim [.addstaff.form.email get]]
    set phone [string trim [.addstaff.form.phone get]]
    set hours [string trim [.addstaff.form.hours get]]

    if {$name eq ""} {
        tk_messageBox -parent .addstaff -title "Validation" \
            -message "Faculty Name is required." -icon warning
        focus .addstaff.form.name ; return
    }
    if {$dept eq ""} {
        tk_messageBox -parent .addstaff -title "Validation" \
            -message "Department is required." -icon warning
        focus .addstaff.form.dept ; return
    }
    if {$hours eq ""} { set hours "NULL" } \
    elseif {![string is integer -strict $hours]} {
        tk_messageBox -parent .addstaff -title "Validation" \
            -message "Hours Allotted must be a whole number." -icon warning
        focus .addstaff.form.hours ; return
    }

    set sql "INSERT INTO faculty
                 (faculty_name, department, designation, email, phone, hours_allotted)
             VALUES (
                 '[string map {"'" "''"} $name]',
                 '[string map {"'" "''"} $dept]',
                 '[string map {"'" "''"} $desig]',
                 '[string map {"'" "''"} $email]',
                 '[string map {"'" "''"} $phone]',
                 $hours)"

    if {[catch {db eval $sql} err]} {
        tk_messageBox -parent .addstaff -title "Database Error" \
            -message "Could not add:\n$err" -icon error
    } else {
        tk_messageBox -parent .addstaff -title "Success" \
            -message "\"$name\" added." -icon info
        clearIndividualStaffForm
        if {[winfo exists .faculty.table.tree]} { refreshFacultyList }
    }
}

# =============================================================================
#  CSV IMPORT
# =============================================================================

proc openImportFaculty {} {
    if {[winfo exists .importfaculty]} { raise .importfaculty ; return }

    toplevel .importfaculty
    wm title     .importfaculty "Import Faculty from CSV"
    wm geometry  .importfaculty "620x500"
    wm resizable .importfaculty 1 1
    .importfaculty configure -bg white

    label .importfaculty.header -text "IMPORT FACULTY FROM CSV" \
        -font {Arial 14 bold} -bg "#1565C0" -fg white
    pack .importfaculty.header -fill x -pady 10

    # Instructions box
    frame .importfaculty.info -bg "#EAF3FC" -relief solid -bd 1
    pack  .importfaculty.info -fill x -padx 14 -pady 6
    label .importfaculty.info.txt \
        -justify left -bg "#EAF3FC" -font {Arial 9} -anchor w \
        -text "CSV columns (row 1 = header, skipped automatically):\n  faculty_name, department, designation, email, phone, hours_allotted\n\nDownload the template, fill it in Excel, save as CSV, then import."
    pack .importfaculty.info.txt -padx 10 -pady 8 -anchor w

    # File picker
    frame .importfaculty.pick -bg white
    pack  .importfaculty.pick -fill x -padx 14 -pady 8

    label .importfaculty.pick.lbl -text "CSV File :" -bg white
    pack  .importfaculty.pick.lbl -side left

    entry .importfaculty.pick.path -width 46
    pack  .importfaculty.pick.path -side left -padx 6

    button .importfaculty.pick.browse -text "Browse..." -width 10 \
        -command {
            set f [tk_getOpenFile -parent .importfaculty \
                -title "Select CSV File" \
                -filetypes {{"CSV Files" {.csv .txt}} {"All Files" *}}]
            if {$f ne ""} {
                .importfaculty.pick.path delete 0 end
                .importfaculty.pick.path insert 0 $f
            }
        }
    pack .importfaculty.pick.browse -side left

    # Log area
    frame .importfaculty.logframe -bg white
    pack  .importfaculty.logframe -fill both -expand 1 -padx 14 -pady 4

    label .importfaculty.logframe.lbl -text "Import Log:" -bg white -anchor w
    pack  .importfaculty.logframe.lbl -anchor w

    text .importfaculty.logframe.log \
        -height 12 -wrap word -font {Consolas 9} \
        -state disabled -relief solid -bd 1
    scrollbar .importfaculty.logframe.ys -orient vertical \
        -command {.importfaculty.logframe.log yview}
    .importfaculty.logframe.log configure \
        -yscrollcommand {.importfaculty.logframe.ys set}
    pack .importfaculty.logframe.ys  -side right -fill y
    pack .importfaculty.logframe.log -side left  -fill both -expand 1

    # Buttons
    frame .importfaculty.buttons -bg white
    pack  .importfaculty.buttons -pady 10

    button .importfaculty.buttons.template \
        -text "Download Template" -width 18 -command {downloadFacultyCsvTemplate}
    button .importfaculty.buttons.import \
        -text "Import Now"        -width 14 -command {parseAndImportFacultyCsv}
    button .importfaculty.buttons.close \
        -text "Close"             -width 10 -command {destroy .importfaculty}

    pack .importfaculty.buttons.template -side left -padx 8
    pack .importfaculty.buttons.import   -side left -padx 8
    pack .importfaculty.buttons.close    -side left -padx 8

    applyThemeToWindow .importfaculty
}

# Write a line to the import log box
proc importLog {msg} {
    if {![winfo exists .importfaculty.logframe.log]} { return }
    .importfaculty.logframe.log configure -state normal
    .importfaculty.logframe.log insert end "$msg\n"
    .importfaculty.logframe.log see end
    .importfaculty.logframe.log configure -state disabled
}

proc clearImportLog {} {
    if {![winfo exists .importfaculty.logframe.log]} { return }
    .importfaculty.logframe.log configure -state normal
    .importfaculty.logframe.log delete 1.0 end
    .importfaculty.logframe.log configure -state disabled
}

proc downloadFacultyCsvTemplate {} {
    set savePath [tk_getSaveFile -parent .importfaculty \
        -title "Save CSV Template As" \
        -initialfile "faculty_template.csv" \
        -filetypes {{"CSV Files" {.csv}} {"All Files" *}}]
    if {$savePath eq ""} { return }

    if {[catch {
        set fh [open $savePath w]
        puts $fh "faculty_name,department,designation,email,phone,hours_allotted"
        puts $fh "Dr. A. Kumar,CSE,Professor,akumar@college.edu,9876543210,20"
        puts $fh "Prof. B. Raj,ECE,Associate Professor,braj@college.edu,9876543211,22"
        puts $fh "Ms. C. Priya,MECH,Assistant Professor,cpriya@college.edu,,24"
        puts $fh "Mr. D. Suresh,CIVIL,Lecturer,dsuresh@college.edu,9876543213,26"
        close $fh
    } err]} {
        tk_messageBox -parent .importfaculty -title "Error" \
            -message "Could not save template:\n$err" -icon error
        return
    }
    tk_messageBox -parent .importfaculty -title "Template Saved" \
        -message "Saved to:\n$savePath\n\nOpen in Excel, fill details, save as CSV, then import." \
        -icon info
}

# Split one CSV line — handles quoted fields correctly
proc splitCsvLine {line} {
    set fields {} ; set field "" ; set inQuote 0
    set len [string length $line]
    for {set i 0} {$i < $len} {incr i} {
        set ch [string index $line $i]
        if {$inQuote} {
            if {$ch eq "\""} {
                if {[string index $line [expr {$i+1}]] eq "\""} {
                    append field "\"" ; incr i
                } else { set inQuote 0 }
            } else { append field $ch }
        } else {
            if      {$ch eq "\""} { set inQuote 1 } \
            elseif  {$ch eq ","} { lappend fields [string trim $field] ; set field "" } \
            else                  { append field $ch }
        }
    }
    lappend fields [string trim $field]
    return $fields
}

proc parseAndImportFacultyCsv {} {
    global db
    set csvPath [string trim [.importfaculty.pick.path get]]

    if {$csvPath eq ""} {
        tk_messageBox -parent .importfaculty -title "No File" \
            -message "Select a CSV file first." -icon warning ; return
    }
    if {![file exists $csvPath]} {
        tk_messageBox -parent .importfaculty -title "Not Found" \
            -message "File not found:\n$csvPath" -icon error ; return
    }

    clearImportLog
    importLog "Reading: $csvPath"
    importLog "---------------------------------------------------"

    if {[catch {
        set fh [open $csvPath r]
        set lines [split [read $fh] "\n"]
        close $fh
    } err]} {
        tk_messageBox -parent .importfaculty -title "Read Error" \
            -message "Could not read:\n$err" -icon error ; return
    }

    set rowNum 0 ; set imported 0 ; set skipped 0 ; set errors 0

    foreach rawLine $lines {
        incr rowNum
        set rawLine [string trimright $rawLine "\r"]
        if {[string trim $rawLine] eq ""} { continue }
        if {$rowNum == 1} { importLog "Row 1 (header skipped)" ; continue }

        set cols [splitCsvLine $rawLine]
        while {[llength $cols] < 6} { lappend cols "" }

        set name  [string trim [lindex $cols 0]]
        set dept  [string trim [lindex $cols 1]]
        set desig [string trim [lindex $cols 2]]
        set email [string trim [lindex $cols 3]]
        set phone [string trim [lindex $cols 4]]
        set hours [string trim [lindex $cols 5]]

        if {$name eq ""} {
            importLog "Row $rowNum SKIPPED : name is empty" ; incr skipped ; continue
        }
        if {$dept eq ""} {
            importLog "Row $rowNum SKIPPED : department empty  ($name)" ; incr skipped ; continue
        }
        if {$hours eq ""} { set hours [defaultHoursForDesignation $desig] }
        if {$hours eq "" || ![string is integer -strict $hours]} { set hours "NULL" }

        set sql "INSERT INTO faculty (faculty_name,department,designation,email,phone,hours_allotted)
                 VALUES (
                     '[string map {"'" "''"} $name]',
                     '[string map {"'" "''"} $dept]',
                     '[string map {"'" "''"} $desig]',
                     '[string map {"'" "''"} $email]',
                     '[string map {"'" "''"} $phone]',
                     $hours)"

        if {[catch {db eval $sql} err]} {
            importLog "Row $rowNum ERROR   : $name — $err" ; incr errors
        } else {
            importLog "Row $rowNum OK      : $name | $dept | Hrs:$hours" ; incr imported
        }
    }

    importLog "---------------------------------------------------"
    importLog "Done.  Imported: $imported   Skipped: $skipped   Errors: $errors"
    if {$imported > 0 && [winfo exists .faculty.table.tree]} { refreshFacultyList }
}
