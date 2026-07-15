proc setupDatabase {} {
    global db

    db eval {
        CREATE TABLE IF NOT EXISTS users (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT NOT NULL,
            password TEXT NOT NULL,
            role TEXT NOT NULL
        )
    }

    db eval {
        CREATE TABLE IF NOT EXISTS faculty (
            faculty_id INTEGER PRIMARY KEY AUTOINCREMENT,
            faculty_name TEXT,
            department TEXT,
            designation TEXT,
            email TEXT,
            phone TEXT,
            hours_allotted INTEGER
        )
    }
    ensureColumn faculty hours_allotted INTEGER

    db eval {
        CREATE TABLE IF NOT EXISTS subjects (
            subject_id INTEGER PRIMARY KEY AUTOINCREMENT,
            subject_name TEXT NOT NULL,
            subject_code TEXT,
            department TEXT,
            credits INTEGER,
            semester INTEGER,
            faculty_id INTEGER,
            subject_type TEXT,
            lab_hours INTEGER
        )
    }
    ensureColumn subjects subject_type TEXT
    ensureColumn subjects lab_hours INTEGER
    ensureColumn subjects weekly_hours INTEGER
    db eval {UPDATE subjects SET subject_type = 'Theory' WHERE subject_type IS NULL OR trim(subject_type) = ''}
    db eval {UPDATE subjects SET lab_hours = 3 WHERE lab_hours IS NULL}
    db eval {UPDATE subjects SET weekly_hours = credits WHERE weekly_hours IS NULL AND credits IS NOT NULL}

    db eval {
        CREATE TABLE IF NOT EXISTS classrooms (
            classroom_id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_number TEXT NOT NULL,
            name TEXT,
            building TEXT,
            capacity INTEGER,
            department TEXT,
            lab_location TEXT
        )
    }
    ensureColumn classrooms lab_location TEXT

    db eval {
        CREATE TABLE IF NOT EXISTS breaktimes (
            break_id INTEGER PRIMARY KEY AUTOINCREMENT,
            year TEXT,
            break_name TEXT NOT NULL,
            start_time TEXT,
            end_time TEXT
        )
    }

    db eval {
        CREATE TABLE IF NOT EXISTS departments (
            department_id INTEGER PRIMARY KEY AUTOINCREMENT,
            department_name TEXT NOT NULL UNIQUE,
            short_name TEXT,
            description TEXT
        )
    }

    db eval {
        CREATE TABLE IF NOT EXISTS sections (
            section_id INTEGER PRIMARY KEY AUTOINCREMENT,
            department TEXT NOT NULL,
            year TEXT,
            section_name TEXT NOT NULL
        )
    }

    db eval {
        CREATE TABLE IF NOT EXISTS leaves (
            leave_id INTEGER PRIMARY KEY AUTOINCREMENT,
            faculty_id INTEGER,
            faculty_name TEXT,
            leave_date TEXT,
            reason TEXT
        )
    }

    db eval {
        CREATE TABLE IF NOT EXISTS settings (
            setting_key TEXT PRIMARY KEY,
            setting_value TEXT
        )
    }

    db eval {
        CREATE TABLE IF NOT EXISTS periods (
            period_id INTEGER PRIMARY KEY AUTOINCREMENT,
            year TEXT,
            period_number INTEGER,
            start_time TEXT,
            end_time TEXT
        )
    }
    ensureColumn periods year TEXT

    db eval {
        CREATE TABLE IF NOT EXISTS timetables (
            timetable_id INTEGER PRIMARY KEY AUTOINCREMENT,
            semester INTEGER,
            year TEXT,
            department TEXT,
            section TEXT,
            notes TEXT,
            generated_at TEXT
        )
    }

    db eval {
        CREATE TABLE IF NOT EXISTS timetable_slots (
            slot_id INTEGER PRIMARY KEY AUTOINCREMENT,
            timetable_id INTEGER,
            day_of_week TEXT,
            period_number INTEGER,
            slot_type TEXT,
            start_time TEXT,
            subject_name TEXT,
            staff_name TEXT,
            department TEXT,
            section TEXT,
            classroom TEXT,
            remarks TEXT
        )
    }

    ensureColumn timetables department TEXT
    ensureColumn timetables section TEXT
    ensureColumn timetable_slots section TEXT
    ensureColumn users can_edit_timetable INTEGER
    db eval {UPDATE users SET can_edit_timetable = 1 WHERE role = 'Admin' AND (can_edit_timetable IS NULL)}
    db eval {UPDATE users SET can_edit_timetable = 0 WHERE can_edit_timetable IS NULL}
    ensureColumn timetable_slots modified_by TEXT
    ensureColumn timetable_slots locked INTEGER
    db eval {UPDATE timetable_slots SET locked = 0 WHERE locked IS NULL}

    # Fix corrupt break/period times stored in 12-hour single-digit format
    # e.g. "1:15" should be "13:15", "3:30" should be "15:30"
    fixCorruptTimes

    set userCount 0
    db eval {SELECT COUNT(*) AS total FROM users} row {
        set userCount $row(total)
    }
    if {$userCount == 0} {
        db eval {INSERT INTO users(username, password, role) VALUES('admin', 'admin123', 'Admin')}
    }

    set periodCount 0
    db eval {SELECT COUNT(*) AS total FROM periods} row {
        set periodCount $row(total)
    }
    if {$periodCount == 0} {
        db eval {
            INSERT INTO periods(year, period_number, start_time, end_time) VALUES
            ('All Years', 1, '08:30', '09:15'),
            ('All Years', 2, '09:15', '10:00'),
            ('All Years', 3, '10:00', '10:45'),
            ('All Years', 4, '11:00', '11:45'),
            ('All Years', 5, '11:45', '12:30'),
            ('All Years', 6, '13:15', '14:00'),
            ('All Years', 7, '14:00', '14:45'),
            ('All Years', 8, '15:00', '15:45'),
            ('All Years', 9, '15:45', '16:30')
        }
    } else {
        db eval {UPDATE periods SET year = 'All Years' WHERE year IS NULL OR trim(year) = ''}
    }
}

proc ensureColumn {table column type} {
    global db
    set found 0
    db eval "PRAGMA table_info($table)" row {
        if {$row(name) eq $column} {
            set found 1
        }
    }
    if {!$found} {
        db eval "ALTER TABLE $table ADD COLUMN $column $type"
    }
}

# =============================================================================
#  resetTableSequence  — call after any DELETE to keep IDs clean.
#
#  If the table is now empty  → removes the row from sqlite_sequence entirely
#    so the next INSERT starts from 1.
#  If rows still exist        → sets the sequence to MAX(id) so the next
#    INSERT continues from max+1 with no gaps.
#
#  Usage:
#    resetTableSequence faculty     faculty_id
#    resetTableSequence timetables  timetable_id
# =============================================================================
proc resetTableSequence {tableName idColumn} {
    global db

    # sqlite_sequence only exists if the table has ever used AUTOINCREMENT
    catch {
        set remaining 0
        db eval "SELECT COUNT(*) AS n FROM $tableName" r { set remaining $r(n) }

        if {$remaining == 0} {
            # Table is empty — remove sequence entry so next ID = 1
            db eval "DELETE FROM sqlite_sequence WHERE name = '$tableName'"
        } else {
            # Rows still exist — set sequence to current max so no gaps
            set maxId 0
            db eval "SELECT MAX($idColumn) AS m FROM $tableName" r {
                if {$r(m) ne ""} { set maxId $r(m) }
            }
            db eval "UPDATE sqlite_sequence SET seq = $maxId WHERE name = '$tableName'"
        }
    }
}

# =============================================================================
#  fixCorruptTimes
#  Corrects break and period times that were stored in single-digit 12-hour
#  format (e.g. "1:15" instead of "13:15", "3:30" instead of "15:30").
#  Runs once at startup — safe to run multiple times (idempotent).
# =============================================================================
proc fixCorruptTimes {} {
    global db

    # Fix breaktimes table
    db eval {SELECT break_id, start_time, end_time FROM breaktimes} bRow {
        set newStart [fixTimeValue $bRow(start_time)]
        set newEnd   [fixTimeValue $bRow(end_time)]
        if {$newStart ne $bRow(start_time) || $newEnd ne $bRow(end_time)} {
            set escS [string map {"'" "''"} $newStart]
            set escE [string map {"'" "''"} $newEnd]
            db eval "UPDATE breaktimes
                     SET start_time='$escS', end_time='$escE'
                     WHERE break_id=$bRow(break_id)"
        }
    }

    # Fix periods table
    db eval {SELECT period_id, start_time, end_time FROM periods} pRow {
        set newStart [fixTimeValue $pRow(start_time)]
        set newEnd   [fixTimeValue $pRow(end_time)]
        if {$newStart ne $pRow(start_time) || $newEnd ne $pRow(end_time)} {
            set escS [string map {"'" "''"} $newStart]
            set escE [string map {"'" "''"} $newEnd]
            db eval "UPDATE periods
                     SET start_time='$escS', end_time='$escE'
                     WHERE period_id=$pRow(period_id)"
        }
    }
}

# -----------------------------------------------------------------------------
#  fixTimeValue — converts a single-digit-hour 12-hour time to 24-hour.
#  "1:15" -> "13:15",  "2:00" -> "14:00",  "3:45" -> "15:45"
#  Times already in correct HH:MM format (e.g. "08:30") are returned as-is.
# -----------------------------------------------------------------------------
proc fixTimeValue {t} {
    set t [string trim $t]
    # Already correct two-digit hour format — leave alone
    if {[regexp {^([0-9][0-9]):([0-9][0-9])$} $t -> h m]} {
        return $t
    }
    # Single-digit hour — e.g. "1:15", "2:00", "3:30", "4:45"
    if {[regexp {^([0-9]):([0-9][0-9])$} $t -> h m]} {
        scan $h %d hour
        scan $m %d min
        # Afternoon single-digit hours (1-5) → add 12
        if {$hour >= 1 && $hour <= 5} {
            set hour [expr {$hour + 12}]
        }
        return [format "%02d:%02d" $hour $min]
    }
    # Can't parse — return as-is
    return $t
}
