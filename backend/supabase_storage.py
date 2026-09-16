import os

from dotenv import load_dotenv
from supabase import create_client

load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_SECRET_KEY = os.getenv("SUPABASE_SECRET_KEY")

supabase = create_client(
    SUPABASE_URL,
    SUPABASE_SECRET_KEY
)

BUCKET_NAME = "evidence"


def upload_encrypted_evidence(
    encrypted_file_path,
    evidence_id,
    filename
):
    """
    Upload an already-encrypted evidence file
    to Supabase Storage.
    """

    storage_path = f"evidence/{evidence_id}/{filename}.enc"

    try:
        with open(encrypted_file_path, "rb") as f:
            file_data = f.read()

        supabase.storage.from_(BUCKET_NAME).upload(
            storage_path,
            file_data,
            {
                "content-type": "application/octet-stream"
            }
        )

        print("ENCRYPTED EVIDENCE UPLOAD SUCCESSFUL")
        print(f"Supabase path: {storage_path}")

        return storage_path

    except Exception as e:
        print("ENCRYPTED EVIDENCE UPLOAD FAILED")
        print("Error:", e)

        return None


if __name__ == "__main__":

    encrypted_file = r"encrypted\REC561405478514725788.mp4.enc"

    result = upload_encrypted_evidence(
        encrypted_file_path=encrypted_file,
        evidence_id="TEST-CLOUD-001",
        filename="REC561405478514725788.mp4"
    )

    print("Returned storage path:", result)