import sqlite3
import os


DB_PATH = os.path.join(
    os.path.dirname(__file__),
    "evidence.db"
)


def get_connection():
    return sqlite3.connect(DB_PATH)


# ============================================================
# DATABASE INITIALIZATION
# ============================================================



    # --------------------------------------------------------
    # Emergency Contacts Table
    # --------------------------------------------------------

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS emergency_contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id)
    )
    """)

    conn.commit()
    conn.close()


# ============================================================
# USER TABLE MIGRATION
# ============================================================

def migrate_users_table():

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        "PRAGMA table_info(users)"
    )

    columns = [
        row[1]
        for row in cursor.fetchall()
    ]

    if "vault_pin_hash" not in columns:

        cursor.execute(
            """
            ALTER TABLE users
            ADD COLUMN vault_pin_hash TEXT
            """
        )

    conn.commit()
    conn.close()


# ============================================================
# EVIDENCE FUNCTIONS
# ============================================================

def insert_evidence(
    user_id,
    evidence_id,
    filename,
    sha256,
    upload_time,
    storage_path,
    status,
    violence_detected=False,
    violence_probability=0.0,
    knife_detected=False,
    gun_detected=False,
    danger_detected=False
):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    INSERT INTO evidence
    (
        user_id,
        evidence_id,
        filename,
        sha256,
        upload_time,
        storage_path,
        status,
        violence_detected,
        violence_probability,
        knife_detected,
        gun_detected,
        danger_detected
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    """, (
        user_id,
        evidence_id,
        filename,
        sha256,
        upload_time,
        storage_path,
        status,
        int(violence_detected),
        float(violence_probability),
        int(knife_detected),
        int(gun_detected),
        int(danger_detected)
    ))

    conn.commit()
    conn.close()

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    INSERT INTO evidence
    (
        user_id,
        evidence_id,
        filename,
        sha256,
        upload_time,
        storage_path,
        status
    )
    VALUES (?, ?, ?, ?, ?, ?, ?)
    """, (
        user_id,
        evidence_id,
        filename,
        sha256,
        upload_time,
        storage_path,
        status
    ))
def init_db():

    conn = get_connection()
    cursor = conn.cursor()

    # --------------------------------------------------------
    # Evidence Table
    # --------------------------------------------------------

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS evidence(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        evidence_id TEXT,
        filename TEXT,
        sha256 TEXT,
        upload_time TEXT,
        storage_path TEXT,
        status TEXT,

        violence_detected INTEGER DEFAULT 0,
        violence_probability REAL DEFAULT 0.0,
        knife_detected INTEGER DEFAULT 0,
        gun_detected INTEGER DEFAULT 0,
        danger_detected INTEGER DEFAULT 0
    )
    """)

    # --------------------------------------------------------
    # Add AI columns to existing evidence table if missing
    # --------------------------------------------------------

    cursor.execute("PRAGMA table_info(evidence)")

    columns = [
        row[1]
        for row in cursor.fetchall()
    ]

    ai_columns = {
        "violence_detected": "INTEGER DEFAULT 0",
        "violence_probability": "REAL DEFAULT 0.0",
        "knife_detected": "INTEGER DEFAULT 0",
        "gun_detected": "INTEGER DEFAULT 0",
        "danger_detected": "INTEGER DEFAULT 0",
    }

    for column, definition in ai_columns.items():

        if column not in columns:

            cursor.execute(
                f"""
                ALTER TABLE evidence
                ADD COLUMN {column} {definition}
                """
            )

    # --------------------------------------------------------
    # Users Table
    # --------------------------------------------------------

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullname TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        vault_pin_hash TEXT
    )
    """)

    # --------------------------------------------------------
    # Emergency Contacts Table
    # --------------------------------------------------------

    cursor.execute("""
    CREATE TABLE IF NOT EXISTS emergency_contacts(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        email TEXT NOT NULL,
        phone TEXT,
        FOREIGN KEY(user_id) REFERENCES users(id)
    )
    """)

    conn.commit()
    conn.close()


def get_evidence_by_id(evidence_id):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        evidence_id,
        filename,
        sha256,
        upload_time,
        storage_path,
        status,
        violence_detected,
        violence_probability,
        knife_detected,
        gun_detected,
        danger_detected
    FROM evidence
    WHERE evidence_id = ?
    """, (evidence_id,))

    row = cursor.fetchone()

    conn.close()

    if row is None:
        return None

    return {
        "evidence_id": row[0],
        "filename": row[1],
        "sha256": row[2],
        "upload_time": row[3],
        "storage_path": row[4],
        "status": row[5],

        "violence_detected": bool(row[6]),
        "violence_probability": row[7],
        "knife_detected": bool(row[8]),
        "gun_detected": bool(row[9]),
        "danger_detected": bool(row[10]),
    }


def get_evidence_by_user(user_id):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        evidence_id,
        filename,
        sha256,
        upload_time,
        storage_path,
        status,
        violence_detected,
        violence_probability,
        knife_detected,
        gun_detected,
        danger_detected
    FROM evidence
    WHERE user_id = ?
    ORDER BY id DESC
    """, (user_id,))

    rows = cursor.fetchall()

    conn.close()

    return [
        {
            "evidence_id": row[0],
            "filename": row[1],
            "sha256": row[2],
            "upload_time": row[3],
            "storage_path": row[4],
            "status": row[5],

            "violence_detected": bool(row[6]),
            "violence_probability": row[7],
            "knife_detected": bool(row[8]),
            "gun_detected": bool(row[9]),
            "danger_detected": bool(row[10]),
        }
        for row in rows
    ]

# ============================================================
# USER FUNCTIONS
# ============================================================

def register_user(
    fullname,
    email,
    password
):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    INSERT INTO users(
        fullname,
        email,
        password
    )
    VALUES (?, ?, ?)
    """, (
        fullname,
        email,
        password
    ))

    conn.commit()
    conn.close()


def get_user(email):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT *
    FROM users
    WHERE email = ?
    """, (email,))

    user = cursor.fetchone()

    conn.close()

    return user


def login_user(
    email,
    password
):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        id,
        fullname,
        email
    FROM users
    WHERE email = ?
    AND password = ?
    """, (
        email,
        password
    ))

    user = cursor.fetchone()

    conn.close()

    return user


# ============================================================
# VAULT PIN FUNCTIONS
# ============================================================

def set_vault_pin_hash(
    user_id,
    pin_hash
):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    UPDATE users
    SET vault_pin_hash = ?
    WHERE id = ?
    """, (
        pin_hash,
        user_id
    ))

    conn.commit()
    conn.close()


def get_vault_pin_hash(user_id):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT vault_pin_hash
    FROM users
    WHERE id = ?
    """, (user_id,))

    row = cursor.fetchone()

    conn.close()

    if row is None:
        return None

    return row[0]


# ============================================================
# EMERGENCY CONTACT FUNCTIONS
# ============================================================

def add_emergency_contact(
    user_id,
    name,
    email,
    phone=None
):

    conn = get_connection()
    cursor = conn.cursor()

    # Allow a maximum of 3 contacts per user
    cursor.execute("""
    SELECT COUNT(*)
    FROM emergency_contacts
    WHERE user_id = ?
    """, (user_id,))

    count = cursor.fetchone()[0]

    if count >= 3:

        conn.close()

        raise ValueError(
            "Maximum of 3 emergency contacts allowed."
        )

    cursor.execute("""
    INSERT INTO emergency_contacts(
        user_id,
        name,
        email,
        phone
    )
    VALUES (?, ?, ?, ?)
    """, (
        user_id,
        name,
        email,
        phone
    ))

    conn.commit()

    contact_id = cursor.lastrowid

    conn.close()

    return contact_id


def get_emergency_contacts(user_id):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT
        id,
        name,
        email,
        phone
    FROM emergency_contacts
    WHERE user_id = ?
    ORDER BY id ASC
    """, (user_id,))

    rows = cursor.fetchall()

    conn.close()

    return [
        {
            "id": row[0],
            "name": row[1],
            "email": row[2],
            "phone": row[3],
        }
        for row in rows
    ]


def delete_emergency_contact(
    user_id,
    contact_id
):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    DELETE FROM emergency_contacts
    WHERE id = ?
    AND user_id = ?
    """, (
        contact_id,
        user_id
    ))

    deleted = cursor.rowcount > 0

    conn.commit()
    conn.close()

    return deleted