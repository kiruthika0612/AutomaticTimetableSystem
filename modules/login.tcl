proc openLogin {} {
    global username password APP_BG APP_PANEL APP_TEXT APP_MUTED

    foreach w [winfo children .] {
        destroy $w
    }

    set username ""
    set password ""

    wm title . "Automatic Timetable Management System"
    wm geometry . "920x560"
    . configure -bg $APP_BG

    makePageHeader . "AUTOMATIC TIMETABLE MANAGEMENT SYSTEM" "College timetable planning and scheduling"

    frame .loginWrap -bg $APP_BG
    pack .loginWrap -fill both -expand 1

    frame .login -bg $APP_PANEL -bd 1 -relief solid
    pack .login -in .loginWrap -pady 55

    label .login.userlbl \
        -text "Username :" \
        -font {Arial 12 bold} \
        -bg $APP_PANEL \
        -fg $APP_TEXT
    grid .login.userlbl -row 1 -column 0 -padx {34 10} -pady {28 10} -sticky e

    entry .login.user -textvariable username -width 28 -font {Arial 11} -relief solid -bd 1
    grid .login.user -row 1 -column 1 -padx {10 34} -pady {28 10} -ipady 4

    label .login.passlbl \
        -text "Password :" \
        -font {Arial 12 bold} \
        -bg $APP_PANEL \
        -fg $APP_TEXT
    grid .login.passlbl -row 2 -column 0 -padx {34 10} -pady 10 -sticky e

    entry .login.pass -textvariable password -show "*" -width 28 -font {Arial 11} -relief solid -bd 1
    grid .login.pass -row 2 -column 1 -padx {10 34} -pady 10 -ipady 4

    label .login.hint \
        -text "Use your admin or faculty account" \
        -font {Arial 9} \
        -bg $APP_PANEL \
        -fg $APP_MUTED
    grid .login.hint -row 0 -column 0 -columnspan 2 -pady {24 0}

    makePrimaryButton .login.loginBtn "Login" checkLogin
    makeDangerButton .login.exitBtn "Exit" exit

    grid .login.loginBtn -row 3 -column 0 -padx {34 10} -pady {22 30}
    grid .login.exitBtn -row 3 -column 1 -padx {10 34} -pady {22 30}

    bind .login.user <Return> {focus .login.pass}
    bind .login.pass <Return> {checkLogin}
    focus .login.user
}

proc checkLogin {} {
    global db username password currentUser currentRole

    set found 0
    set escUser [string map {"'" "''"} $username]
    set escPass [string map {"'" "''"} $password]

    db eval "SELECT username, role FROM users WHERE username = '$escUser' AND password = '$escPass' LIMIT 1" row {
        set found 1
        set currentUser $row(username)
        set currentRole $row(role)
    }

    if {$found} {
        openDashboard
    } else {
        tk_messageBox \
            -title "Login Failed" \
            -message "Invalid Username or Password"
    }
}
