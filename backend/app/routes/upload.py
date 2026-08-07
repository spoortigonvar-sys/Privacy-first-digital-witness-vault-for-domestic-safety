from fastapi import APIRouter, UploadFile, File, HTTPException
from fastapi.responses import FileResponse
import os
import uuid
from datetime import datetime

from hashing.sha256 import generate_sha256
from encryption.encryption import encrypt_file
from database.database import insert_evidence, get_connection

router = APIRouter()

UPLOAD_FOLDER = "uploads"
ENCRYPTED_FOLDER = "encrypted"

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(ENCRYPTED_FOLDER, exist_ok=True)


from fastapi import Form

@router.post("/upload")
async def upload_video(
    user_id: int = Form(...),
    file: UploadFile = File(...)
):
    # Save uploaded file
    file_path = os.path.join(UPLOAD_FOLDER, file.filename)

    content = await file.read()

    with open(file_path, "wb") as f:
        f.write(content)

    # Generate SHA-256
    sha256_hash = generate_sha256(file_path)

    # Encrypt file
    encrypted_path = os.path.join(
        ENCRYPTED_FOLDER,
        file.filename + ".enc"
    )

    encrypt_file(file_path, encrypted_path)

    # Generate evidence ID
    evidence_id = "EV-" + uuid.uuid4().hex[:8].upper()

    # Upload time
    upload_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Save evidence to database
    insert_evidence(
        user_id,
        evidence_id,
        file.filename,
        sha256_hash,
        upload_time,
        encrypted_path,
        "Uploaded",
    )

    return {
        "message": "Video uploaded successfully",
        "evidence_id": evidence_id,
        "filename": file.filename,
        "sha256": sha256_hash,
        "upload_time": upload_time,
        "storage_path": encrypted_path,
        "status": "Uploaded"
    }


@router.get("/video/{evidence_id}")
def get_video(evidence_id: str):

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute("""
        SELECT filename
        FROM evidence
        WHERE evidence_id = ?
    """, (evidence_id,))

    row = cursor.fetchone()

    conn.close()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Video not found"
        )

    filename = row[0]

    file_path = os.path.join(
        UPLOAD_FOLDER,
        filename
    )

    if not os.path.exists(file_path):
        raise HTTPException(
            status_code=404,
            detail="Video file missing"
        )

    return FileResponse(
        path=file_path,
        media_type="video/mp4",
        filename=filename
    )