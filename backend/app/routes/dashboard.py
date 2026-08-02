from fastapi import APIRouter
import sqlite3
import os

router = APIRouter()

DB_NAME = "database/evidence.db"   # Change if needed


@router.get("/dashboard")
def dashboard():

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    # Total evidence
    cursor.execute("SELECT COUNT(*) FROM evidence")
    total = cursor.fetchone()[0]

    # Verified/Uploaded evidence
    cursor.execute("SELECT COUNT(*) FROM evidence WHERE status='Uploaded'")
    verified = cursor.fetchone()[0]

    # Recent uploads
    cursor.execute("""
        SELECT evidence_id,
               filename,
               upload_time,
               status
        FROM evidence
        ORDER BY upload_time DESC
        LIMIT 10
    """)

    recent = cursor.fetchall()

    conn.close()

    # Calculate encrypted storage size
    storage = 0

    if os.path.exists("encrypted"):
        for file in os.listdir("encrypted"):
            file_path = os.path.join("encrypted", file)

            if os.path.isfile(file_path):
                storage += os.path.getsize(file_path)

    storage = round(storage / (1024 * 1024), 2)

    return {
        "total": total,
        "verified": verified,
        "storage": storage,
        "recent": recent
    }