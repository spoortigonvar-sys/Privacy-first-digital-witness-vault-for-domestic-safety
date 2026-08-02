"""
Entry point for the AI-Powered Emergency Evidence Vault backend.

Run with:
    python main.py

or, equivalently, using uvicorn directly (auto-reload for development):
    uvicorn app.server:app --reload --port 8000
"""

import uvicorn

if __name__ == "__main__":
    uvicorn.run("app.server:app", host="0.0.0.0", port=8000, reload=True)
