package require Tk
package require sqlite3
package require Ttk

sqlite3 db "database/college.db"

source database/database.tcl
source modules/ui_theme.tcl
source modules/login.tcl
source modules/user_management.tcl
source modules/department.tcl
source modules/faculty_management.tcl
source modules/subject_management.tcl
source modules/classroom_management.tcl
source modules/breaktime_management.tcl
source modules/settings.tcl
source modules/leave.tcl
source modules/timetable.tcl
source modules/clash_detection.tcl
source modules/reports.tcl
source modules/dashboard.tcl

setupDatabase
initTheme
openLogin

tkwait window .
