from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

from database.database import (
    register_user,
    login_user,
    get_user
)

router = APIRouter()


class RegisterRequest(BaseModel):
    fullname: str
    email: str
    password: str


class LoginRequest(BaseModel):
    email: str
    password: str


@router.post("/register")
def register(data: RegisterRequest):

    # Check if email already exists
    existing_user = get_user(data.email)

    if existing_user:
        raise HTTPException(
            status_code=400,
            detail="Email already registered"
        )

    register_user(
        data.fullname,
        data.email,
        data.password
    )

    return {
        "message": "Registration successful"
    }


@router.post("/login")
def login(data: LoginRequest):

    user = login_user(
        data.email,
        data.password
    )

    if not user:
        raise HTTPException(
            status_code=401,
            detail="Invalid email or password"
        )

    return {
        "message": "Login successful",
        "user": {
            "id": user[0],
            "fullname": user[1],
            "email": user[2]
        }
    }