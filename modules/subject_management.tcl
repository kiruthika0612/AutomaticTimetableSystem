# ─────────────────────────────────────────────────────────────────────────────
#  Subject Management Module
#  - Faculty assigned via name dropdown (ID resolved internally)
#  - Weekly Hours field with auto-suggestion from credits / subject type
#  - ttk::treeview table replacing the plain listbox
# ─────────────────────────────────────────────────────────────────────────────

# Default weekly periods by subject type and credits
# Theory  → same as credits
# Lab     → lab_hours (typically 3)
# Blended → credits + 1 extra lab session

# ── Helpers ──────────────────────────────────────────────────────────────────

proc loadSubjectDepartmentOptions {} {
    global db
    set departments {}
    foreach query {
        {SELECT COALESCE(NULLIF(trim(short_name),''), department_name) AS department
           FROM departments WHERE department_name IS NOT NULL AND trim(department_name)<>''}
        {SELECT DISTINCT department FROM faculty   WHERE department IS NOT NULL AND trim(department)<>''}
        {SELECT DISTINCT department FROM subjects  WHERE department IS NOT NULL AND trim(department)<>''}
        {SELECT DISTINCT department FROM classrooms WHERE department IS NOT NULL AND trim(department)<>''}
    } {
        db eval $query row {
            if {[lsearch -exact $departments $row(department)] < 0} {
                lappend departments $row(department)
            }
        }
    }
    return [lsort -dictionary $departments]
}

# Returns list of "Name (ID)" strings for faculty combobox
proc loadFacultyOptions {} {
    global db
    set opts {}
    db eval {SELECT faculty_id, faculty_name FROM faculty ORDER BY faculty_name} row {
        lappend opts "$row(faculty_name)  \[ID:$row(faculty_id)\]"
    }
    return $opts
}

# Extract numeric ID from "Name  [ID:42]" format
proc facultyIdFromOption {opt} {
    if {[regexp {\[ID:(\d+)\]} $opt -> id]} { return $id }
    return "NULL"
}

# Build "Name  [ID:n]" label for a given faculty_id (for edit-fill)
proc facultyOptionFromId {fid} {
    global db
    set label ""
    db eval "SELECT faculty_name FROM faculty WHERE faculty_id = $fid" row {
        set label "$row(faculty_name)  \[ID:$fid\]"
    }
    return $label
}

# Auto-suggest weekly hours given credits and subject type
proc suggestWeeklyHours {credits subjectType} {
    if {![string is integer -strict $credits] || $credits < 1} { return "" }
    switch -- $subjectType {
        "Lab"     { return 3 }
        "Blended" { return [expr {$credits + 1}] }
        default   { return $credits }
    }
}

# ── Main Window ───────────────────────────────────────────────────────────────

proc openSubjectManagement {} {
    global editingSubjectId
    set editingSubjectId ""

    if {[winfo exists .subject]} { raise .subject ; return }

    toplevel .subject
    wm title .subject "Subject Management"
    wm geometry .subject "1060x680"
    .subject configure -bg white

    label .subject.title -text "SUBJECT MANAGEMENT" \
        -font {Arial 18 bold} -bg "#1565C0" -fg white
    pack .subject.title -fill x -pady 10

    # ── Form (two-column layout) ──────────────────────────────────────────────
    frame .subject.form -bg white
    pack  .subject.form -pady 8

    # Left column labels / widgets
    label .subject.form.l1 -text "Subject Name :" -bg white
    grid  .subject.form.l1 -row 0 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.e1 -width 30
    grid  .subject.form.e1 -row 0 -column 1 -padx 10 -sticky w

    label .subject.form.l2 -text "Subject Code :" -bg white
    grid  .subject.form.l2 -row 1 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.e2 -width 20
    grid  .subject.form.e2 -row 1 -column 1 -padx 10 -sticky w

    label .subject.form.l3 -text "Department :" -bg white
    grid  .subject.form.l3 -row 2 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.e3 \
        -values [loadSubjectDepartmentOptions] -width 28 -state readonly
    grid  .subject.form.e3 -row 2 -column 1 -padx 10 -sticky w

    label .subject.form.l4 -text "Credits :" -bg white
    grid  .subject.form.l4 -row 3 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.e4 -values {1 2 3 4 5 6} -width 8 -state readonly
    .subject.form.e4 set "3"
    grid  .subject.form.e4 -row 3 -column 1 -padx 10 -sticky w

    label .subject.form.l5 -text "Semester :" -bg white
    grid  .subject.form.l5 -row 4 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.e5 -values {1 2 3 4 5 6 7 8} -width 8 -state readonly
    grid  .subject.form.e5 -row 4 -column 1 -padx 10 -sticky w

    # Faculty name dropdown (replaces raw ID entry)
    label .subject.form.l6 -text "Assigned Faculty :" -bg white
    grid  .subject.form.l6 -row 5 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.faculty \
        -values [loadFacultyOptions] -width 36
    grid  .subject.form.faculty -row 5 -column 1 -padx 10 -sticky w

    label .subject.form.l7 -text "Subject Type :" -bg white
    grid  .subject.form.l7 -row 6 -column 0 -padx 10 -pady 5 -sticky e
    ttk::combobox .subject.form.type \
        -values {"Theory" "Lab" "Blended"} -width 12 -state readonly
    .subject.form.type set "Theory"
    grid  .subject.form.type -row 6 -column 1 -padx 10 -sticky w

    label .subject.form.l8 -text "Lab Periods :" -bg white
    grid  .subject.form.l8 -row 7 -column 0 -padx 10 -pady 5 -sticky e
    entry .subject.form.lab -width 8
    .subject.form.lab insert 0 "3"
    grid  .subject.form.lab -row 7 -column 1 -padx 10 -sticky w

    # Weekly Hours with hint label
    label .subject.form.l9 -text "Weekly Hours :" -bg white
    grid  .subject.form.l9 -row 8 -column 0 -padx 10 -pady 5 -sticky e
    frame .subject.form.whframe -bg white
    grid  .subject.form.whframe -row 8 -column 1 -padx 10 -sticky w
    entry .subject.form.wh -width 8
    pack  .subject.form.wh -in .subject.form.whframe -side left
    label .subject.form.whhint \
        -text "(periods/week; auto-suggested)" \
        -font {Arial 8} -bg white -fg "#888888"
    pack  .subject.form.whhint -in .subject.form.whframe -side left -padx 6

    # Auto-suggest weekly hours when credits or type changes
    bind .subject.form.e4   <<ComboboxSelected>> { subjectAutoFillWeeklyHours }
    bind .subject.form.type <<ComboboxSelected>> { subjectAutoFillWeeklyHours }

    # ── Buttons ───────────────────────────────────────────────────────────────
    frame .subject.actions -bg white
    pack  .subject.actions -pady 10

    button .subject.add     -text "Add Subject"        -width 14 -command {addSubject}
    button .subject.import  -text "Import CSV / Excel"  -width 18 -command {openImportSubjects}
    button .subject.clear   -text "Clear"               -width 10 -command {clearSubjectForm}
    button .subject.edit    -text "Edit Selected"       -width 13 -command {editSelectedSubject}
    button .subject.update  -text "Update Selected"     -width 15 -command {updateSelectedSubject}
    button .subject.refresh -text "Refresh"             -width 10 -command {refreshSubjectList}
    button .subject.delete  -text "Delete Selected"     -width 14 -command {deleteSelectedSubject}
    button .subject.close   -text "Close"                         -command {destroy .subject}

    foreach btn {.subject.add .subject.import .subject.clear .subject.edit .subject.update
                 .subject.refresh .subject.delete .subject.close} {
        pack $btn -in .subject.actions -side left -padx 5
    }

    # ── Treeview ──────────────────────────────────────────────────────────────
    frame .subject.tblframe -bg white
    pack  .subject.tblframe -fill both -expand 1 -padx 10 -pady 8

    set cols {SubjectID Name Code Department Credits Semester Faculty Type LabPeriods WeeklyHrs}
    ttk::style configure Subject.Treeview -font {Arial 9} -rowheight 25
    ttk::style configure Subject.Treeview.Heading \
        -font {Arial 9 bold} -background "#1565C0" -foreground white

    ttk::treeview .subject.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style Subject.Treeview \
        -yscrollcommand {.subject.tblframe.ys set} \
        -xscrollcommand {.subject.tblframe.xs set}

    scrollbar .subject.tblframe.ys -orient vertical   -command {.subject.tblframe.tree yview}
    scrollbar .subject.tblframe.xs -orient horizontal -command {.subject.tblframe.tree xview}

    .subject.tblframe.tree heading SubjectID  -text "ID"
    .subject.tblframe.tree heading Name       -text "Subject Name"
    .subject.tblframe.tree heading Code       -text "Code"
    .subject.tblframe.tree heading Department -text "Department"
    .subject.tblframe.tree heading Credits    -text "Cr"
    .subject.tblframe.tree heading Semester   -text "Sem"
    .subject.tblframe.tree heading Faculty    -text "Assigned Faculty"
    .subject.tblframe.tree heading Type       -text "Type"
    .subject.tblframe.tree heading LabPeriods -text "Lab Pd"
    .subject.tblframe.tree heading WeeklyHrs  -text "Wk Hrs"

    .subject.tblframe.tree column SubjectID  -width 40  -anchor center
    .subject.tblframe.tree column Name       -width 175 -anchor w
    .subject.tblframe.tree column Code       -width 80  -anchor w
    .subject.tblframe.tree column Department -width 110 -anchor w
    .subject.tblframe.tree column Credits    -width 35  -anchor center
    .subject.tblframe.tree column Semester   -width 40  -anchor center
    .subject.tblframe.tree column Faculty    -width 165 -anchor w
    .subject.tblframe.tree column Type       -width 70  -anchor center
    .subject.tblframe.tree column LabPeriods -width 55  -anchor center
    .subject.tblframe.tree column WeeklyHrs  -width 55  -anchor center

    .subject.tblframe.tree tag configure odd  -background "#F7FBFF"
    .subject.tblframe.tree tag configure even -background "#EAF3FC"
    .subject.tblframe.tree tag configure lab  -background "#E8F5E9"

    grid .subject.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .subject.tblframe.ys   -row 0 -column 1 -sticky ns
    grid .subject.tblframe.xs   -row 1 -column 0 -sticky ew
    grid rowconfigure    .subject.tblframe 0 -weight 1
    grid columnconfigure .subject.tblframe 0 -weight 1

    applyThemeToWindow .subject
    refreshSubjectList
}

# ── Form helpers ──────────────────────────────────────────────────────────────

proc subjectAutoFillWeeklyHours {} {
    set credits [string trim [.subject.form.e4 get]]
    set stype   [string trim [.subject.form.type get]]
    set sugg    [suggestWeeklyHours $credits $stype]
    if {$sugg ne ""} {
        .subject.form.wh delete 0 end
        .subject.form.wh insert 0 $sugg
    }
}

proc clearSubjectForm {} {
    global editingSubjectId
    set editingSubjectId ""
    .subject.form.e1     delete 0 end
    .subject.form.e2     delete 0 end
    .subject.form.e3     configure -values [loadSubjectDepartmentOptions]
    .subject.form.e3     set ""
    .subject.form.e4     set "3"
    .subject.form.e5     set ""
    .subject.form.faculty configure -values [loadFacultyOptions]
    .subject.form.faculty set ""
    .subject.form.type   set "Theory"
    .subject.form.lab    delete 0 end
    .subject.form.lab    insert 0 "3"
    .subject.form.wh     delete 0 end
    .subject.form.wh     insert 0 "3"
}

proc subjectOptionalInteger {value label} {
    set value [string trim $value]
    if {$value eq ""} { return "NULL" }
    if {![string is integer -strict $value]} {
        tk_messageBox -title "Validation Error" \
            -message "$label must be a whole number." -icon warning
        return "__INVALID__"
    }
    return $value
}

proc readSubjectForm {} {
    set name       [string trim [.subject.form.e1     get]]
    set code       [string trim [.subject.form.e2     get]]
    set dept       [string trim [.subject.form.e3     get]]
    set credits    [string trim [.subject.form.e4     get]]
    set sem        [string trim [.subject.form.e5     get]]
    set facOpt     [string trim [.subject.form.faculty get]]
    set stype      [string trim [.subject.form.type   get]]
    set lab_hours  [string trim [.subject.form.lab    get]]
    set weekly_hrs [string trim [.subject.form.wh     get]]

    if {$name eq ""} {
        tk_messageBox -title "Validation Error" \
            -message "Subject Name is required." -icon warning
        return "__INVALID__"
    }
    if {$stype eq ""} { set stype "Theory" }

    set faculty_id [facultyIdFromOption $facOpt]

    set credits    [subjectOptionalInteger $credits   "Credits"]
    if {$credits   eq "__INVALID__"} { return "__INVALID__" }
    set sem        [subjectOptionalInteger $sem        "Semester"]
    if {$sem       eq "__INVALID__"} { return "__INVALID__" }
    set lab_hours  [subjectOptionalInteger $lab_hours  "Lab Periods"]
    if {$lab_hours eq "__INVALID__"} { return "__INVALID__" }
    if {$lab_hours eq "NULL"} { set lab_hours 3 }

    # Weekly hours: fall back to suggestWeeklyHours if blank
    if {$weekly_hrs eq ""} {
        set weekly_hrs [suggestWeeklyHours $credits $stype]
    }
    set weekly_hrs [subjectOptionalInteger $weekly_hrs "Weekly Hours"]
    if {$weekly_hrs eq "__INVALID__"} { return "__INVALID__" }

    return [list \
        [string map {"'" "''"} $name] \
        [string map {"'" "''"} $code] \
        [string map {"'" "''"} $dept] \
        $credits $sem $faculty_id \
        [string map {"'" "''"} $stype] \
        $lab_hours $weekly_hrs]
}

# ── CRUD procs ────────────────────────────────────────────────────────────────

proc addSubject {} {
    global db
    set values [readSubjectForm]
    if {$values eq "__INVALID__"} { return }
    lassign $values escName escCode escDept credits sem faculty_id escType lab_hours weekly_hrs

    set sql "INSERT INTO subjects
                 (subject_name, subject_code, department, credits, semester,
                  faculty_id, subject_type, lab_hours, weekly_hours)
             VALUES
                 ('$escName','$escCode','$escDept',$credits,$sem,
                  $faculty_id,'$escType',$lab_hours,$weekly_hrs)"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" \
            -message "Failed to add subject:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Subject added successfully." -icon info
        clearSubjectForm
        refreshSubjectList
    }
}

proc selectedSubjectId {} {
    set sel [.subject.tblframe.tree selection]
    if {$sel eq ""} { return "" }
    return [lindex [.subject.tblframe.tree item $sel -values] 0]
}

proc editSelectedSubject {} {
    global db editingSubjectId
    set sid [selectedSubjectId]
    if {$sid eq ""} {
        tk_messageBox -title "Edit" -message "Select a subject row first." -icon info
        return
    }
    set found 0
    db eval "SELECT subject_name, subject_code, department,
                    COALESCE(credits,'')      AS credits,
                    COALESCE(semester,'')     AS semester,
                    COALESCE(faculty_id,'')   AS faculty_id,
                    COALESCE(subject_type,'Theory') AS subject_type,
                    COALESCE(lab_hours,3)     AS lab_hours,
                    COALESCE(weekly_hours,'') AS weekly_hours
             FROM subjects WHERE subject_id = $sid" row {
        set found 1
        clearSubjectForm
        set editingSubjectId $sid
        .subject.form.e1     insert 0 $row(subject_name)
        .subject.form.e2     insert 0 $row(subject_code)
        .subject.form.e3     set      $row(department)
        .subject.form.e4     set      $row(credits)
        .subject.form.e5     set      $row(semester)
        .subject.form.type   set      $row(subject_type)
        .subject.form.lab    delete 0 end
        .subject.form.lab    insert 0 $row(lab_hours)
        .subject.form.wh     delete 0 end
        .subject.form.wh     insert 0 $row(weekly_hours)
        # Fill faculty dropdown by ID
        if {$row(faculty_id) ne ""} {
            set facLabel [facultyOptionFromId $row(faculty_id)]
            .subject.form.faculty set $facLabel
        }
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Selected subject was not found." -icon warning
    }
}

proc updateSelectedSubject {} {
    global db editingSubjectId
    if {$editingSubjectId eq ""} { set editingSubjectId [selectedSubjectId] }
    if {$editingSubjectId eq ""} {
        tk_messageBox -title "Update" \
            -message "Select a row, then click Edit Selected." -icon info
        return
    }
    set values [readSubjectForm]
    if {$values eq "__INVALID__"} { return }
    lassign $values escName escCode escDept credits sem faculty_id escType lab_hours weekly_hrs

    set sql "UPDATE subjects
             SET subject_name='$escName', subject_code='$escCode', department='$escDept',
                 credits=$credits, semester=$sem, faculty_id=$faculty_id,
                 subject_type='$escType', lab_hours=$lab_hours, weekly_hours=$weekly_hrs
             WHERE subject_id = $editingSubjectId"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "Database Error" \
            -message "Could not update subject:\n$err" -icon error
        return
    }
    tk_messageBox -title "Success" -message "Subject updated successfully." -icon info
    clearSubjectForm
    refreshSubjectList
}

proc deleteSelectedSubject {} {
    global db
    set sid [selectedSubjectId]
    if {$sid eq ""} {
        tk_messageBox -title "Delete" -message "Select a subject row first." -icon info
        return
    }
    set sname ""
    db eval "SELECT subject_name FROM subjects WHERE subject_id = $sid" row {
        set sname $row(subject_name)
    }
    set confirm [tk_messageBox -title "Confirm Delete" \
        -message "Delete subject \"$sname\"?\nThis cannot be undone." \
        -icon question -type yesno]
    if {$confirm ne "yes"} { return }

    if {[catch {db eval "DELETE FROM subjects WHERE subject_id = $sid"} err]} {
        tk_messageBox -title "Database Error" \
            -message "Could not delete subject:\n$err" -icon error
        return
    }
    refreshSubjectList
}

proc refreshSubjectList {} {
    global db
    if {![winfo exists .subject.tblframe.tree]} { return }
    .subject.tblframe.tree delete [.subject.tblframe.tree children {}]

    set rowIdx 0
    db eval {
        SELECT s.subject_id, s.subject_name, s.subject_code, s.department,
               COALESCE(s.credits,'')       AS credits,
               COALESCE(s.semester,'')      AS semester,
               COALESCE(f.faculty_name,'—') AS faculty_name,
               COALESCE(s.subject_type,'Theory') AS subject_type,
               COALESCE(s.lab_hours,3)      AS lab_hours,
               COALESCE(s.weekly_hours,'')  AS weekly_hours
        FROM subjects s
        LEFT JOIN faculty f ON f.faculty_id = s.faculty_id
        ORDER BY s.department, s.semester, s.subject_name
    } row {
        set tag [expr {$rowIdx % 2 == 0 ? "even" : "odd"}]
        if {$row(subject_type) eq "Lab"} { set tag "lab" }
        .subject.tblframe.tree insert {} end -values [list \
            $row(subject_id)   $row(subject_name) $row(subject_code) \
            $row(department)   $row(credits)      $row(semester) \
            $row(faculty_name) $row(subject_type) $row(lab_hours) \
            $row(weekly_hours)] -tags $tag
        incr rowIdx
    }
}

# ── CSV / Excel Import Dialog ─────────────────────────────────────────────────

proc openImportSubjects {} {
    if {[winfo exists .importsubj]} { raise .importsubj ; return }

    toplevel .importsubj
    wm title .importsubj "Import Subjects from CSV / Excel"
    wm geometry .importsubj "660x540"
    wm resizable .importsubj 1 1
    .importsubj configure -bg white

    label .importsubj.title -text "IMPORT SUBJECTS FROM CSV / EXCEL" \
        -font {Arial 14 bold} -bg "#1565C0" -fg white
    pack .importsubj.title -fill x -pady 10

    # ── Info box ──────────────────────────────────────────────────────────────
    frame .importsubj.info -bg "#EAF3FC" -relief solid -bd 1
    pack  .importsubj.info -fill x -padx 14 -pady 4

    label .importsubj.info.txt \
        -justify left -bg "#EAF3FC" -font {Arial 9} -anchor w \
        -text "Supported formats: .csv  |  .xlsx (Excel — converted automatically via PowerShell)\
\nCSV columns (row 1 = header, skipped automatically):\
\n  subject_name, subject_code, department, credits, semester, subject_type, lab_hours, weekly_hours\
\nNotes:\
\n  • Faculty assignment is done MANUALLY after import using Edit Selected.\
\n  • subject_type: Theory / Lab / Blended  (default = Theory)\
\n  • weekly_hours auto-filled from credits/type if blank in file.\
\n  • Download the template below, fill in Excel, save as CSV or .xlsx, then import."
    pack .importsubj.info.txt -padx 10 -pady 8 -anchor w

    # ── File picker ───────────────────────────────────────────────────────────
    frame .importsubj.pick -bg white
    pack  .importsubj.pick -fill x -padx 14 -pady 8

    label .importsubj.pick.lbl -text "File :" -bg white
    pack  .importsubj.pick.lbl -side left

    entry .importsubj.pick.path -width 48
    pack  .importsubj.pick.path -side left -padx 6

    button .importsubj.pick.browse -text "Browse..." -width 10 \
        -command {
            set f [tk_getOpenFile \
                -parent .importsubj \
                -title  "Select CSV or Excel File" \
                -filetypes {
                    {"CSV / Excel Files" {.csv .xlsx .xls .txt}}
                    {"CSV Files"         {.csv .txt}}
                    {"Excel Files"       {.xlsx .xls}}
                    {"All Files"         *}
                }]
            if {$f ne ""} {
                .importsubj.pick.path delete 0 end
                .importsubj.pick.path insert 0 $f
            }
        }
    pack .importsubj.pick.browse -side left

    # ── Log area ──────────────────────────────────────────────────────────────
    frame .importsubj.logframe -bg white
    pack  .importsubj.logframe -fill both -expand 1 -padx 14 -pady 4

    label .importsubj.logframe.lbl -text "Import Log:" -bg white -anchor w
    pack  .importsubj.logframe.lbl -anchor w

    text .importsubj.logframe.log \
        -height 12 -wrap word -font {Consolas 9} \
        -state disabled -relief solid -bd 1
    scrollbar .importsubj.logframe.ys -orient vertical \
        -command {.importsubj.logframe.log yview}
    .importsubj.logframe.log configure \
        -yscrollcommand {.importsubj.logframe.ys set}
    pack .importsubj.logframe.ys  -side right -fill y
    pack .importsubj.logframe.log -side left  -fill both -expand 1

    # ── Buttons ───────────────────────────────────────────────────────────────
    frame .importsubj.btns -bg white
    pack  .importsubj.btns -pady 10

    button .importsubj.btns.template -text "Download Template" -width 18 \
        -command {downloadSubjectCsvTemplate}
    button .importsubj.btns.import   -text "Import Now"        -width 14 \
        -command {parseAndImportSubjectsCsv}
    button .importsubj.btns.close    -text "Close"             -width 10 \
        -command {destroy .importsubj}

    pack .importsubj.btns.template -side left -padx 8
    pack .importsubj.btns.import   -side left -padx 8
    pack .importsubj.btns.close    -side left -padx 8

    applyThemeToWindow .importsubj
}

proc subjImportLog {msg} {
    if {![winfo exists .importsubj.logframe.log]} { return }
    .importsubj.logframe.log configure -state normal
    .importsubj.logframe.log insert end "$msg\n"
    .importsubj.logframe.log see end
    .importsubj.logframe.log configure -state disabled
}

proc clearSubjImportLog {} {
    if {![winfo exists .importsubj.logframe.log]} { return }
    .importsubj.logframe.log configure -state normal
    .importsubj.logframe.log delete 1.0 end
    .importsubj.logframe.log configure -state disabled
}

# ── Template download ─────────────────────────────────────────────────────────

proc downloadSubjectCsvTemplate {} {
    set savePath [tk_getSaveFile \
        -parent .importsubj \
        -title  "Save Subject Template As" \
        -initialfile "subjects_template.csv" \
        -filetypes {{"CSV Files" {.csv}} {"All Files" *}}]
    if {$savePath eq ""} { return }

    if {[catch {
        set fh [open $savePath w]
        puts $fh "subject_name,subject_code,department,credits,semester,subject_type,lab_hours,weekly_hours"
        puts $fh "Data Structures,CS201,CSE,3,3,Theory,,3"
        puts $fh "Operating Systems,CS301,CSE,3,5,Theory,,3"
        puts $fh "Database Lab,CS302L,CSE,2,5,Lab,3,"
        puts $fh "Networks,CS401,CSE,4,7,Blended,3,5"
        puts $fh "Mathematics I,MA101,ECE,4,1,Theory,,4"
        close $fh
    } err]} {
        tk_messageBox -parent .importsubj -title "Error" \
            -message "Could not save template:\n$err" -icon error
        return
    }
    tk_messageBox -parent .importsubj -title "Template Saved" \
        -message "Template saved:\n$savePath\n\nOpen in Excel, fill your subjects,\nthen save as CSV (.csv) or keep as .xlsx and import." \
        -icon info
}

# ── Excel → CSV conversion via PowerShell (no extra installs needed) ─────────

proc convertExcelToCsv {xlsxPath} {
    # Returns path to a temp CSV, or "" on failure
    set tmpCsv [file join $::env(TEMP) "subj_import_[clock seconds].csv"]

    # PowerShell script: open Excel COM object, export first sheet as CSV
    set psScript [string map [list \
        __XLSX__ [string map {\ \\ \" \\\"} $xlsxPath] \
        __CSV__  [string map {\ \\ \" \\\"} $tmpCsv]] {
$ErrorActionPreference = 'Stop'
try {
    $xl = New-Object -ComObject Excel.Application
    $xl.Visible = $false
    $xl.DisplayAlerts = $false
    $wb = $xl.Workbooks.Open("__XLSX__")
    $ws = $wb.Sheets.Item(1)
    $wb.SaveAs("__CSV__", 6)   # 6 = xlCSV
    $wb.Close($false)
    $xl.Quit()
    Write-Output "OK"
} catch {
    Write-Error $_.Exception.Message
    exit 1
}
}]

    set tmpPs [file join $::env(TEMP) "subj_xlconv_[clock seconds].ps1"]
    catch {
        set fh [open $tmpPs w]
        puts $fh $psScript
        close $fh
    }

    set rc [catch {
        exec powershell.exe -ExecutionPolicy Bypass -NonInteractive \
            -File $tmpPs
    } out]

    catch { file delete $tmpPs }

    if {$rc != 0} {
        subjImportLog "Excel conversion failed: $out"
        subjImportLog "Tip: Save your Excel file as CSV first (File → Save As → CSV), then import the .csv file."
        return ""
    }
    return $tmpCsv
}

# ── CSV line splitter (handles quoted fields, same as faculty import) ─────────

proc splitSubjCsvLine {line} {
    set fields  {}
    set field   ""
    set inQuote 0
    set len [string length $line]
    for {set i 0} {$i < $len} {incr i} {
        set ch [string index $line $i]
        if {$inQuote} {
            if {$ch eq "\""} {
                set next [string index $line [expr {$i+1}]]
                if {$next eq "\""} { append field "\"" ; incr i } \
                else               { set inQuote 0 }
            } else { append field $ch }
        } else {
            if      {$ch eq "\""} { set inQuote 1 } \
            elseif  {$ch eq ","} {
                lappend fields [string trim $field]
                set field ""
            } else { append field $ch }
        }
    }
    lappend fields [string trim $field]
    return $fields
}

# ── Main import proc ──────────────────────────────────────────────────────────

proc parseAndImportSubjectsCsv {} {
    global db
    set rawPath [string trim [.importsubj.pick.path get]]

    if {$rawPath eq ""} {
        tk_messageBox -parent .importsubj -title "No File" \
            -message "Please select a CSV or Excel file first." -icon warning
        return
    }
    if {![file exists $rawPath]} {
        tk_messageBox -parent .importsubj -title "Not Found" \
            -message "File not found:\n$rawPath" -icon error
        return
    }

    clearSubjImportLog
    set csvPath $rawPath
    set tmpCreated 0

    # Convert Excel to CSV if needed
    set ext [string tolower [file extension $rawPath]]
    if {$ext eq ".xlsx" || $ext eq ".xls"} {
        subjImportLog "Excel file detected — converting via PowerShell..."
        set csvPath [convertExcelToCsv $rawPath]
        if {$csvPath eq ""} { return }
        set tmpCreated 1
        subjImportLog "Conversion OK → $csvPath"
    }

    subjImportLog "Reading: $csvPath"
    subjImportLog "---------------------------------------------------"

    if {[catch {
        set fh [open $csvPath r]
        set content [read $fh]
        close $fh
    } err]} {
        tk_messageBox -parent .importsubj -title "Read Error" \
            -message "Could not read file:\n$err" -icon error
        if {$tmpCreated} { catch { file delete $csvPath } }
        return
    }

    if {$tmpCreated} { catch { file delete $csvPath } }

    set lines   [split $content "\n"]
    set rowNum   0
    set imported 0
    set skipped  0
    set errors   0

    foreach rawLine $lines {
        incr rowNum
        set rawLine [string trimright $rawLine "\r"]
        if {[string trim $rawLine] eq ""} { continue }

        # Skip header row
        if {$rowNum == 1} {
            subjImportLog "Row 1 (header skipped): $rawLine"
            continue
        }

        set cols [splitSubjCsvLine $rawLine]
        while {[llength $cols] < 8} { lappend cols "" }

        set name       [string trim [lindex $cols 0]]
        set code       [string trim [lindex $cols 1]]
        set dept       [string trim [lindex $cols 2]]
        set credits    [string trim [lindex $cols 3]]
        set sem        [string trim [lindex $cols 4]]
        set stype      [string trim [lindex $cols 5]]
        set lab_hours  [string trim [lindex $cols 6]]
        set weekly_hrs [string trim [lindex $cols 7]]

        # Validate required
        if {$name eq ""} {
            subjImportLog "Row $rowNum SKIPPED : subject_name is empty"
            incr skipped ; continue
        }
        if {$dept eq ""} {
            subjImportLog "Row $rowNum SKIPPED : department is empty  (name=$name)"
            incr skipped ; continue
        }

        # Defaults
        if {$stype eq ""} { set stype "Theory" }
        if {$credits eq "" || ![string is integer -strict $credits]} { set credits "NULL" }
        if {$sem     eq "" || ![string is integer -strict $sem]}     { set sem     "NULL" }
        if {$lab_hours  eq "" || ![string is integer -strict $lab_hours]}  { set lab_hours 3 }
        if {$weekly_hrs eq ""} {
            set weekly_hrs [suggestWeeklyHours $credits $stype]
        }
        if {$weekly_hrs eq "" || ![string is integer -strict $weekly_hrs]} { set weekly_hrs "NULL" }

        set escName  [string map {"'" "''"} $name]
        set escCode  [string map {"'" "''"} $code]
        set escDept  [string map {"'" "''"} $dept]
        set escType  [string map {"'" "''"} $stype]

        set sql "INSERT INTO subjects
                     (subject_name, subject_code, department, credits, semester,
                      faculty_id, subject_type, lab_hours, weekly_hours)
                 VALUES
                     ('$escName','$escCode','$escDept',
                      $credits,$sem,NULL,
                      '$escType',$lab_hours,$weekly_hrs)"

        if {[catch {db eval $sql} err]} {
            subjImportLog "Row $rowNum ERROR   : $name — $err"
            incr errors
        } else {
            subjImportLog "Row $rowNum OK      : $name | $dept | Sem:$sem | $stype | Wk:$weekly_hrs"
            incr imported
        }
    }

    subjImportLog "---------------------------------------------------"
    subjImportLog "Done.  Imported: $imported   Skipped: $skipped   Errors: $errors"
    subjImportLog "(Faculty assignment: open Subject Management → select row → Edit Selected → pick faculty → Update Selected)"

    if {$imported > 0} {
        if {[winfo exists .subject.tblframe.tree]} { refreshSubjectList }
    }
}
