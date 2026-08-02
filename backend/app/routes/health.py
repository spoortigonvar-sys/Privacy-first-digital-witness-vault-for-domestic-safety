"""
Health-check route.

Used to verify the backend is running, both by us during development
and by the frontend to confirm connectivity before allowing recording.
"""

from fastapi import APIRouter
from datetime import datetime, timezone

router = APIRouter(tags=["Health"])


@router.get("/health")
def health_check():
    return {
        "status": "ok",
        "service": "AI-Powered Emergency Evidence Vault API",
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }
