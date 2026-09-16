import os
import smtplib

from email.message import EmailMessage
from dotenv import load_dotenv


load_dotenv()


SMTP_EMAIL = os.getenv("SMTP_EMAIL")
SMTP_APP_PASSWORD = os.getenv("SMTP_APP_PASSWORD")


def send_emergency_alert(
    recipient_email,
    contact_name,
    person_name,
    detection_type,
    violence_probability,
):
    """
    Send an emergency alert to one emergency contact.
    """

    if not SMTP_EMAIL:
        raise RuntimeError(
            "SMTP_EMAIL is not configured in .env"
        )

    if not SMTP_APP_PASSWORD:
        raise RuntimeError(
            "SMTP_APP_PASSWORD is not configured in .env"
        )


    message = EmailMessage()

    message["From"] = SMTP_EMAIL
    message["To"] = recipient_email

    message["Subject"] = (
        "🚨 Emergency Alert - Digital Witness Vault"
    )


    message.set_content(
        f"""
Hello {contact_name},

🚨 EMERGENCY ALERT

An emergency situation may have been detected
involving {person_name}.

Person in possible trouble:
{person_name}

Detection:
{detection_type}

Violence detection score:
{violence_probability:.2%}

Please check on {person_name} as soon as possible.

IMPORTANT:
This email does NOT provide access to:

- The recorded video
- Encryption key
- Vault PIN
- Digital Witness Vault account
- Investigator dashboard

The evidence remains securely stored in the
Digital Witness Vault.

This is an automated emergency notification.

Digital Witness Vault
"""
    )


    with smtplib.SMTP(
        "smtp.gmail.com",
        587
    ) as server:

        server.starttls()

        server.login(
            SMTP_EMAIL,
            SMTP_APP_PASSWORD
        )

        server.send_message(message)


def send_emergency_alerts(
    contacts,
    person_name,
    detection_type,
    violence_probability,
):
    """
    Send emergency alert to all configured contacts.
    """

    sent = []
    failed = []


    for contact in contacts:

        try:

            send_emergency_alert(
                recipient_email=contact["email"],
                contact_name=contact["name"],
                person_name=person_name,
                detection_type=detection_type,
                violence_probability=violence_probability,
            )

            sent.append(
                contact["email"]
            )


        except Exception as e:

            failed.append(
                {
                    "email": contact["email"],
                    "error": str(e)
                }
            )


    return {
        "sent": sent,
        "failed": failed
    }