from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr

from database.database import (
    add_emergency_contact,
    get_emergency_contacts,
    delete_emergency_contact,
)


router = APIRouter(
    prefix="/contacts",
    tags=["Emergency Contacts"]
)


# ============================================================
# REQUEST MODEL
# ============================================================

class ContactRequest(BaseModel):
    user_id: int
    name: str
    email: EmailStr
    phone: str | None = None


# ============================================================
# ADD EMERGENCY CONTACT
# ============================================================

@router.post("/add")
def add_contact(contact: ContactRequest):

    try:

        contact_id = add_emergency_contact(
            user_id=contact.user_id,
            name=contact.name,
            email=contact.email,
            phone=contact.phone,
        )

        return {
            "message": "Emergency contact added successfully",
            "contact_id": contact_id,
        }

    except ValueError as e:

        raise HTTPException(
            status_code=400,
            detail=str(e)
        )


# ============================================================
# GET EMERGENCY CONTACTS
# ============================================================

@router.get("/{user_id}")
def get_contacts(user_id: int):

    contacts = get_emergency_contacts(
        user_id
    )

    return {
        "user_id": user_id,
        "count": len(contacts),
        "contacts": contacts,
    }


# ============================================================
# DELETE EMERGENCY CONTACT
# ============================================================

@router.delete("/{user_id}/{contact_id}")
def remove_contact(
    user_id: int,
    contact_id: int
):

    deleted = delete_emergency_contact(
        user_id,
        contact_id
    )

    if not deleted:

        raise HTTPException(
            status_code=404,
            detail="Emergency contact not found"
        )

    return {
        "message": "Emergency contact deleted successfully"
    }