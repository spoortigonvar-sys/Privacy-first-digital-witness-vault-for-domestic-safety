from cryptography.fernet import Fernet
import os

KEY_FILE = "secret.key"


def load_key():
    if not os.path.exists(KEY_FILE):
        key = Fernet.generate_key()

        with open(KEY_FILE, "wb") as f:
            f.write(key)

    with open(KEY_FILE, "rb") as f:
        return f.read()


key = load_key()

cipher = Fernet(key)


def encrypt_file(input_file, output_file):
    """
    Encrypt a file using Fernet encryption.
    """

    with open(input_file, "rb") as f:
        data = f.read()

    encrypted_data = cipher.encrypt(data)

    with open(output_file, "wb") as f:
        f.write(encrypted_data)


def decrypt_file(input_file, output_file):
    """
    Decrypt a Fernet-encrypted file.
    """

    with open(input_file, "rb") as f:
        encrypted_data = f.read()

    decrypted_data = cipher.decrypt(encrypted_data)

    with open(output_file, "wb") as f:
        f.write(decrypted_data)