# 📅 Reminda (Schedly) — AI-Powered Smart Schedule & Timetable Assistant

<p align="center">
  <img src="assets/images/Reminda%20-%20NoBG.png" alt="Reminda Mascot" width="180"/>
</p>

<p align="center">
  <b>Scan. Parse. Schedule. Get Reminded.</b><br>
  Turn any timetable screenshot, document photo, or PDF into smart, reminder-ready schedules in seconds.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white" alt="Flutter"/>
  <img src="https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white" alt="Dart"/>
  <img src="https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black" alt="Firebase"/>
  <img src="https://img.shields.io/badge/Google_ML_Kit-4285F4?style=for-the-badge&logo=google&logoColor=white" alt="ML Kit"/>
  <img src="https://img.shields.io/badge/Gemini_AI-8E75C2?style=for-the-badge&logo=google&logoColor=white" alt="Gemini"/>
  <img src="https://img.shields.io/badge/Version-v1.0.0+17-brightgreen?style=for-the-badge" alt="Version"/>
</p>

---

## 📖 Overview

**Reminda (Schedly)** is a dynamic, multi-sector mobile scheduling application designed for **college and high school students, healthcare workers (nurses & doctors), corporate shift employees (BPO, malls, fast food), and government personnel**.

People frequently miss classes, shift rotations, or duty handovers simply because managing scattered screenshots and rigid calendar apps is tedious. Reminda eliminates manual data entry by extracting schedule details directly from visual images and PDFs using **On-Device Neural OCR & Multimodal AI**, then instantly scheduling high-priority alarm reminders.

---

## ✨ Key Features

### 📷 1. Dual AI Schedule Scanner
- **100% On-Device Offline AI:** Powered by **Google ML Kit On-Device Neural Vision** paired with a custom **MMA (Multi-Modal Adaptive) Spatial Parser** to extract class codes, times, days, and rooms without requiring internet connectivity.
- **Multimodal Cloud AI Fallback:** Seamless cloud fallback powered by **Google Gemini Vision (`gemini-1.5-flash`, `gemini-2.0-flash`)**, OpenRouter, and Cloudflare Workers AI for complex, noisy, or rotated document layouts.
- **Interactive Review & Verification:** Inspect, edit, add instructors/supervisors, adjust reminder leads, and fine-tune entries before saving.

### 🎓 2. Multi-Sector Timetable Profiles
- **School & University:** Track course codes, classroom/lab rooms, and professors across Philippine universities (UM, UIC, CJC, Ateneo, UP, UST, USEP, etc.).
- **Hospital & Clinic:** Organize ward assignments, doctor rotations, and hospital duty shifts.
- **Work & Corporate:** Manage rotating morning, mid, night, and graveyard shifts.
- **Custom / Government:** Adaptable for public sector duties, freelance routines, and personal projects.

### ⏰ 3. Smart Alarms & Crystal Chime Notifications
- **Custom Melodies:** High-quality built-in tones including *Crystal Chime*, *Zen Bell*, *Electronic Pulse*, and *Soft Marimba*.
- **Advance Reminder Alerts:** Flexible reminder lead times (5m, 15m, 30m, 1h, 2h before).
- **Exact Background Alarm Dispatch:** Uses Android exact alarms and notification channels so alarms reliably ring even when the device is locked, on battery saver, or offline.

### ☁️ 4. Google Cloud Backup & Strict Account Sandboxing
- **Real-Time Firebase Firestore Sync:** Synchronizes profiles and timetables across devices when signed in with Google or Email.
- **100% Multi-Account Isolation:** Clean local cache purging on logout ensures zero cross-account data leaks between different Google accounts on the same device.
- **Guest Mode:** Complete offline usage without requiring registration or email.

### 💬 5. In-App Feedback & Anonymous Telemetry Pipeline
- **Direct Feedback System:** Integrated 5-star rating, category chips (*Bug Report, Feature Request, Scanner Issue, General*), and direct feedback delivery to Firestore.
- **Ground-Truth Dataset Telemetry:** Optional anonymous collection of layout formatting and verified corrections to continuously improve future offline AI models in compliance with the **Data Privacy Act of 2012 (RA 10173)**.

### 🛡️ 6. Full Data Ownership & Cascade Management
- **1-Tap Export:** Export complete timetables to Formatted Text, Excel CSV, or JSON backup.
- **Cascade Deletion:** Deleting a schedule profile permanently wipes out all associated schedule events, alarms, and cloud documents in real-time.

---

## 🏗️ Architecture & Tech Stack

```
lib/
├── core/
│   ├── ai/                      # ML Kit OCR, Gemini Parser & AI Telemetry Service
│   ├── config/                  # App configuration & environment keys
│   ├── constants/               # Colors, themes, dynamic versioning
│   ├── database/                # Local Hive repositories & Firestore Cloud Sync
│   ├── notifications/           # Local notification & exact alarm dispatcher
│   └── utils/                   # Time utilities, day formatters & page routes
├── models/                      # ScheduleEntry, ScheduleProfile, AlarmTone, Directory
├── providers/                   # Riverpod StateNotifier providers (Auth, Schedule, Profile, Setup)
└── views/
    ├── home/                    # Dashboard, countdown banner, schedule detail views
    ├── navigation/              # Animated bottom navigation bar shell
    ├── onboarding/              # Splash screen, walkthrough, login & 3-step workspace setup
    ├── profile/                 # Profile details, legal views (Privacy & Terms), Send Feedback
    ├── profiles/                # Multi-profile manager (My Schedules) & cascade deletion
    ├── scanner/                 # Camera scanner, image picker, OCR processing & review screen
    └── schedule/                # Timetable calendar view, add/edit schedule & reminder dialogs
```

| Layer | Technology |
| :--- | :--- |
| **Framework** | [Flutter](https://flutter.dev/) (v3.24+) |
| **Language** | [Dart](https://dart.dev/) (v3.5+) |
| **State Management** | [Flutter Riverpod](https://riverpod.dev/) |
| **On-Device OCR** | [Google ML Kit Text Recognition](https://pub.dev/packages/google_mlkit_text_recognition) |
| **Cloud AI** | [Google Generative AI (Gemini Flash)](https://pub.dev/packages/google_generative_ai) |
| **Cloud Database & Auth**| [Firebase Firestore](https://pub.dev/packages/cloud_firestore) & [Firebase Auth](https://pub.dev/packages/firebase_auth) |
| **Local Storage** | [Hive](https://pub.dev/packages/hive_flutter) (Key-Value NoSQL) |
| **Notifications & Audio**| [Flutter Local Notifications](https://pub.dev/packages/flutter_local_notifications) & [AudioPlayers](https://pub.dev/packages/audioplayers) |

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (`>= 3.24.0`)
- Android Studio / VS Code with Flutter extensions
- Android Device or Emulator (API 26+)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Dranyl-23/Schedly.git
   cd Schedly
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Configure Environment Variables (Optional for Online AI):**
   Create a `.env` file in the root directory:
   ```env
   GEMINI_API_KEY=your_gemini_api_key_here
   OPENROUTER_API_KEY=your_openrouter_api_key_here
   CLOUDFLARE_ACCOUNT_ID=your_cloudflare_id_here
   CLOUDFLARE_API_TOKEN=your_cloudflare_token_here
   ```

4. **Run the application:**
   ```bash
   flutter run
   ```

5. **Build Release APK:**
   ```bash
   flutter build apk --release
   ```
   *Output file:* `build/app/outputs/flutter-apk/app-release.apk`

---

## 📜 Privacy & Compliance

Reminda is engineered with a **Privacy-First Architecture**:
- All offline schedule scanning is processed 100% locally on the user's device.
- Zero personal information (Student IDs, contact numbers, passwords) is shared or sold.
- Fully compliant with the **Philippine Data Privacy Act of 2012 (Republic Act No. 10173)**.
- Read our full [Privacy Policy](PRIVACY_POLICY.md).

---

## 👨‍💻 Developer & Support

- **Lead Developer:** Alfie Lynard Polacas
- **GitHub:** [@Dranyl-23](https://github.com/Dranyl-23)
- **Support Email:** alfielynard23@gmail.com
- **Distribution:** Available on [APKPure](https://apkpure.com) & Firebase App Distribution

---

<p align="center">
  Made with ❤️ in the Philippines 🇵🇭
</p>
