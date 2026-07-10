# modules/breaktime_management.tcl
# Break times stored per year; UI allows selecting year to view/add.

proc openBreaktimeManagement {} {
    global editingBreakId
    set editingBreakId ""

    if {[winfo exists .breaktime]} {
        raise .breaktime
        return
    }
    toplevel .breaktime
    wm title .breaktime "Break Time Management"
    wm geometry .breaktime "620x420"
    .breaktime configure -bg white

    label .breaktime.title -text "BREAK TIME MANAGEMENT" -font {Arial 16 bold} -bg "#1565C0" -fg white
    pack .breaktime.title -fill x -pady 10

    frame .breaktime.form -bg white
    pack .breaktime.form -pady 8

    # Year selector (academic year level)
    set years {"1st Year" "2nd Year" "3rd Year" "4th Year"}

    label .breaktime.form.ly -text "Year :" -bg white
    grid .breaktime.form.ly -row 0 -column 0 -padx 8 -pady 5 -sticky e
    ttk::combobox .breaktime.form.year -values $years -width 12
    .breaktime.form.year set "1st Year"
    grid .breaktime.form.year -row 0 -column 1 -padx 8 -sticky w

    label .breaktime.form.l1 -text "Break Name :" -bg white
    grid .breaktime.form.l1 -row 1 -column 0 -padx 8 -pady 5 -sticky e
    entry .breaktime.form.e1 -width 30
    grid .breaktime.form.e1 -row 1 -column 1 -padx 8

    label .breaktime.form.l2 -text "Start Time (HH:MM) :" -bg white
    grid .breaktime.form.l2 -row 2 -column 0 -padx 8 -pady 5 -sticky e
    entry .breaktime.form.e2 -width 12
    grid .breaktime.form.e2 -row 2 -column 1 -padx 8 -sticky w

    label .breaktime.form.l3 -text "End Time (HH:MM) :" -bg white
    grid .breaktime.form.l3 -row 3 -column 0 -padx 8 -pady 5 -sticky e
    entry .breaktime.form.e3 -width 12
    grid .breaktime.form.e3 -row 3 -column 1 -padx 8 -sticky w

    frame .breaktime.actions -bg white
    pack .breaktime.actions -pady 12

    button .breaktime.add -text "Add Break" -width 12 -command {addBreaktime}
    pack .breaktime.add -in .breaktime.actions -side left -padx 6
    button .breaktime.clear -text "Clear" -width 10 -command {clearBreaktimeForm}
    pack .breaktime.clear -in .breaktime.actions -side left -padx 6
    button .breaktime.edit -text "Edit Selected" -width 13 -command {editSelectedBreak}
    pack .breaktime.edit -in .breaktime.actions -side left -padx 6
    button .breaktime.update -text "Update Selected" -width 15 -command {updateSelectedBreak}
    pack .breaktime.update -in .breaktime.actions -side left -padx 6
    button .breaktime.refresh -text "Refresh" -width 10 -command {refreshBreaktimeList}
    pack .breaktime.refresh -in .breaktime.actions -side left -padx 6
    button .breaktime.delete -text "Delete Selected" -width 14 -command {deleteSelectedBreak}
    pack .breaktime.delete -in .breaktime.actions -side left -padx 6
    button .breaktime.close -text "Close" -command {destroy .breaktime}
    pack .breaktime.close -in .breaktime.actions -side left -padx 6

    # ── Treeview ──────────────────────────────────────────────────────────────
    frame .breaktime.tblframe -bg white
    pack  .breaktime.tblframe -fill both -expand 1 -padx 8 -pady 8

    set cols {BreakID Year BreakName StartTime EndTime}
    ttk::style configure Break.Treeview -font {Arial 10} -rowheight 26
    ttk::style configure Break.Treeview.Heading \
        -font {Arial 10 bold} -background "#1565C0" -foreground white

    ttk::treeview .breaktime.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style Break.Treeview \
        -yscrollcommand {.breaktime.tblframe.ys set}

    scrollbar .breaktime.tblframe.ys -orient vertical \
        -command {.breaktime.tblframe.tree yview}

    .breaktime.tblframe.tree heading BreakID   -text "ID"
    .breaktime.tblframe.tree heading Year      -text "Year"
    .breaktime.tblframe.tree heading BreakName -text "Break Name"
    .breaktime.tblframe.tree heading StartTime -text "Start"
    .breaktime.tblframe.tree heading EndTime   -text "End"

    .breaktime.tblframe.tree column BreakID   -width 50  -anchor center
    .breaktime.tblframe.tree column Year      -width 120 -anchor center
    .breaktime.tblframe.tree column BreakName -width 200 -anchor w
    .breaktime.tblframe.tree column StartTime -width 90  -anchor center
    .breaktime.tblframe.tree column EndTime   -width 90  -anchor center

    .breaktime.tblframe.tree tag configure odd  -background "#F7FBFF"
    .breaktime.tblframe.tree tag configure even -background "#FFF3E0"

    grid .breaktime.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .breaktime.tblframe.ys   -row 0 -column 1 -sticky ns
    grid rowconfigure    .breaktime.tblframe 0 -weight 1
    grid columnconfigure .breaktime.tblframe 0 -weight 1

    applyThemeToWindow .breaktime
    refreshBreaktimeList
}

proc clearBreaktimeForm {} {
    global editingBreakId
    set editingBreakId ""
    .breaktime.form.e1 delete 0 end
    .breaktime.form.e2 delete 0 end
    .breaktime.form.e3 delete 0 end
}

proc readBreaktimeForm {} {
    set year [string trim [.breaktime.form.year get]]
    set name [string trim [.breaktime.form.e1 get]]
    set start [string trim [.breaktime.form.e2 get]]
    set end   [string trim [.breaktime.form.e3 get]]

    if {$year eq "" || $name eq ""} {
        tk_messageBox -title "Validation" -message "Year and Break name are required." -icon warning
        return "__INVALID__"
    }

    set start [validateBreakClockTime $start "Start Time"]
    if {$start eq ""} { return "__INVALID__" }
    set end [validateBreakClockTime $end "End Time"]
    if {$end eq ""} { return "__INVALID__" }

    set escYear [string map {"'" "''"} $year]
    set escName [string map {"'" "''"} $name]
    set escStart [string map {"'" "''"} $start]
    set escEnd [string map {"'" "''"} $end]

    return [list $escYear $escName $escStart $escEnd $year]
}

proc addBreaktime {} {
    global db
    set values [readBreaktimeForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values escYear escName escStart escEnd year

    set sql "INSERT INTO breaktimes (year, break_name, start_time, end_time) VALUES ('$escYear','$escName','$escStart','$escEnd')"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "DB Error" -message "Failed to add break:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Break added for year $year." -icon info
        clearBreaktimeForm
        refreshBreaktimeList
    }
}

proc selectedBreakId {} {
    if {![winfo exists .breaktime.tblframe.tree]} { return "" }
    set sel [.breaktime.tblframe.tree selection]
    if {$sel eq ""} { return "" }
    return [lindex [.breaktime.tblframe.tree item $sel -values] 0]
}

proc editSelectedBreak {} {
    global db editingBreakId
    set breakId [selectedBreakId]
    if {$breakId eq ""} {
        tk_messageBox -title "Edit" -message "Select a break row." -icon info
        return
    }

    set found 0
    db eval "SELECT year, break_name, start_time, end_time FROM breaktimes WHERE break_id = $breakId" row {
        set found 1
        clearBreaktimeForm
        set editingBreakId $breakId
        .breaktime.form.year set $row(year)
        .breaktime.form.e1 insert 0 $row(break_name)
        .breaktime.form.e2 insert 0 $row(start_time)
        .breaktime.form.e3 insert 0 $row(end_time)
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Selected break was not found." -icon warning
    }
}

proc updateSelectedBreak {} {
    global db editingBreakId
    if {$editingBreakId eq ""} {
        set editingBreakId [selectedBreakId]
    }
    if {$editingBreakId eq ""} {
        tk_messageBox -title "Update" -message "Select a break row, then click Edit Selected." -icon info
        return
    }

    set values [readBreaktimeForm]
    if {$values eq "__INVALID__"} {
        return
    }
    lassign $values escYear escName escStart escEnd year

    set sql "UPDATE breaktimes SET year='$escYear', break_name='$escName', start_time='$escStart', end_time='$escEnd' WHERE break_id = $editingBreakId"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "DB Error" -message "Could not update break:\n$err" -icon error
        return
    }

    tk_messageBox -title "Success" -message "Break updated." -icon info
    clearBreaktimeForm
    refreshBreaktimeList
}

proc validateBreakClockTime {timeValue label} {
    set timeValue [string trim $timeValue]
    if {![regexp {^([0-9][0-9]):([0-9][0-9])$} $timeValue -> hour minute]} {
        tk_messageBox -title "Validation" -message "$label must use 24-hour HH:MM format. Example: 13:15, not 1:15." -icon warning
        return ""
    }

    scan $hour %d hour
    scan $minute %d minute
    if {$hour < 0 || $hour > 23 || $minute < 0 || $minute > 59} {
        tk_messageBox -title "Validation" -message "$label must be a valid 24-hour time." -icon warning
        return ""
    }

    return [format "%02d:%02d" $hour $minute]
}

proc refreshBreaktimeList {} {
    global db
    if {![winfo exists .breaktime.tblframe.tree]} { return }
    .breaktime.tblframe.tree delete [.breaktime.tblframe.tree children {}]

    set year [.breaktime.form.year get]
    if {$year eq ""} {
        set sql {SELECT break_id, year, break_name, start_time, end_time
                 FROM breaktimes ORDER BY year, start_time}
    } else {
        set escYear [string map {"'" "''"} $year]
        set sql "SELECT break_id, year, break_name, start_time, end_time
                 FROM breaktimes WHERE year = '$escYear' ORDER BY start_time"
    }

    set rowIdx 0
    if {[catch {
        db eval $sql row {
            set tag [expr {$rowIdx % 2 == 0 ? "even" : "odd"}]
            .breaktime.tblframe.tree insert {} end \
                -values [list $row(break_id) $row(year) \
                    $row(break_name) $row(start_time) $row(end_time)] \
                -tags $tag
            incr rowIdx
        }
    } err]} {
        .breaktime.tblframe.tree insert {} end \
            -values [list "" "" "Error reading breaks: $err" "" ""]
    }
}

proc deleteSelectedBreak {} {
    global db
    set bid [selectedBreakId]
    if {$bid eq ""} {
        tk_messageBox -title "Delete" -message "Select a break to delete." -icon info
        return
    }
    if {[tk_messageBox -type yesno -icon question -title "Confirm" \
            -message "Delete this break?"] ne "yes"} { return }
    if {[catch {db eval "DELETE FROM breaktimes WHERE break_id = $bid"} err]} {
        tk_messageBox -title "DB Error" -message "Delete failed:\n$err" -icon error
    } else {
        clearBreaktimeForm
        refreshBreaktimeList
    }
}
