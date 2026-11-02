from fastapi import APIRouter, UploadFile, File, HTTPException, Form
from fastapi.responses import FileResponse

import os
import uuid
from datetime import datetime

from hashing.sha256 import generate_sha256
from encryption.encryption import encrypt_file
from supabase_storage import upload_encrypted_evidence

from database.database import (
    insert_evidence,
    get_connection,
    get_emergency_contacts,
)

from ai.violence_detector import (
    load_violence_model,
    predict_violence,
)

from ai.sharp_object_detector import detect_sharp_objects_in_video
from mailer.email_sender import send_emergency_alerts


router = APIRouter()

UPLOAD_FOLDER = "uploads"
ENCRYPTED_FOLDER = "encrypted"

os.makedirs(UPLOAD_FOLDER, exist_ok=True)
os.makedirs(ENCRYPTED_FOLDER, exist_ok=True)


# ============================================================
# LOAD X3D MODEL ONCE
# ============================================================

violence_model = load_violence_model()


# ============================================================
# UPLOAD VIDEO
# ============================================================

@router.post("/upload")
async def upload_video(
    user_id: int = Form(...),
    file: UploadFile = File(...),
):
    # 1. SAVE VIDEO LOCALLY FOR PROCESSING
    # Use only the filename, preventing a supplied path from being used.
    filename = os.path.basename(file.filename or "")
    if not filename:
        raise HTTPException(status_code=400, detail="Invalid filename")

    file_path = os.path.join(UPLOAD_FOLDER, filename)

    try:
        content = await file.read()
        received_size = len(content)
        print(f"UPLOAD RECEIVED: {received_size} bytes")

        if received_size == 0:
            raise HTTPException(
                status_code=400,
                detail="Uploaded video is empty",
            )

        os.makedirs(UPLOAD_FOLDER, exist_ok=True)

        with open(file_path, "wb") as output_file:
            output_file.write(content)

        saved_size = os.path.getsize(file_path)
        print(f"FILE SAVED: {saved_size} bytes")
        print(f"FILE PATH: {os.path.abspath(file_path)}")

        if saved_size != received_size:
            raise HTTPException(
                status_code=500,
                detail="Uploaded video size does not match saved file size",
            )

    finally:
        await file.close()

    # Resolve the person's display name for emergency notifications.
    user = get_user_by_id(user_id)
    person_name = user["fullname"] if user and user.get("fullname") else f"User {user_id}"

    # 2. X3D VIOLENCE DETECTION
    print("\nRunning X3D violence detection...")
    try:
        ai_result = predict_violence(violence_model, file_path)
    except Exception as exc:
        print(f"X3D detection failed: {exc}")
        raise HTTPException(
            status_code=500,
            detail=f"AI violence detection failed: {exc}",
        ) from exc

    violence_detected = bool(ai_result["violence_detected"])
    violence_probability = float(ai_result["violence_probability"])
    non_violence_probability = float(ai_result["non_violence_probability"])

    print(f"Violence detected: {violence_detected}")
    print(f"Violence probability: {violence_probability:.4f}")

    # 3. YOLO KNIFE / GUN DETECTION
    print("\nRunning YOLO sharp object detection...")
    try:
        yolo_result = detect_sharp_objects_in_video(
            file_path,
            frame_skip=1,
        )
    except Exception as exc:
        print(f"YOLO detection failed: {exc}")
        raise HTTPException(
            status_code=500,
            detail=f"YOLO sharp object detection failed: {exc}",
        ) from exc

    knife_detected = bool(yolo_result["knife_detected"])
    gun_detected = bool(yolo_result["gun_detected"])
    sharp_object_detected = bool(yolo_result["sharp_object_detected"])
    highest_knife_confidence = float(yolo_result["highest_knife_confidence"])
    highest_gun_confidence = float(yolo_result["highest_gun_confidence"])

    print(f"Knife detected: {knife_detected}")
    print(f"Highest knife confidence: {highest_knife_confidence:.4f}")
    print(f"Gun detected: {gun_detected}")
    print(f"Highest gun confidence: {highest_gun_confidence:.4f}")

    # 4. COMBINED DANGER DECISION
    danger_detected = violence_detected or sharp_object_detected

    print("\n" + "=" * 60)
    print("COMBINED AI DECISION")
    print("=" * 60)
    print(f"Violence detected: {violence_detected}")
    print(f"Knife detected: {knife_detected}")
    print(f"Gun detected: {gun_detected}")
    print(f"Danger detected: {danger_detected}")

    # 5. DETERMINE DETECTION TYPE
    detection_types = []
    if violence_detected:
        detection_types.append("Possible violent activity")
    if knife_detected:
        detection_types.append("Knife detected")
    if gun_detected:
        detection_types.append("Gun detected")
    if not detection_types:
        detection_types.append("No danger detected")

    detection_type = ", ".join(detection_types)

    # 6. EMERGENCY EMAIL ALERT
    email_result = {
        "alert_sent": False,
        "sent": [],
        "failed": [],
    }

    if danger_detected:
        print("\n" + "=" * 60)
        print("EMERGENCY CONDITION DETECTED")
        print("=" * 60)

        try:
            contacts = get_emergency_contacts(user_id)
            print(f"Emergency contacts found: {len(contacts)}")

            if contacts:
                result = send_emergency_alerts(
                    contacts=contacts,
                    person_name=person_name,
                    detection_type=detection_type,
                    violence_probability=violence_probability,
                )

                if isinstance(result, dict):
                    email_result["sent"] = result.get("sent", [])
                    email_result["failed"] = result.get("failed", [])
                email_result["alert_sent"] = len(email_result["sent"]) > 0

                print(f"Emails sent: {len(email_result['sent'])}")
                print(f"Emails failed: {len(email_result['failed'])}")
            else:
                print("No emergency contacts configured.")

        except Exception as exc:
            print(f"Emergency email process failed: {exc}")
            email_result["failed"].append({"error": str(exc)})
    else:
        print("\nNo danger detected.")
        print("Emergency email will NOT be sent.")

    # 7. SHA-256
    print("\nGenerating SHA-256 hash...")
    try:
        sha256_hash = generate_sha256(file_path)
    except Exception as exc:
        print(f"SHA-256 generation failed: {exc}")
        raise HTTPException(
            status_code=500,
            detail="Failed to generate evidence hash",
        ) from exc

    print(f"SHA-256: {sha256_hash}")

    # 8. EVIDENCE ID
    evidence_id = "EV-" + uuid.uuid4().hex[:8].upper()
    print(f"Evidence ID: {evidence_id}")

    # 9. ENCRYPTION
    print("\nEncrypting evidence...")
    encrypted_path = os.path.join(ENCRYPTED_FOLDER, filename + ".enc")

    try:
        encrypt_file(file_path, encrypted_path)
    except Exception as exc:
        print(f"Evidence encryption failed: {exc}")
        raise HTTPException(
            status_code=500,
            detail="Failed to encrypt evidence",
        ) from exc

    if not os.path.exists(encrypted_path) or os.path.getsize(encrypted_path) == 0:
        raise HTTPException(
            status_code=500,
            detail="Encrypted evidence file was not created correctly",
        )

    print(f"Encrypted evidence stored at: {encrypted_path}")

    # 10. UPLOAD ENCRYPTED EVIDENCE TO SUPABASE CLOUD
    print("\nUploading encrypted evidence to Supabase Cloud...")
    try:
        cloud_storage_path = upload_encrypted_evidence(
            encrypted_file_path=encrypted_path,
            evidence_id=evidence_id,
            filename=filename,
        )
    except Exception as exc:
        print(f"Cloud upload failed: {exc}")
        raise HTTPException(
            status_code=500,
            detail="Failed to upload encrypted evidence to cloud storage",
        ) from exc

    if cloud_storage_path is None:
        print("Cloud upload failed.")
        raise HTTPException(
            status_code=500,
            detail="Failed to upload encrypted evidence to cloud storage.",
        )

    print(f"Cloud storage path: {cloud_storage_path}")

    # 11. UPLOAD TIME
    upload_time = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # 12. SAVE EVIDENCE METADATA TO DATABASE
    try:
        insert_evidence(
            user_id,
            evidence_id,
            filename,
            sha256_hash,
            upload_time,
            cloud_storage_path,
            "Uploaded",
            violence_detected=violence_detected,
            violence_probability=violence_probability,
            knife_detected=knife_detected,
            gun_detected=gun_detected,
            danger_detected=danger_detected,
        )
    except Exception as exc:
        print(f"Database metadata save failed: {exc}")
        raise HTTPException(
            status_code=500,
            detail="Evidence was uploaded but its metadata could not be saved",
        ) from exc

    # 13. FINAL RESPONSE
    print("\n" + "=" * 60)
    print("UPLOAD COMPLETED")
    print("=" * 60)

    return {
        "message": "Video uploaded successfully",
        "evidence_id": evidence_id,
        "filename": filename,
        "sha256": sha256_hash,
        "upload_time": upload_time,
        "storage_path": cloud_storage_path,
        "status": "Uploaded",
        "ai_detection": {
            "violence_detected": violence_detected,
            "violence_probability": violence_probability,
            "non_violence_probability": non_violence_probability,
            "knife_detected": knife_detected,
            "gun_detected": gun_detected,
            "sharp_object_detected": sharp_object_detected,
            "highest_knife_confidence": highest_knife_confidence,
            "highest_gun_confidence": highest_gun_confidence,
            "danger_detected": danger_detected,
            "detection_type": detection_type,
            "violence_threshold": 0.40,
            "yolo_confidence_threshold": 0.80,
        },
        "emergency_alert": {
            "alert_sent": email_result["alert_sent"],
            "sent_to": email_result["sent"],
            "failed": email_result["failed"],
        },
    }


# ============================================================
# GET ORIGINAL VIDEO
# ============================================================

@router.get("/video/{evidence_id}")
def get_video(evidence_id: str):
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT filename
            FROM evidence
            WHERE evidence_id = ?
            """,
            (evidence_id,),
        )
        row = cursor.fetchone()
    finally:
        conn.close()

    if row is None:
        raise HTTPException(status_code=404, detail="Video not found")

    filename = os.path.basename(row[0])
    file_path = os.path.join(UPLOAD_FOLDER, filename)

    if not os.path.exists(file_path):
        raise HTTPException(status_code=404, detail="Video file missing")

    return FileResponse(
        path=file_path,
        media_type="video/mp4",
        filename=filename,
    )


# ============================================================
# GET USER BY ID
# ============================================================

def get_user_by_id(user_id):
    conn = get_connection()
    try:
        cursor = conn.cursor()
        cursor.execute(
            """
            SELECT id, fullname, email
            FROM users
            WHERE id = ?
            """,
            (user_id,),
        )
        row = cursor.fetchone()
    finally:
        conn.close()

    if row is None:
        return None

    return {
        "id": row[0],
        "fullname": row[1],
        "email": row[2],
    }
