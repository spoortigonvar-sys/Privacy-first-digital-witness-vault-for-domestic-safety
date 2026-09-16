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

from ai.sharp_object_detector import (
    detect_sharp_objects_in_video,
)

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
    file: UploadFile = File(...)
):

    # ========================================================
    # 1. SAVE VIDEO LOCALLY FOR PROCESSING
    # ========================================================

    file_path = os.path.join(
        UPLOAD_FOLDER,
        file.filename
    )

    content = await file.read()

    with open(file_path, "wb") as f:
        f.write(content)

    print()
    print("=" * 60)
    print("VIDEO UPLOAD")
    print("=" * 60)
    print(f"Uploaded video: {file.filename}")


    # ========================================================
    # 2. GET USER INFORMATION
    # ========================================================

    user = get_user_by_id(user_id)

    if user is None:
        raise HTTPException(
            status_code=404,
            detail="User not found."
        )

    person_name = user["fullname"]

    print()
    print(f"Person associated with evidence: {person_name}")


    # ========================================================
    # 3. X3D VIOLENCE DETECTION
    # ========================================================

    print()
    print("Running X3D violence detection...")

    try:

        ai_result = predict_violence(
            violence_model,
            file_path
        )

    except Exception as e:

        print(f"X3D detection failed: {e}")

        raise HTTPException(
            status_code=500,
            detail="AI violence detection failed."
        )


    violence_detected = ai_result[
        "violence_detected"
    ]

    violence_probability = ai_result[
        "violence_probability"
    ]

    non_violence_probability = ai_result[
        "non_violence_probability"
    ]


    print()
    print(
        f"Violence detected: "
        f"{violence_detected}"
    )

    print(
        f"Violence probability: "
        f"{violence_probability:.4f}"
    )


    # ========================================================
    # 4. YOLO KNIFE / GUN DETECTION
    # ========================================================

    print()
    print("Running YOLO sharp object detection...")

    try:

        yolo_result = detect_sharp_objects_in_video(
            file_path,
            frame_skip=1
        )

    except Exception as e:

        print(f"YOLO detection failed: {e}")

        raise HTTPException(
            status_code=500,
            detail="YOLO sharp object detection failed."
        )


    knife_detected = yolo_result[
        "knife_detected"
    ]

    gun_detected = yolo_result[
        "gun_detected"
    ]

    sharp_object_detected = yolo_result[
        "sharp_object_detected"
    ]

    highest_knife_confidence = yolo_result[
        "highest_knife_confidence"
    ]

    highest_gun_confidence = yolo_result[
        "highest_gun_confidence"
    ]


    print()
    print(
        f"Knife detected: "
        f"{knife_detected}"
    )

    print(
        f"Highest knife confidence: "
        f"{highest_knife_confidence:.4f}"
    )

    print(
        f"Gun detected: "
        f"{gun_detected}"
    )

    print(
        f"Highest gun confidence: "
        f"{highest_gun_confidence:.4f}"
    )


    # ========================================================
    # 5. COMBINED DANGER DECISION
    # ========================================================

    danger_detected = (
        violence_detected
        or sharp_object_detected
    )


    print()
    print("=" * 60)
    print("COMBINED AI DECISION")
    print("=" * 60)

    print(
        f"Violence detected: "
        f"{violence_detected}"
    )

    print(
        f"Knife detected: "
        f"{knife_detected}"
    )

    print(
        f"Gun detected: "
        f"{gun_detected}"
    )

    print(
        f"Danger detected: "
        f"{danger_detected}"
    )


    # ========================================================
    # 6. DETERMINE DETECTION TYPE
    # ========================================================

    detection_types = []

    if violence_detected:
        detection_types.append(
            "Possible violent activity"
        )

    if knife_detected:
        detection_types.append(
            "Knife detected"
        )

    if gun_detected:
        detection_types.append(
            "Gun detected"
        )

    if not detection_types:
        detection_types.append(
            "No danger detected"
        )

    detection_type = ", ".join(
        detection_types
    )


    # ========================================================
    # 7. EMERGENCY EMAIL ALERT
    # ========================================================

    email_result = {
        "alert_sent": False,
        "sent": [],
        "failed": []
    }


    if danger_detected:

        print()
        print("=" * 60)
        print("EMERGENCY CONDITION DETECTED")
        print("=" * 60)

        try:

            contacts = get_emergency_contacts(
                user_id
            )

            print(
                f"Emergency contacts found: "
                f"{len(contacts)}"
            )


            if len(contacts) > 0:

                email_result = send_emergency_alerts(
                    contacts=contacts,
                    person_name=person_name,
                    detection_type=detection_type,
                    violence_probability=violence_probability,
                )

                email_result["alert_sent"] = (
                    len(email_result["sent"]) > 0
                )

                print()
                print(
                    f"Emails sent: "
                    f"{len(email_result['sent'])}"
                )

                print(
                    f"Emails failed: "
                    f"{len(email_result['failed'])}"
                )

            else:

                print(
                    "No emergency contacts configured."
                )

        except Exception as e:

            print(
                f"Emergency email process failed: {e}"
            )

            email_result["failed"].append(
                {
                    "error": str(e)
                }
            )

    else:

        print()
        print(
            "No danger detected."
        )

        print(
            "Emergency email will NOT be sent."
        )


    # ========================================================
    # 8. SHA-256
    # ========================================================

    print()
    print("Generating SHA-256 hash...")

    sha256_hash = generate_sha256(
        file_path
    )

    print(
        f"SHA-256: {sha256_hash}"
    )


    # ========================================================
    # 9. EVIDENCE ID
    # ========================================================

    evidence_id = (
        "EV-"
        + uuid.uuid4().hex[:8].upper()
    )

    print()
    print(
        f"Evidence ID: {evidence_id}"
    )


    # ========================================================
    # 10. AES / FERNET ENCRYPTION
    # ========================================================

    print()
    print("Encrypting evidence...")

    encrypted_path = os.path.join(
        ENCRYPTED_FOLDER,
        file.filename + ".enc"
    )

    encrypt_file(
        file_path,
        encrypted_path
    )

    print(
        f"Encrypted evidence stored at: "
        f"{encrypted_path}"
    )


    # ========================================================
    # 11. UPLOAD ENCRYPTED EVIDENCE TO SUPABASE CLOUD
    # ========================================================

    print()
    print("Uploading encrypted evidence to Supabase Cloud...")

    cloud_storage_path = upload_encrypted_evidence(
        encrypted_file_path=encrypted_path,
        evidence_id=evidence_id,
        filename=file.filename
    )

    if cloud_storage_path is None:

        print(
            "Cloud upload failed."
        )

        raise HTTPException(
            status_code=500,
            detail="Failed to upload encrypted evidence to cloud storage."
        )

    print(
        f"Cloud storage path: "
        f"{cloud_storage_path}"
    )


    # ========================================================
    # 12. UPLOAD TIME
    # ========================================================

    upload_time = datetime.now().strftime(
        "%Y-%m-%d %H:%M:%S"
    )


    # ========================================================
    # 13. SAVE EVIDENCE METADATA TO DATABASE
    # ========================================================

    insert_evidence(
        user_id,
        evidence_id,
        file.filename,
        sha256_hash,
        upload_time,

        # Store Supabase cloud path
        cloud_storage_path,

        "Uploaded",

        # AI results
        violence_detected=violence_detected,
        violence_probability=violence_probability,
        knife_detected=knife_detected,
        gun_detected=gun_detected,
        danger_detected=danger_detected,
    )


    # ========================================================
    # 14. FINAL RESPONSE
    # ========================================================

    print()
    print("=" * 60)
    print("UPLOAD COMPLETED")
    print("=" * 60)

    return {

        "message":
            "Video uploaded successfully",

        "evidence_id":
            evidence_id,

        "filename":
            file.filename,

        "sha256":
            sha256_hash,

        "upload_time":
            upload_time,

        # Now this is the cloud storage path
        "storage_path":
            cloud_storage_path,

        "status":
            "Uploaded",

        "ai_detection": {

            "violence_detected":
                violence_detected,

            "violence_probability":
                violence_probability,

            "non_violence_probability":
                non_violence_probability,

            "knife_detected":
                knife_detected,

            "gun_detected":
                gun_detected,

            "sharp_object_detected":
                sharp_object_detected,

            "highest_knife_confidence":
                highest_knife_confidence,

            "highest_gun_confidence":
                highest_gun_confidence,

            "danger_detected":
                danger_detected,

            "detection_type":
                detection_type,

            "violence_threshold":
                0.40,

            "yolo_confidence_threshold":
                0.80,
        },

        "emergency_alert": {

            "alert_sent":
                email_result["alert_sent"],

            "sent_to":
                email_result["sent"],

            "failed":
                email_result["failed"],
        },
    }


# ============================================================
# GET ORIGINAL VIDEO
# ============================================================

@router.get("/video/{evidence_id}")
def get_video(evidence_id: str):

    conn = get_connection()

    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT filename
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


# ============================================================
# GET USER BY ID
# ============================================================

def get_user_by_id(user_id):

    conn = get_connection()

    cursor = conn.cursor()

    cursor.execute(
        """
        SELECT id, fullname, email
        FROM users
        WHERE id = ?
        """,
        (user_id,)
    )

    row = cursor.fetchone()

    conn.close()


    if row is None:
        return None


    return {
        "id": row[0],
        "fullname": row[1],
        "email": row[2],
    }