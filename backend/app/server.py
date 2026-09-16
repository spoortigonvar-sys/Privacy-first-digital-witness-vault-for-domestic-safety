"""
Application factory for the AI-Powered Emergency Evidence Vault backend.
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import settings
from app.routes import health
from app.routes import upload
from app.routes import auth
from app.routes import contacts
from app.routes.dashboard import router as dashboard_router
from app.routes import verify
from app.routes import vault
from database.database import init_db, migrate_users_table


def create_app() -> FastAPI:
    app = FastAPI(
        title=settings.APP_NAME,
        description=(
            "Backend API for secure emergency evidence "
            "recording, encryption, integrity "
            "verification, and evidence vault storage."
        ),
        version="0.1.0",
    )

    app.add_middleware(
        CORSMiddleware,
        allow_origins=["*"],
        allow_credentials=False,
        allow_methods=["*"],
        allow_headers=["*"],
    )

    app.include_router(dashboard_router)
    app.include_router(verify.router)
    app.include_router(vault.router)

    # Create database tables automatically
        # Create database tables automatically
    init_db()
    migrate_users_table()

    # Routes
    app.include_router(health.router)
    app.include_router(upload.router)
    app.include_router(auth.router)
    app.include_router(contacts.router)

    @app.get("/")
    def root():
        return {
            "message": f"{settings.APP_NAME} API is running.",
            "docs": "/docs",
        }

    return app


app = create_app()
