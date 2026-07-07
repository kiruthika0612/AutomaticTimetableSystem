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
            phone TEXT
        )
    }

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
    db eval {UPDATE subjects SET subject_type = 'Theory' WHERE subject_type IS NULL OR trim(subject_type) = ''}
    db eval {UPDATE subjects SET lab_hours = 3 WHERE lab_hours IS NULL}

    db eval {
        CREATE TABLE IF NOT EXISTS classrooms (
            classroom_id INTEGER PRIMARY KEY AUTOINCREMENT,
            room_number TEXT NOT NULL,
            name TEXT,
            building TEXT,
            capacity INTEGER,
            department TEXT
        )
    }

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
