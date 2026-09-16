import hashlib
import secrets


def hash_vault_pin(pin: str) -> str:
    """
    Hash a vault PIN using PBKDF2-HMAC-SHA256 with a random salt.
    Returns: salt$hash
    """

    salt = secrets.token_bytes(16)

    pin_hash = hashlib.pbkdf2_hmac(
        "sha256",
        pin.encode("utf-8"),
        salt,
        200_000
    )

    return f"{salt.hex()}${pin_hash.hex()}"


def verify_vault_pin(pin: str, stored_hash: str) -> bool:
    """
    Verify a PIN against the stored salt$hash value.
    """

    try:
        salt_hex, hash_hex = stored_hash.split("$", 1)

        salt = bytes.fromhex(salt_hex)
        expected_hash = bytes.fromhex(hash_hex)

        actual_hash = hashlib.pbkdf2_hmac(
            "sha256",
            pin.encode("utf-8"),
            salt,
            200_000
        )

        return secrets.compare_digest(
            actual_hash,
            expected_hash
        )

    except (ValueError, TypeError):
        return False