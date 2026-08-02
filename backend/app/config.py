"""
Centralized application configuration.
"""

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    # ---- General ----
    APP_NAME: str = "AI-Powered Emergency Evidence Vault"
    ENVIRONMENT: str = "development"
    DEBUG: bool = True

    # ---- CORS ----
    # Allow all origins so the Flutter mobile app can connect from any IP
    ALLOWED_ORIGINS: list[str] = ["*"]

    # ---- Storage ----
    UPLOAD_DIR: str = "uploads"

    model_config = SettingsConfigDict(
        env_file=".env",
        env_file_encoding="utf-8",
        extra="ignore",
    )


settings = Settings()
