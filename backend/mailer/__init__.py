"""Gmail SMTP mailer module — implemented in Phase 10.

Note: this package is named `mailer`, not `email`, because a top-level
`email/` folder would shadow Python's built-in `email` standard-library
module (which packages like uvicorn depend on internally) and crash
the app on startup.
"""
