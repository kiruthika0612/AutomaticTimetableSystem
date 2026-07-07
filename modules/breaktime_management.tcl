# modules/breaktime_management.tcl
# Break times stored per year; UI allows selecting year to view/add.

proc openBreaktimeManagement {} {
    if {[winfo exists .breaktime]} {
        raise .breaktime
        return
    }
    toplevel .breaktime
    wm title .breaktime "Break Time Management"
    wm geometry .breaktime "520x360"
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
    button .breaktime.close -text "Close" -command {destroy .breaktime}
    pack .breaktime.close -in .breaktime.actions -side left -padx 6

    # List and filter
    frame .breaktime.listf -bg white
    pack .breaktime.listf -fill both -expand 1 -padx 8 -pady 8
    listbox .breaktime.list -width 70 -height 8
    pack .breaktime.list -in .breaktime.listf -fill both -expand 1
    frame .breaktime.listctrl -bg white
    pack .breaktime.listctrl -pady 6
    button .breaktime.refresh -text "Refresh List" -command {refreshBreaktimeList}
    pack .breaktime.refresh -in .breaktime.listctrl -side left -padx 6
    button .breaktime.delete -text "Delete Selected" -command {deleteSelectedBreak} 
    pack .breaktime.delete -in .breaktime.listctrl -side left -padx 6

    applyThemeToWindow .breaktime
    refreshBreaktimeList
}

proc clearBreaktimeForm {} {
    .breaktime.form.e1 delete 0 end
    .breaktime.form.e2 delete 0 end
    .breaktime.form.e3 delete 0 end
}

proc addBreaktime {} {
    global db
    set year [.breaktime.form.year get]
    set name [.breaktime.form.e1 get]
    set start [.breaktime.form.e2 get]
    set end   [.breaktime.form.e3 get]

    if {$year eq "" || $name eq ""} {
        tk_messageBox -title "Validation" -message "Year and Break name are required." -icon warning
        return
    }

    set escYear [string map {"'" "''"} $year]
    set escName [string map {"'" "''"} $name]
    set escStart [string map {"'" "''"} $start]
    set escEnd [string map {"'" "''"} $end]

    set sql "INSERT INTO breaktimes (year, break_name, start_time, end_time) VALUES ('$escYear','$escName','$escStart','$escEnd')"
    if {[catch {db eval $sql} err]} {
        tk_messageBox -title "DB Error" -message "Failed to add break:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Break added for year $year." -icon info
        clearBreaktimeForm
        refreshBreaktimeList
    }
}

proc refreshBreaktimeList {} {
    global db
    .breaktime.list delete 0 end
    set year [.breaktime.form.year get]
    if {$year eq ""} {
        set sql {SELECT break_id, year, break_name, start_time, end_time FROM breaktimes ORDER BY year, start_time}
        if {[catch {db eval $sql} err]} {
            .breaktime.list insert end "Error reading breaktimes: $err"
            return
        }
        db eval $sql {
            .breaktime.list insert end "[format {%d | %s | %s | %s - %s} $row(break_id) $row(year) $row(break_name) $row(start_time) $row(end_time)]"
        }
    } else {
        set escYear [string map {"'" "''"} $year]
        set sql "SELECT break_id, year, break_name, start_time, end_time FROM breaktimes WHERE year = '$escYear' ORDER BY start_time"
        if {[catch {db eval $sql} err]} {
            .breaktime.list insert end "Error reading breaktimes: $err"
            return
        }
        db eval $sql {
            .breaktime.list insert end "[format {%d | %s | %s | %s - %s} $row(break_id) $row(year) $row(break_name) $row(start_time) $row(end_time)]"
        }
    }
}

proc deleteSelectedBreak {} {
    global db
    set selIndex [.breaktime.list curselection]
    if {$selIndex eq ""} {
        tk_messageBox -title "Delete" -message "Select a break to delete." -icon info
        return
    }
    set line [.breaktime.list get $selIndex]
    # line format: id | year | name | start - end
    regexp {^([0-9]+) \|} $line -> bid
    if {$bid eq ""} {
        tk_messageBox -title "Delete" -message "Could not parse selection." -icon error
        return
    }
    if {![tk_messageBox -type yesno -icon question -title "Confirm" -message "Delete break ID $bid ?"]} { return }
    if {[catch {db eval "DELETE FROM breaktimes WHERE break_id = $bid"} err]} {
        tk_messageBox -title "DB Error" -message "Delete failed:\n$err" -icon error
    } else {
        tk_messageBox -title "Success" -message "Deleted." -icon info
        refreshBreaktimeList
    }
}
