import sqlite3
import os

DB_PATH = os.path.join(os.path.dirname(__file__), "evidence.db")


def get_connection():
    return sqlite3.connect(DB_PATH)


def init_db():
    conn = get_connection()
    cursor = conn.cursor()

    # Evidence Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS evidence(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    user_id INTEGER,
    evidence_id TEXT,
    filename TEXT,
    sha256 TEXT,
    upload_time TEXT,
    storage_path TEXT,
    status TEXT
)
    """)

    # Users Table
    cursor.execute("""
    CREATE TABLE IF NOT EXISTS users(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        fullname TEXT NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL
    )
    """)

    conn.commit()
    conn.close()


# -------------------------------
# Evidence Functions
# -------------------------------
def insert_evidence(user_id, evidence_id, filename, sha256, upload_time, storage_path, status):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    INSERT INTO evidence
    (user_id, evidence_id, filename, sha256, upload_time, storage_path, status)
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

    conn.commit()
    conn.close()


# -------------------------------
# User Functions
# -------------------------------

def register_user(fullname, email, password):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    INSERT INTO users(fullname, email, password)
    VALUES (?, ?, ?)
    """, (fullname, email, password))

    conn.commit()
    conn.close()


def get_user(email):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT * FROM users
    WHERE email=?
    """, (email,))

    user = cursor.fetchone()

    conn.close()

    return user

def login_user(email, password):
    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
    SELECT id, fullname, email
    FROM users
    WHERE email = ? AND password = ?
    """, (email, password))

    user = cursor.fetchone()

    conn.close()

    return user

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
        status
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
    }