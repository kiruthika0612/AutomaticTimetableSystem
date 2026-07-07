set APP_PRIMARY "#0F4C81"
set APP_PRIMARY_DARK "#0B355A"
set APP_ACCENT "#F59E0B"
set APP_BG "#EEF4FA"
set APP_PANEL "#FFFFFF"
set APP_TEXT "#1F2937"
set APP_MUTED "#64748B"
set APP_DANGER "#DC2626"

proc initTheme {} {
    global APP_BG APP_PRIMARY APP_PRIMARY_DARK APP_ACCENT APP_TEXT

    option add *Font {Arial 10}
    option add *Background $APP_BG
    option add *Foreground $APP_TEXT
    option add *activeBackground $APP_PRIMARY_DARK
    option add *activeForeground white

    catch {
        ttk::style theme use clam
        ttk::style configure TCombobox -padding 4
        ttk::style configure Treeview -rowheight 24
        ttk::style configure TEntry -padding 4
        ttk::style configure TButton -padding {10 6}
    }

    if {[file exists "images/college_logo.png"]} {
        catch {
            image create photo app_window_icon -file "images/college_logo.png"
            wm iconphoto . -default app_window_icon
        }
    }
}

proc loadCollegeLogo {imageName {subsample 5}} {
    set safeName [string map {. _ " " _} $imageName]
    if {[file exists "images/college_logo.png"]} {
        catch {image delete $safeName}
        catch {image delete ${safeName}_source}
        if {![catch {image create photo ${safeName}_source -file "images/college_logo.png"}]} {
            image create photo $safeName
            $safeName copy ${safeName}_source -subsample $subsample $subsample
            image delete ${safeName}_source
            return $safeName
        }
    }
    return ""
}

proc loadAppIcon {imageName fileName} {
    set safeName [string map {. _ " " _} $imageName]
    set path "icons/$fileName.png"
    if {[file exists $path]} {
        catch {image delete $safeName}
        if {![catch {image create photo $safeName -file $path}]} {
            return $safeName
        }
    }
    return ""
}

proc makePageHeader {parent title {subtitle ""}} {
    global APP_PRIMARY APP_PRIMARY_DARK APP_ACCENT APP_PANEL APP_TEXT APP_MUTED

    if {$parent eq "."} {
        set header ".header"
    } else {
        set header "$parent.header"
    }

    frame $header -bg $APP_PRIMARY -height 132
    pack $header -fill x
    pack propagate $header 0

    frame $header.logoBox -bg $APP_PANEL -width 250 -height 112
    pack $header.logoBox -side left -padx {22 20} -pady 14
    pack propagate $header.logoBox 0

    set logo [loadCollegeLogo "${parent}_logo" 4]
    if {$logo ne ""} {
        label $header.logoBox.logo -image $logo -bg $APP_PANEL
        pack $header.logoBox.logo -expand 1
    }

    frame $header.text -bg $APP_PRIMARY
    pack $header.text -side left -fill both -expand 1

    frame $header.text.accent -bg $APP_ACCENT -height 5
    pack $header.text.accent -fill x -pady {18 10}

    label $header.text.title \
        -text $title \
        -font {Arial 23 bold} \
        -bg $APP_PRIMARY \
        -fg white \
        -anchor w
    pack $header.text.title -fill x

    if {$subtitle ne ""} {
        label $header.text.subtitle \
            -text $subtitle \
            -font {Arial 12 bold} \
            -bg $APP_PRIMARY \
            -fg "#DDEBFA" \
            -anchor w
        pack $header.text.subtitle -fill x -pady {8 0}
    }

    frame $header.rightBar -bg $APP_PRIMARY_DARK -width 18
    pack $header.rightBar -side right -fill y
}

proc makePrimaryButton {path text command} {
    global APP_PRIMARY APP_PRIMARY_DARK
    button $path \
        -text $text \
        -command $command \
        -bg $APP_PRIMARY \
        -fg white \
        -activebackground $APP_PRIMARY_DARK \
        -activeforeground white \
        -relief flat \
        -bd 0 \
        -width 24 \
        -font {Arial 10 bold} \
        -cursor hand2
}

proc makeMenuButton {path text iconFile command} {
    global APP_PANEL APP_TEXT APP_PRIMARY
    set icon [loadAppIcon "${path}_icon" $iconFile]
    button $path \
        -text $text \
        -command $command \
        -bg $APP_PANEL \
        -fg $APP_TEXT \
        -activebackground "#E8F1FA" \
        -activeforeground $APP_PRIMARY \
        -relief flat \
        -bd 0 \
        -width 32 \
        -anchor w \
        -compound left \
        -padx 14 \
        -font {Arial 10 bold} \
        -cursor hand2
    if {$icon ne ""} {
        $path configure -image $icon
    }
}

proc makeAccentButton {path text command} {
    global APP_ACCENT
    button $path \
        -text $text \
        -command $command \
        -bg $APP_ACCENT \
        -fg white \
        -activebackground "#D97706" \
        -activeforeground white \
        -relief flat \
        -bd 0 \
        -width 24 \
        -font {Arial 10 bold} \
        -cursor hand2
}

proc makeDangerButton {path text command} {
    global APP_DANGER
    button $path \
        -text $text \
        -command $command \
        -bg $APP_DANGER \
        -fg white \
        -activebackground "#991B1B" \
        -activeforeground white \
        -relief flat \
        -bd 0 \
        -width 24 \
        -font {Arial 10 bold} \
        -cursor hand2
}

proc applyThemeToWindow {root} {
    global APP_BG APP_PANEL APP_TEXT APP_PRIMARY APP_PRIMARY_DARK APP_ACCENT APP_DANGER

    catch {$root configure -bg $APP_BG}
    foreach widget [winfo children $root] {
        applyThemeToWidget $widget
    }
}

proc applyThemeToWidget {widget} {
    global APP_BG APP_PANEL APP_TEXT APP_PRIMARY APP_PRIMARY_DARK APP_ACCENT APP_DANGER

    set class [winfo class $widget]
    if {$class eq "Frame"} {
        catch {$widget configure -bg $APP_BG}
    } elseif {$class eq "Label"} {
        set labelText ""
        catch {set labelText [$widget cget -text]}
        if {[string match {*MANAGEMENT*} $labelText] || [string match {*REPORTS*} $labelText] || [string match {*SETTINGS*} $labelText] || [string match {*TIMETABLE*} $labelText] || [string match {*DETECTION*} $labelText]} {
            catch {$widget configure -bg $APP_PRIMARY -fg white -font {Arial 16 bold}}
        } else {
            catch {$widget configure -bg $APP_BG -fg $APP_TEXT}
        }
    } elseif {$class eq "Button"} {
        set buttonText ""
        catch {set buttonText [$widget cget -text]}
        set color $APP_PRIMARY
        set active $APP_PRIMARY_DARK
        if {[string match -nocase {*delete*} $buttonText] || [string match -nocase {*close*} $buttonText] || [string match -nocase {*exit*} $buttonText] || [string match -nocase {*logout*} $buttonText]} {
            set color $APP_DANGER
            set active "#991B1B"
        } elseif {[string match -nocase {*generate*} $buttonText] || [string match -nocase {*save*} $buttonText] || [string match -nocase {*add*} $buttonText] || [string match -nocase {*view*} $buttonText] || [string match -nocase {*export*} $buttonText]} {
            set color $APP_ACCENT
            set active "#D97706"
        }
        catch {$widget configure -bg $color -fg white -activebackground $active -activeforeground white -relief flat -bd 0 -font {Arial 10 bold} -cursor hand2}
    } elseif {$class eq "Entry"} {
        catch {$widget configure -bg white -fg $APP_TEXT -relief solid -bd 1 -font {Arial 10}}
    } elseif {$class eq "Text" || $class eq "Listbox"} {
        catch {$widget configure -bg white -fg $APP_TEXT -relief solid -bd 1 -font {Consolas 10}}
    }

    foreach child [winfo children $widget] {
        applyThemeToWidget $child
    }
}
