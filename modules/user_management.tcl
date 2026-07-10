# ─────────────────────────────────────────────────────────────────────────────
#  User Management Module
#  - Roles: Admin / Faculty
#  - Permission: "Edit Timetable" (can_edit_timetable column)
#    Admin users always have this permission; Faculty users can be granted it.
# ─────────────────────────────────────────────────────────────────────────────

proc openUserManagement {} {
    global newUsername newPassword newRole newCanEditTimetable editingUserId
    global APP_BG APP_PANEL APP_TEXT APP_MUTED

    if {[winfo exists .userManagement]} { raise .userManagement ; return }

    set newUsername        ""
    set newPassword        ""
    set newRole            "Admin"
    set newCanEditTimetable 1
    set editingUserId      ""

    toplevel .userManagement
    wm title .userManagement "User Management"
    wm geometry .userManagement "760x600"
    .userManagement configure -bg $APP_BG

    label .userManagement.title \
        -text "USER MANAGEMENT" -font {Arial 16 bold} \
        -bg "#0F4C81" -fg white
    pack .userManagement.title -fill x -pady {0 18}

    frame .userManagement.panel -bg $APP_PANEL -bd 1 -relief solid
    pack  .userManagement.panel -padx 45 -pady 10 -fill x

    label .userManagement.panel.hint \
        -text "Create login accounts for admin and faculty users" \
        -font {Arial 9} -bg $APP_PANEL -fg $APP_MUTED
    grid .userManagement.panel.hint -row 0 -column 0 -columnspan 2 -pady {22 10}

    # Username
    label .userManagement.panel.userlbl \
        -text "Username :" -font {Arial 11 bold} -bg $APP_PANEL -fg $APP_TEXT
    grid .userManagement.panel.userlbl -row 1 -column 0 -padx {28 10} -pady 8 -sticky e
    entry .userManagement.panel.username \
        -textvariable newUsername -width 28 -font {Arial 10} -relief solid -bd 1
    grid .userManagement.panel.username -row 1 -column 1 -padx {10 28} -pady 8 -ipady 4

    # Password
    label .userManagement.panel.passlbl \
        -text "Password :" -font {Arial 11 bold} -bg $APP_PANEL -fg $APP_TEXT
    grid .userManagement.panel.passlbl -row 2 -column 0 -padx {28 10} -pady 8 -sticky e
    entry .userManagement.panel.password \
        -textvariable newPassword -show "*" -width 28 -font {Arial 10} -relief solid -bd 1
    grid .userManagement.panel.password -row 2 -column 1 -padx {10 28} -pady 8 -ipady 4

    # Role
    label .userManagement.panel.rolelbl \
        -text "Role :" -font {Arial 11 bold} -bg $APP_PANEL -fg $APP_TEXT
    grid .userManagement.panel.rolelbl -row 3 -column 0 -padx {28 10} -pady 8 -sticky e
    ttk::combobox .userManagement.panel.role \
        -textvariable newRole -values {"Admin" "Faculty"} -width 26
    grid .userManagement.panel.role -row 3 -column 1 -padx {10 28} -pady 8 -sticky w

    # Auto-set permission when role changes
    bind .userManagement.panel.role <<ComboboxSelected>> {
        if {$newRole eq "Admin"} { set newCanEditTimetable 1 }
    }

    # Edit Timetable permission
    label .userManagement.panel.permlbl \
        -text "Permissions :" -font {Arial 11 bold} -bg $APP_PANEL -fg $APP_TEXT
    grid .userManagement.panel.permlbl -row 4 -column 0 -padx {28 10} -pady 8 -sticky e

    frame .userManagement.panel.permframe -bg $APP_PANEL
    grid  .userManagement.panel.permframe -row 4 -column 1 -padx {10 28} -pady 8 -sticky w

    checkbutton .userManagement.panel.permframe.editTT \
        -text "Edit Timetable" \
        -variable newCanEditTimetable \
        -font {Arial 10} \
        -bg $APP_PANEL -fg $APP_TEXT \
        -activebackground $APP_PANEL \
        -relief flat
    pack .userManagement.panel.permframe.editTT -side left

    label .userManagement.panel.permframe.hint \
        -text "(can generate, edit, delete timetable entries)" \
        -font {Arial 8} -bg $APP_PANEL -fg $APP_MUTED
    pack .userManagement.panel.permframe.hint -side left -padx 6

    # Buttons
    frame .userManagement.panel.actions -bg $APP_PANEL
    grid  .userManagement.panel.actions -row 5 -column 0 -columnspan 2 -pady {18 24}

    makeAccentButton .userManagement.panel.actions.add    "Add User"        addUser
    makeAccentButton .userManagement.panel.actions.edit   "Edit Selected"   editSelectedUser
    makeAccentButton .userManagement.panel.actions.update "Update Selected" updateSelectedUser
    makeAccentButton .userManagement.panel.actions.refresh "Refresh"        refreshUserList
    makeDangerButton .userManagement.panel.actions.delete "Delete Selected" deleteSelectedUser
    makeDangerButton .userManagement.panel.actions.close  "Close"           {destroy .userManagement}

    foreach btn {add edit update refresh delete close} {
        pack .userManagement.panel.actions.$btn -side left -padx 6
    }

    # ── Treeview ──────────────────────────────────────────────────────────────
    frame .userManagement.tblframe -bg $APP_BG
    pack  .userManagement.tblframe -fill both -expand 1 -padx 45 -pady 10

    set cols {UserID Username Role EditTimetable}
    ttk::style configure User.Treeview -font {Arial 10} -rowheight 26
    ttk::style configure User.Treeview.Heading \
        -font {Arial 10 bold} -background "#0F4C81" -foreground white

    ttk::treeview .userManagement.tblframe.tree \
        -columns $cols -show headings -selectmode browse \
        -style User.Treeview \
        -yscrollcommand {.userManagement.tblframe.ys set}

    scrollbar .userManagement.tblframe.ys -orient vertical \
        -command {.userManagement.tblframe.tree yview}

    .userManagement.tblframe.tree heading UserID        -text "ID"
    .userManagement.tblframe.tree heading Username      -text "Username"
    .userManagement.tblframe.tree heading Role          -text "Role"
    .userManagement.tblframe.tree heading EditTimetable -text "Edit Timetable"

    .userManagement.tblframe.tree column UserID        -width 50  -anchor center
    .userManagement.tblframe.tree column Username      -width 220 -anchor w
    .userManagement.tblframe.tree column Role          -width 100 -anchor center
    .userManagement.tblframe.tree column EditTimetable -width 110 -anchor center

    .userManagement.tblframe.tree tag configure admin    -background "#EAF3FC"
    .userManagement.tblframe.tree tag configure faculty  -background "#F7FBFF"
    .userManagement.tblframe.tree tag configure hasperms -foreground "#14532D"

    grid .userManagement.tblframe.tree -row 0 -column 0 -sticky nsew
    grid .userManagement.tblframe.ys   -row 0 -column 1 -sticky ns
    grid rowconfigure    .userManagement.tblframe 0 -weight 1
    grid columnconfigure .userManagement.tblframe 0 -weight 1

    focus .userManagement.panel.username
    refreshUserList
}

proc clearUserForm {} {
    global newUsername newPassword newRole newCanEditTimetable editingUserId
    set editingUserId       ""
    set newUsername         ""
    set newPassword         ""
    set newRole             "Admin"
    set newCanEditTimetable 1
}

proc addUser {} {
    global db newUsername newPassword newRole newCanEditTimetable

    if {$newUsername eq "" || $newPassword eq "" || $newRole eq ""} {
        tk_messageBox -title "Validation" -message "Please fill all fields." -icon warning
        return
    }

    # Admin always gets edit timetable permission
    set perm $newCanEditTimetable
    if {$newRole eq "Admin"} { set perm 1 }

    set escU [string map {"'" "''"} $newUsername]
    set escP [string map {"'" "''"} $newPassword]
    set escR [string map {"'" "''"} $newRole]

    if {[catch {
        db eval "INSERT INTO users(username,password,role,can_edit_timetable)
                 VALUES('$escU','$escP','$escR',$perm)"
    } err]} {
        tk_messageBox -title "Database Error" -message "User could not be added:\n$err" -icon error
        return
    }
    tk_messageBox -title "Success" -message "User added successfully." -icon info
    clearUserForm
    refreshUserList
}

proc selectedUserId {} {
    if {![winfo exists .userManagement.tblframe.tree]} { return "" }
    set sel [.userManagement.tblframe.tree selection]
    if {$sel eq ""} { return "" }
    return [lindex [.userManagement.tblframe.tree item $sel -values] 0]
}

proc editSelectedUser {} {
    global db newUsername newPassword newRole newCanEditTimetable editingUserId
    set userId [selectedUserId]
    if {$userId eq ""} {
        tk_messageBox -title "Edit" -message "Select a user row." -icon info
        return
    }
    set found 0
    db eval "SELECT username, password, role,
                    COALESCE(can_edit_timetable,0) AS can_edit_timetable
             FROM users WHERE id = $userId" row {
        set found 1
        set editingUserId       $userId
        set newUsername         $row(username)
        set newPassword         $row(password)
        set newRole             $row(role)
        set newCanEditTimetable $row(can_edit_timetable)
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Selected user was not found." -icon warning
    }
}

proc updateSelectedUser {} {
    global db newUsername newPassword newRole newCanEditTimetable editingUserId
    if {$editingUserId eq ""} { set editingUserId [selectedUserId] }
    if {$editingUserId eq ""} {
        tk_messageBox -title "Update" \
            -message "Select a user row, then click Edit Selected." -icon info
        return
    }
    if {$newUsername eq "" || $newPassword eq "" || $newRole eq ""} {
        tk_messageBox -title "Validation" -message "Please fill all fields." -icon warning
        return
    }

    # Guard: don't demote the last Admin
    set oldRole ""
    db eval "SELECT role FROM users WHERE id = $editingUserId" row { set oldRole $row(role) }
    if {$oldRole eq "Admin" && $newRole ne "Admin"} {
        set adminCount 0
        db eval {SELECT COUNT(*) AS total FROM users WHERE role = 'Admin'} row {
            set adminCount $row(total)
        }
        if {$adminCount <= 1} {
            tk_messageBox -title "Update" \
                -message "Cannot change the last Admin user to Faculty." -icon warning
            return
        }
    }

    set perm $newCanEditTimetable
    if {$newRole eq "Admin"} { set perm 1 }

    set escU [string map {"'" "''"} $newUsername]
    set escP [string map {"'" "''"} $newPassword]
    set escR [string map {"'" "''"} $newRole]

    if {[catch {
        db eval "UPDATE users
                 SET username='$escU', password='$escP', role='$escR',
                     can_edit_timetable=$perm
                 WHERE id = $editingUserId"
    } err]} {
        tk_messageBox -title "Database Error" -message "User could not be updated:\n$err" -icon error
        return
    }
    tk_messageBox -title "Success" -message "User updated successfully." -icon info
    clearUserForm
    refreshUserList
}

proc refreshUserList {} {
    global db
    if {![winfo exists .userManagement.tblframe.tree]} { return }
    .userManagement.tblframe.tree delete [.userManagement.tblframe.tree children {}]
    db eval {SELECT id, username, role,
                    COALESCE(can_edit_timetable,0) AS can_edit_timetable
             FROM users ORDER BY username} row {
        set tag [expr {$row(role) eq "Admin" ? "admin" : "faculty"}]
        set permLabel [expr {$row(can_edit_timetable) ? "Yes" : "No"}]
        .userManagement.tblframe.tree insert {} end \
            -values [list $row(id) $row(username) $row(role) $permLabel] \
            -tags $tag
    }
}

proc deleteSelectedUser {} {
    global db
    set userId [selectedUserId]
    if {$userId eq ""} {
        tk_messageBox -title "Delete" -message "Select a user row." -icon info
        return
    }
    set selRole ""
    db eval "SELECT role FROM users WHERE id = $userId" row { set selRole $row(role) }
    if {$selRole eq "Admin"} {
        set adminCount 0
        db eval {SELECT COUNT(*) AS total FROM users WHERE role = 'Admin'} row {
            set adminCount $row(total)
        }
        if {$adminCount <= 1} {
            tk_messageBox -title "Delete" \
                -message "Cannot delete the last Admin user." -icon warning
            return
        }
    }
    if {[catch {db eval "DELETE FROM users WHERE id = $userId"} err]} {
        tk_messageBox -title "Database Error" -message "Could not delete user:\n$err" -icon error
        return
    }
    refreshUserList
}
