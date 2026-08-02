from fastapi import APIRouter, UploadFile, File
import os
import uuid
from datetime import datetime
from hashing.sha256 import generate_sha256
from encryption.encryption import encrypt_file
from database.database import insert_evidence

router = APIRouter()

UPLOAD_FOLDER = "uploads"
ENCRYPTED_FOLDER = "encrypted"

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(ENCRYPTED_FOLDER, exist_ok=True)


@router.post("/upload")
async def upload_video(file: UploadFile = File(...)):

    # Save uploaded file
    file_path = os.path.join(UPLOAD_FOLDER, file.filename)

    content = await file.read()

    with open(file_path, "wb") as f:
        f.write(content)

    # Generate SHA-256 hash (bug fix: was mis-indented outside function)
    sha256_hash = generate_sha256(file_path)

    # Encrypt file
    encrypted_path = os.path.join(
        ENCRYPTED_FOLDER,
        file.filename + ".enc"
    )

    encrypt_file(file_path, encrypted_path)

    # Generate Evidence Metadata
    evidence_id = "EV-" + uuid.uuid4().hex[:8].upper()

    upload_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    storage_path = encrypted_path

    status = "Uploaded"

    # Save metadata into SQLite
    insert_evidence(
        evidence_id,
        file.filename,
        sha256_hash,
        upload_time,
        storage_path,
        status
    )

    return {
        "message": "Video uploaded successfully",
        "evidence_id": evidence_id,
        "filename": file.filename,
        "sha256": sha256_hash,
        "upload_time": upload_time,
        "storage_path": storage_path,
        "status": status
    }
