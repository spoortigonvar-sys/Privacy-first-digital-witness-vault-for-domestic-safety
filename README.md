# Digital Witness Vault — Mobile

This is the mobile conversion of the **Digital Witness Vault** project
(originally an HTML/CSS/JS website + FastAPI backend). The web frontend has
been replaced with a **Flutter mobile app**. The FastAPI backend is kept
fully intact — all APIs, encryption, hashing, and SQLite storage work
exactly as before.

```
Digital-Witness-Vault-Mobile/
├── backend/          FastAPI backend (unchanged business logic, 1 bug fixed)
├── mobile_app/        Flutter mobile application
└── README.md
```

---

## 1. What changed vs. the original project

| Area | Status |
|---|---|
| `frontend/` (HTML/CSS/JS) | **Removed** — replaced by `mobile_app/` |
| `backend/app/routes/upload.py` | **Bug fixed**: `sha256_hash = generate_sha256(file_path)` was mis-indented outside the `upload_video` function, which would raise a `NameError`/`UnboundLocalError` at runtime. Fixed to run inside the function. |
| `backend/app/config.py` | `ALLOWED_ORIGINS` changed to `["*"]` so the CORS middleware allows requests from a mobile app (mobile requests don't come from a browser origin like `http://localhost:5500`). |
| `backend/app/server.py` | CORS middleware now uses `allow_origins=["*"]` and `allow_credentials=False` (required combination in Starlette/FastAPI — you cannot use `allow_credentials=True` together with a wildcard origin). |
| `backend/requirements.txt` | Trimmed to only the packages the current backend code actually imports (`firebase-admin`, `opencv-python-headless`, `numpy` were listed but unused by any route — removed to keep the install lightweight; add them back if you extend the backend later). |
| All other backend logic (auth, upload, verify, dashboard, hashing, encryption, SQLite) | **Untouched** — same endpoints, same request/response shapes, same behavior. |

No business logic was changed. No endpoints were removed, renamed, or
altered. No new AI features were added.

---

## 2. Backend Setup (FastAPI)

### Requirements
- Python 3.10+

### Install & Run

```bash
cd backend
python -m venv venv

# Activate the virtual environment
source venv/bin/activate        # macOS / Linux
venv\Scripts\activate           # Windows

pip install -r requirements.txt

# Run the server
python main.py
```

The server starts on `http://0.0.0.0:8000` with auto-reload enabled.

You can verify it's running by visiting:
- `http://127.0.0.1:8000/` — root status message
- `http://127.0.0.1:8000/health` — health check
- `http://127.0.0.1:8000/docs` — interactive Swagger API docs

### Existing API Endpoints (all preserved)

| Method | Path | Purpose |
|---|---|---|
| GET | `/health` | Backend health check |
| POST | `/register` | Register a new user (fullname, email, password) |
| POST | `/login` | Login (email, password) → returns user object |
| POST | `/upload` | Upload a video file (multipart/form-data, field `file`) → hashes, encrypts, stores metadata |
| GET | `/verify/{evidence_id}` | Re-hash the stored file and compare against the stored SHA-256 |
| GET | `/dashboard` | Total files, uploaded count, encrypted storage size (MB), 10 most recent uploads |

The SQLite database file lives at `backend/database/evidence.db` and is
created automatically (tables `evidence` and `users`) via `init_db()` on
startup if it doesn't already exist. Uploaded files are saved to
`backend/uploads/`, encrypted copies to `backend/encrypted/`, and the
Fernet symmetric key is stored in `backend/secret.key` (auto-generated on
first run).

---

## 3. Mobile App Setup (Flutter)

### Requirements
- Flutter SDK 3.19+ (Dart 3.0+)
- Android Studio (for Android) and/or Xcode (for iOS), with a device or
  emulator/simulator configured
- The backend running and reachable from your device/emulator (see
  networking notes below)

### Install & Run

```bash
cd mobile_app
flutter pub get
flutter run
```

This launches the app on whatever device/emulator you have selected
(`flutter devices` to list them).

### Configuring the backend URL

Open `mobile_app/lib/utils/constants.dart` and set `baseUrl` to match how
your emulator/device reaches your backend machine:

```dart
class AppConstants {
  const String baseUrl = 'http://172.20.10.4:8000';
  // ...0
}
```

| Target | `baseUrl` to use |
|---|---|
| Android Emulator | `http://10.0.2.2:8000` (this is already the default — `10.0.2.2` is the emulator's alias for your host machine's `localhost`) |
| iOS Simulator | `http://127.0.0.1:8000` |
| Physical Android/iOS device | `http://<your-computer's-LAN-IP>:8000` (e.g. `http://192.168.1.42:8000`) — your phone and computer must be on the same Wi-Fi network, and the backend must be started with `host="0.0.0.0"` (already the default in `main.py`) |

The app has cleartext (plain HTTP) traffic enabled on both Android
(`android:usesCleartextTraffic="true"` in `AndroidManifest.xml`) and iOS
(`NSAllowsArbitraryLoads` in `Info.plist`), since the backend runs over
HTTP for local development. If you later deploy the backend behind HTTPS,
you can tighten these settings.

---

## 4. Mobile App — Screens

All screens from the original website are implemented natively in
Flutter/Material Design:

| Screen | File | Maps to original |
|---|---|---|
| Splash Screen | `lib/screens/splash_screen.dart` | New — checks backend health, routes to Login or Dashboard |
| Login | `lib/screens/login_screen.dart` | `login.html` / `js/login.js` |
| Register | `lib/screens/register_screen.dart` | `register.html` / `js/register.js` |
| Dashboard | `lib/screens/dashboard_screen.dart` | `dashboard.html` |
| Emergency Recorder | `lib/screens/recorder_screen.dart` | `recorder.html` / `js/recorder.js` — live camera+mic capture, on-screen timer, uploads the recorded file to `/upload` on stop, exactly like the website's `getUserMedia`/`MediaRecorder` flow |
| Upload Evidence | `lib/screens/upload_screen.dart` | `upload.html` / `js/upload.js` |
| Evidence History | `lib/screens/evidence_history_screen.dart` | `evidence.html` (list of recent uploads from `/dashboard`) |
| Evidence Details | `lib/screens/evidence_detail_screen.dart` | New per-item detail view (metadata + verify action) |
| Verify Evidence | `lib/screens/verify_evidence_screen.dart` | Manual SHA-256 verification against `/verify/{id}` |

---

## 5. Mobile App — Project Structure

```
mobile_app/
└── lib/
    ├── main.dart                     App entry point + route table
    ├── models/
    │   ├── user_model.dart
    │   ├── evidence_model.dart
    │   └── dashboard_model.dart
    ├── services/
    │   ├── api_service.dart          All HTTP calls to the FastAPI backend
    │   └── auth_service.dart         Local session persistence (SharedPreferences)
    ├── screens/
    │   ├── splash_screen.dart
    │   ├── login_screen.dart
    │   ├── register_screen.dart
    │   ├── dashboard_screen.dart
    │   ├── recorder_screen.dart
    │   ├── upload_screen.dart
    │   ├── evidence_history_screen.dart
    │   ├── evidence_detail_screen.dart
    │   └── verify_evidence_screen.dart
    ├── widgets/
    │   ├── custom_text_field.dart
    │   ├── loading_overlay.dart
    │   └── stat_card.dart
    └── utils/
        ├── constants.dart            Base URL, route names, storage keys
        └── app_theme.dart            Material theme matching the original dark/navy design
```

---

## 6. Notes on data & sessions

- Login/session state is stored on-device using `shared_preferences`
  (equivalent to the website's `localStorage.setItem("user", ...)`).
- No mock data is used anywhere — every screen calls the live FastAPI
  backend (`/login`, `/register`, `/upload`, `/verify/{id}`, `/dashboard`,
  `/health`).
- Password handling matches the original backend exactly (plaintext
  comparison in SQLite) — this was not changed, per the instruction to
  preserve all existing business logic exactly as-is. If you intend to use
  this beyond an academic prototype, hash passwords server-side before
  storing them.

---

## 7. Troubleshooting

- **"Cannot connect to backend" / red banner on splash screen**
  Check `baseUrl` in `constants.dart` matches your setup (see table
  above), and confirm the backend is running (`python main.py`) and
  reachable (`curl http://127.0.0.1:8000/health` from your machine).

- **Upload fails / file picker returns nothing**
  Make sure storage/media permissions are granted to the app on first
  launch (Android 13+ requires `READ_MEDIA_VIDEO`, already declared in
  `AndroidManifest.xml`).

- **Emergency Recorder shows "Camera Permission Denied"**
  Grant Camera and Microphone permissions when prompted (declared in
  `AndroidManifest.xml` / `Info.plist`). On a physical device you may
  need to enable them manually in system Settings → Apps → Digital
  Witness Vault → Permissions if you denied them once. Camera preview
  will not work on most desktop/emulator setups without a virtual camera
  configured — test on a physical device or an emulator with camera
  emulation enabled.

- **`flutter pub get` fails**
  Ensure you're using a Flutter SDK version that supports Dart 3.0+
  (`flutter --version`).
