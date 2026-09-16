from fastapi import APIRouter, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel

import os
import tempfile

from database.database import (
    get_vault_pin_hash,
    set_vault_pin_hash,
    get_evidence_by_user,
    get_connection,
)

from security.vault_security import (
    hash_vault_pin,
    verify_vault_pin,
)

from encryption.encryption import decrypt_file

from supabase_storage import supabase, BUCKET_NAME


router = APIRouter(
    prefix="/vault",
    tags=["Vault"]
)


# ---------------------------------------------------------
# VAULT PIN
# ---------------------------------------------------------

class VaultPinRequest(BaseModel):
    user_id: int
    pin: str


@router.post("/set-pin")
def set_pin(data: VaultPinRequest):

    if not data.pin.isdigit():
        raise HTTPException(
            status_code=400,
            detail="PIN must contain only numbers"
        )

    if len(data.pin) != 6:
        raise HTTPException(
            status_code=400,
            detail="PIN must be exactly 6 digits"
        )

    pin_hash = hash_vault_pin(data.pin)

    set_vault_pin_hash(
        data.user_id,
        pin_hash
    )

    return {
        "success": True,
        "message": "Vault PIN created successfully"
    }


@router.post("/unlock")
def unlock_vault(data: VaultPinRequest):

    pin_hash = get_vault_pin_hash(
        data.user_id
    )

    if not pin_hash:
        raise HTTPException(
            status_code=404,
            detail="Vault PIN has not been created"
        )

    if not verify_vault_pin(
        data.pin,
        pin_hash
    ):
        raise HTTPException(
            status_code=401,
            detail="Invalid Vault PIN"
        )

    return {
        "success": True,
        "message": "Vault unlocked"
    }


# ---------------------------------------------------------
# USER EVIDENCE
# ---------------------------------------------------------

@router.get("/evidence/{user_id}")
def get_vault_evidence(user_id: int):

    evidence = get_evidence_by_user(user_id)

    return {
        "success": True,
        "evidence": evidence
    }


# ---------------------------------------------------------
# VIEW / PLAY ENCRYPTED EVIDENCE FROM SUPABASE
# ---------------------------------------------------------

@router.get("/video/{evidence_id}")
def get_evidence_video(
    evidence_id: str,
    user_id: int
):

    # -----------------------------------------------------
    # GET EVIDENCE INFORMATION FROM DATABASE
    # -----------------------------------------------------

    conn = get_connection()
    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT
            user_id,
            filename,
            storage_path
        FROM evidence
        WHERE evidence_id = ?
        """,
        (evidence_id,)
    )

    row = cursor.fetchone()

    conn.close()

    if row is None:
        raise HTTPException(
            status_code=404,
            detail="Evidence not found"
        )

    evidence_user_id = row[0]
    filename = row[1]
    cloud_storage_path = row[2]


    # -----------------------------------------------------
    # SECURITY CHECK
    # -----------------------------------------------------

    if evidence_user_id != user_id:
        raise HTTPException(
            status_code=403,
            detail="You are not authorized to view this evidence"
        )


    # -----------------------------------------------------
    # CHECK CLOUD STORAGE PATH
    # -----------------------------------------------------

    if not cloud_storage_path:
        raise HTTPException(
            status_code=404,
            detail="Cloud storage path not found"
        )


    print()
    print("=" * 60)
    print("CLOUD EVIDENCE RETRIEVAL")
    print("=" * 60)

    print(
        f"Evidence ID: {evidence_id}"
    )

    print(
        f"Supabase path: {cloud_storage_path}"
    )


    # -----------------------------------------------------
    # CREATE TEMPORARY DIRECTORY
    # -----------------------------------------------------

    temp_dir = tempfile.mkdtemp()

    encrypted_temp_path = os.path.join(
        temp_dir,
        filename + ".enc"
    )

    decrypted_temp_path = os.path.join(
        temp_dir,
        filename
    )


    try:

        # -------------------------------------------------
        # DOWNLOAD ENCRYPTED FILE FROM SUPABASE
        # -------------------------------------------------

        print(
            "Downloading encrypted evidence from Supabase..."
        )

        encrypted_data = (
            supabase
            .storage
            .from_(BUCKET_NAME)
            .download(cloud_storage_path)
        )


        if not encrypted_data:

            raise HTTPException(
                status_code=404,
                detail="Encrypted evidence could not be downloaded from cloud"
            )


        # -------------------------------------------------
        # SAVE ENCRYPTED DATA TEMPORARILY
        # -------------------------------------------------

        with open(
            encrypted_temp_path,
            "wb"
        ) as f:

            f.write(encrypted_data)


        print(
            "Encrypted evidence downloaded successfully."
        )


        # -------------------------------------------------
        # DECRYPT EVIDENCE
        # -------------------------------------------------

        print(
            "Decrypting evidence..."
        )

        decrypt_file(
            encrypted_temp_path,
            decrypted_temp_path
        )


        print(
            "Evidence decrypted successfully."
        )


        # -------------------------------------------------
        # RETURN VIDEO TO FLUTTER
        # -------------------------------------------------

        print(
            "Sending video to Flutter..."
        )

        return FileResponse(
            path=decrypted_temp_path,
            media_type="video/mp4",
            filename=filename,
            background=None
        )


    except HTTPException:

        raise


    except Exception as e:

        print(
            f"Cloud evidence retrieval failed: {e}"
        )

        raise HTTPException(
            status_code=500,
            detail=f"Unable to retrieve evidence from cloud: {str(e)}"
        )