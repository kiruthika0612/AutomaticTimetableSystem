proc openDashboard {} {
    global currentUser currentRole APP_BG APP_PANEL APP_TEXT APP_MUTED APP_PRIMARY APP_PRIMARY_DARK APP_ACCENT APP_DANGER

    foreach w [winfo children .] {
        destroy $w
    }

    wm title . "Admin Dashboard"
    wm geometry . "1200x820"
    catch {wm state . zoomed}
    . configure -bg $APP_BG

    makePageHeader . "AUTOMATIC TIMETABLE MANAGEMENT SYSTEM" "Smart academic scheduling dashboard"

    frame .content -bg $APP_BG
    pack .content -fill both -expand 1 -padx 34 -pady 22

    frame .welcomeCard -bg $APP_PANEL -bd 0 -relief flat
    pack .welcomeCard -in .content -fill x -pady {0 18}

    frame .welcomeCard.left -bg $APP_PANEL
    pack .welcomeCard.left -side left -fill both -expand 1 -padx 24 -pady 18

    label .welcomeCard.left.title \
        -text "Welcome, $currentUser" \
        -font {Arial 22 bold} \
        -bg $APP_PANEL \
        -fg $APP_TEXT \
        -anchor w
    pack .welcomeCard.left.title -fill x

    label .welcomeCard.left.subtitle \
        -text "Build department-wise, section-wise and lab-aware timetables with clear reports." \
        -font {Arial 11} \
        -bg $APP_PANEL \
        -fg $APP_MUTED \
        -anchor w
    pack .welcomeCard.left.subtitle -fill x -pady {6 0}

    frame .welcomeCard.right -bg $APP_PANEL
    pack .welcomeCard.right -side right -padx 24 -pady 18

    label .welcomeCard.right.role \
        -text "Role: $currentRole" \
        -font {Arial 10 bold} \
        -bg $APP_ACCENT \
        -fg white \
        -padx 14 \
        -pady 8
    pack .welcomeCard.right.role -side left -padx {0 12}

    button .welcomeCard.right.logout \
        -text "Logout" \
        -command openLogin \
        -bg $APP_DANGER \
        -fg white \
        -activebackground "#991B1B" \
        -activeforeground white \
        -relief flat \
        -bd 0 \
        -width 10 \
        -font {Arial 10 bold} \
        -cursor hand2
    pack .welcomeCard.right.logout -side left

    label .sectionTitle \
        -text "Quick Actions" \
        -font {Arial 15 bold} \
        -bg $APP_BG \
        -fg $APP_PRIMARY_DARK \
        -anchor w
    pack .sectionTitle -in .content -fill x -pady {0 8}

    frame .menu -bg $APP_BG
    pack .menu -in .content -fill both -expand 1

    set items {
        {.cardUsers    "User Management"         "Create admin and faculty accounts"        users      "#0F4C81" openUserManagement}
        {.cardDept     "Departments / Sections"  "Maintain branches and class sections"     department "#F59E0B" openDepartmentManagement}
        {.cardFaculty  "Faculty Management"      "Store faculty details and department"     faculty    "#16A34A" openFacultyManagement}
        {.cardSubject  "Subject Management"      "Add theory and 3-period lab subjects"     subject    "#0F4C81" openSubjectManagement}
        {.cardRoom     "Classroom Management"    "Manage rooms, labs and capacity"          room       "#475569" openClassroomManagement}
        {.cardBreak    "Break Time"              "Set year-wise breaks and lunch"           break      "#F59E0B" openBreaktimeManagement}
        {.cardPeriod   "Period Settings"         "Configure year-wise 45 minute periods"    settings   "#475569" openSettings}
        {.cardLeave    "Faculty Leave"           "Record faculty leave details"             leave      "#16A34A" openLeaveManagement}
        {.cardTimetable "Generate Timetable"     "Create class and lab schedule"            timetable  "#0F4C81" openTimetableGenerator}
        {.cardEditor   "Timetable Editor"        "Edit, swap and lock timetable slots"      timetable  "#1565C0" openTimetableEditor}
        {.cardFacHours "Assign Faculty to Hours" "Decide which staff handles each period"   faculty    "#16A34A" openFacultyHourAssignment}
        {.cardClash    "Clash Detection"         "Find faculty, room and section clashes"   clash      "#DC2626" openClashDetection}
        {.cardReports  "Reports"                 "View and export generated data"           reports    "#F59E0B" openReports}
    }

    set row 0
    set col 0
    foreach item $items {
        lassign $item path title desc icon color command
        createDashboardCard $path $title $desc $icon $color $command
        grid $path -in .menu -row $row -column $col -padx 10 -pady 10 -sticky nsew
        incr col
        if {$col == 4} {
            set col 0
            incr row
        }
    }

    for {set i 0} {$i < 4} {incr i} {
        grid columnconfigure .menu $i -weight 1 -uniform cards
    }
}

proc createDashboardCard {path title desc iconFile color command} {
    global APP_PANEL APP_TEXT APP_MUTED APP_PRIMARY

    frame $path -bg $APP_PANEL -bd 1 -relief solid -height 96
    grid propagate $path 0

    frame $path.strip -bg $color -width 6
    pack $path.strip -side left -fill y

    set icon [loadAppIcon "${path}_icon" $iconFile]
    if {$icon ne ""} {
        label $path.icon -image $icon -bg $APP_PANEL
    } else {
        label $path.icon -text "" -bg $APP_PANEL -width 6
    }
    pack $path.icon -side left -padx {14 12}

    frame $path.text -bg $APP_PANEL
    pack $path.text -side left -fill both -expand 1 -pady 16

    label $path.text.title \
        -text $title \
        -font {Arial 11 bold} \
        -bg $APP_PANEL \
        -fg $APP_TEXT \
        -anchor w
    pack $path.text.title -fill x

    label $path.text.desc \
        -text $desc \
        -font {Arial 9} \
        -bg $APP_PANEL \
        -fg $APP_MUTED \
        -anchor w
    pack $path.text.desc -fill x -pady {6 0}

    bindDashboardClick $path $command
}

proc bindDashboardClick {widget command} {
    bind $widget <Button-1> [list eval $command]
    bind $widget <Enter> [list dashboardCardHover $widget 1]
    bind $widget <Leave> [list dashboardCardHover $widget 0]
    catch {$widget configure -cursor hand2}
    foreach child [winfo children $widget] {
        bindDashboardClick $child $command
    }
}

proc dashboardCardHover {widget active} {
    set bg "#FFFFFF"
    if {$active} {
        set bg "#F8FBFF"
    }
    catch {$widget configure -bg $bg}
    foreach child [winfo children $widget] {
        if {[winfo class $child] ne "Frame" || ![string match "*.strip" $child]} {
            catch {$child configure -bg $bg}
        }
        foreach grand [winfo children $child] {
            catch {$grand configure -bg $bg}
        }
    }
}
