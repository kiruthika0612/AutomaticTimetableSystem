proc openUserManagement {} {
    global newUsername newPassword newRole APP_BG APP_PANEL APP_TEXT APP_MUTED

    if {[winfo exists .userManagement]} {
        raise .userManagement
        return
    }

    set newUsername ""
    set newPassword ""
    set newRole "Admin"

    toplevel .userManagement
    wm title .userManagement "User Management"
    wm geometry .userManagement "560x460"
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

    makeDangerButton .userManagement.panel.actions.close "Close" {destroy .userManagement}
    pack .userManagement.panel.actions.close -side left -padx 6

    focus .userManagement.panel.username
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

    set newUsername ""
    set newPassword ""
    set newRole "Admin"
}
