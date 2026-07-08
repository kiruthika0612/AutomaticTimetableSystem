proc openUserManagement {} {
    global newUsername newPassword newRole editingUserId APP_BG APP_PANEL APP_TEXT APP_MUTED

    if {[winfo exists .userManagement]} {
        raise .userManagement
        return
    }

    set newUsername ""
    set newPassword ""
    set newRole "Admin"
    set editingUserId ""

    toplevel .userManagement
    wm title .userManagement "User Management"
    wm geometry .userManagement "700x560"
    .userManagement configure -bg $APP_BG

    label .userManagement.title \
        -text "USER MANAGEMENT" \
        -font {Arial 16 bold} \
        -bg "#0F4C81" \
        -fg white
    pack .userManagement.title -fill x -pady {0 18}

    frame .userManagement.panel -bg $APP_PANEL -bd 1 -relief solid
    pack .userManagement.panel -padx 45 -pady 10 -fill x

    label .userManagement.panel.hint \
        -text "Create login accounts for admin and faculty users" \
        -font {Arial 9} \
        -bg $APP_PANEL \
        -fg $APP_MUTED
    grid .userManagement.panel.hint -row 0 -column 0 -columnspan 2 -pady {22 10}

    label .userManagement.panel.userlbl \
        -text "Username :" \
        -font {Arial 11 bold} \
        -bg $APP_PANEL \
        -fg $APP_TEXT
    grid .userManagement.panel.userlbl -row 1 -column 0 -padx {28 10} -pady 8 -sticky e

    entry .userManagement.panel.username \
        -textvariable newUsername \
        -width 28 \
        -font {Arial 10} \
        -relief solid \
        -bd 1
    grid .userManagement.panel.username -row 1 -column 1 -padx {10 28} -pady 8 -ipady 4

    label .userManagement.panel.passlbl \
        -text "Password :" \
        -font {Arial 11 bold} \
        -bg $APP_PANEL \
        -fg $APP_TEXT
    grid .userManagement.panel.passlbl -row 2 -column 0 -padx {28 10} -pady 8 -sticky e

    entry .userManagement.panel.password \
        -textvariable newPassword \
        -show "*" \
        -width 28 \
        -font {Arial 10} \
        -relief solid \
        -bd 1
    grid .userManagement.panel.password -row 2 -column 1 -padx {10 28} -pady 8 -ipady 4

    label .userManagement.panel.rolelbl \
        -text "Role :" \
        -font {Arial 11 bold} \
        -bg $APP_PANEL \
        -fg $APP_TEXT
    grid .userManagement.panel.rolelbl -row 3 -column 0 -padx {28 10} -pady 8 -sticky e

    ttk::combobox .userManagement.panel.role \
        -textvariable newRole \
        -values {"Admin" "Faculty"} \
        -width 26
    grid .userManagement.panel.role -row 3 -column 1 -padx {10 28} -pady 8 -sticky w

    frame .userManagement.panel.actions -bg $APP_PANEL
    grid .userManagement.panel.actions -row 4 -column 0 -columnspan 2 -pady {18 24}

    makeAccentButton .userManagement.panel.actions.add "Add User" addUser
    pack .userManagement.panel.actions.add -side left -padx 6

    makeAccentButton .userManagement.panel.actions.edit "Edit Selected" editSelectedUser
    pack .userManagement.panel.actions.edit -side left -padx 6

    makeAccentButton .userManagement.panel.actions.update "Update Selected" updateSelectedUser
    pack .userManagement.panel.actions.update -side left -padx 6

    makeAccentButton .userManagement.panel.actions.refresh "Refresh" refreshUserList
    pack .userManagement.panel.actions.refresh -side left -padx 6

    makeDangerButton .userManagement.panel.actions.delete "Delete Selected" deleteSelectedUser
    pack .userManagement.panel.actions.delete -side left -padx 6

    makeDangerButton .userManagement.panel.actions.close "Close" {destroy .userManagement}
    pack .userManagement.panel.actions.close -side left -padx 6

    listbox .userManagement.list -width 80 -height 10
    pack .userManagement.list -fill both -expand 1 -padx 45 -pady 10

    focus .userManagement.panel.username
    refreshUserList
}

proc clearUserForm {} {
    global newUsername newPassword newRole editingUserId
    set editingUserId ""
    set newUsername ""
    set newPassword ""
    set newRole "Admin"
}

proc addUser {} {
    global db newUsername newPassword newRole

    if {$newUsername eq "" || $newPassword eq "" || $newRole eq ""} {
        tk_messageBox \
            -title "Validation" \
            -message "Please fill all fields." \
            -icon warning
        return
    }

    set escUsername [string map {"'" "''"} $newUsername]
    set escPassword [string map {"'" "''"} $newPassword]
    set escRole [string map {"'" "''"} $newRole]

    if {[catch {
        db eval "INSERT INTO users(username,password,role) VALUES('$escUsername','$escPassword','$escRole')"
    } err]} {
        tk_messageBox -title "Database Error" -message "User could not be added:\n$err" -icon error
        return
    }

    tk_messageBox \
        -title "Success" \
        -message "User added successfully." \
        -icon info

    clearUserForm
    refreshUserList
}

proc selectedUserId {} {
    set sel [.userManagement.list curselection]
    if {$sel eq ""} {
        return ""
    }

    set line [.userManagement.list get $sel]
    if {[regexp {^([0-9]+) \|} $line -> userId]} {
        return $userId
    }
    return ""
}

proc editSelectedUser {} {
    global db newUsername newPassword newRole editingUserId
    set userId [selectedUserId]
    if {$userId eq ""} {
        tk_messageBox -title "Edit" -message "Select a user row." -icon info
        return
    }

    set found 0
    db eval "SELECT username, password, role FROM users WHERE id = $userId" row {
        set found 1
        set editingUserId $userId
        set newUsername $row(username)
        set newPassword $row(password)
        set newRole $row(role)
    }
    if {!$found} {
        tk_messageBox -title "Edit" -message "Selected user was not found." -icon warning
    }
}

proc updateSelectedUser {} {
    global db newUsername newPassword newRole editingUserId
    if {$editingUserId eq ""} {
        set editingUserId [selectedUserId]
    }
    if {$editingUserId eq ""} {
        tk_messageBox -title "Update" -message "Select a user row, then click Edit Selected." -icon info
        return
    }
    if {$newUsername eq "" || $newPassword eq "" || $newRole eq ""} {
        tk_messageBox -title "Validation" -message "Please fill all fields." -icon warning
        return
    }

    set oldRole ""
    db eval "SELECT role FROM users WHERE id = $editingUserId" row {
        set oldRole $row(role)
    }
    if {$oldRole eq "Admin" && $newRole ne "Admin"} {
        set adminCount 0
        db eval {SELECT COUNT(*) AS total FROM users WHERE role = 'Admin'} row {
            set adminCount $row(total)
        }
        if {$adminCount <= 1} {
            tk_messageBox -title "Update" -message "Cannot change the last Admin user to Faculty." -icon warning
            return
        }
    }

    set escUsername [string map {"'" "''"} $newUsername]
    set escPassword [string map {"'" "''"} $newPassword]
    set escRole [string map {"'" "''"} $newRole]

    if {[catch {
        db eval "UPDATE users SET username='$escUsername', password='$escPassword', role='$escRole' WHERE id = $editingUserId"
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
    if {![winfo exists .userManagement.list]} {
        return
    }

    .userManagement.list delete 0 end
    db eval {SELECT id, username, role FROM users ORDER BY username} row {
        .userManagement.list insert end "[format {%d | %s | %s} $row(id) $row(username) $row(role)]"
    }
}

proc deleteSelectedUser {} {
    global db
    set userId [selectedUserId]
    if {$userId eq ""} {
        tk_messageBox -title "Delete" -message "Select a user row." -icon info
        return
    }

    set selectedRole ""
    db eval "SELECT role FROM users WHERE id = $userId" row {
        set selectedRole $row(role)
    }

    if {$selectedRole eq "Admin"} {
        set adminCount 0
        db eval {SELECT COUNT(*) AS total FROM users WHERE role = 'Admin'} row {
            set adminCount $row(total)
        }
        if {$adminCount <= 1} {
            tk_messageBox -title "Delete" -message "Cannot delete the last Admin user." -icon warning
            return
        }
    }

    if {[catch {db eval "DELETE FROM users WHERE id = $userId"} err]} {
        tk_messageBox -title "Database Error" -message "Could not delete user:\n$err" -icon error
        return
    }

    refreshUserList
}
