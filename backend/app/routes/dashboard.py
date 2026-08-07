from fastapi import APIRouter
import sqlite3
import os

router = APIRouter()

DB_NAME = "database/evidence.db"


@router.get("/dashboard/{user_id}")
def dashboard(user_id: int):

    conn = sqlite3.connect(DB_NAME)
    cursor = conn.cursor()

    # Total evidence
    cursor.execute(
        "SELECT COUNT(*) FROM evidence WHERE user_id=?",
        (user_id,)
    )
    total = cursor.fetchone()[0]

    # Uploaded evidence
    cursor.execute(
        "SELECT COUNT(*) FROM evidence WHERE user_id=? AND status='Uploaded'",
        (user_id,)
    )
    verified = cursor.fetchone()[0]

    # Recent uploads
    cursor.execute("""
        SELECT
            evidence_id,
            filename,
            sha256,
            upload_time,
            storage_path,
            status
        FROM evidence
        WHERE user_id=?
        ORDER BY upload_time DESC
    """, (user_id,))

    rows = cursor.fetchall()

    recent = []

    for row in rows:
        recent.append({
            "evidence_id": row[0],
            "filename": row[1],
            "sha256": row[2],
            "upload_time": row[3],
            "storage_path": row[4],
            "status": row[5],
        })

    # Calculate storage used by this user
    storage = 0

    cursor.execute("""
        SELECT storage_path
        FROM evidence
        WHERE user_id=?
    """, (user_id,))

    files = cursor.fetchall()

    for row in files:
        path = row[0]

        if os.path.exists(path):
            storage += os.path.getsize(path)

    storage = round(storage / (1024 * 1024), 2)

    conn.close()

    return {
        "total": total,
        "verified": verified,
        "storage": storage,
        "recent": recent,
    }