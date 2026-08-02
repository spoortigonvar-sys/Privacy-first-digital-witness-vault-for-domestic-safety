from fastapi import APIRouter, HTTPException
from database.database import get_evidence_by_id
from hashing.sha256 import generate_sha256
import os

router = APIRouter()

UPLOAD_FOLDER = "uploads"

@router.get("/verify/{evidence_id}")
def verify_evidence(evidence_id: str):

    evidence = get_evidence_by_id(evidence_id)

    if evidence is None:
        raise HTTPException(status_code=404, detail="Evidence not found")

    stored_hash = evidence["sha256"]

    file_path = os.path.join(UPLOAD_FOLDER, evidence["filename"])

    current_hash = generate_sha256(file_path)

    if stored_hash == current_hash:
        return {
            "verified": True,
            "message": "Evidence is authentic",
            "sha256": current_hash
        }

    return {
        "verified": False,
        "message": "Evidence has been modified",
        "stored_hash": stored_hash,
        "current_hash": current_hash
    }