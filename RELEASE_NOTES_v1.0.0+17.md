# Reminda v1.0.0+17 — Unified Cloud Sync, Dynamic Releases & Desktop Stability

**Release Tag:** `v1.0.0+17`  
**Date:** November 2026  
**Platforms:** Android (APK) & Windows Desktop (x64)

---

## 🌟 Highlights & What's New

### 📱 Android Updates
* **Fixed Cloud Firestore Sync:** Re-routed Firestore connection to the active Singapore region database (`databaseId: 'default'`). Cloud sync for timetables, profiles, institution sync, and announcements now works instantly without 403 billing errors.
* **Direct Download 404 Resolved:** Fixed download routing on the landing page and within the app so Android users are always routed to the latest working `.apk`.
* **Schedule Deduplication:** Enhanced deduplication engine prevents duplicate classes or overlapping blocks when re-scanning timetable PDFs/images.

### 💻 Windows Desktop Updates
* **Cloud Sync Enabled:** Windows desktop now connects seamlessly to Cloud Firestore with full bidirectional sync matching the mobile experience.
* **Storage Stability & Encryption Fix:** Resolved a Hive encryption key persistence issue on Windows. Local schedule data is now securely stored and will not reset upon reboot or app restart.
* **Secure AI Parsing:** Timetable OCR and AI parsing now use the server proxy, keeping API credentials secure and avoiding local quota errors.
* **New Windows Installer:** Packaged with Inno Setup into a standalone `Reminda-Setup.exe` with desktop shortcut and clean uninstaller support.

### 🌐 Web & Infrastructure Updates
* **Smart GitHub Release Resolvers:** The marketing site (`https://getreminda.vercel.app`) now dynamically resolves and redirects download buttons (`/api/download/android` and `/api/download/windows`) to the newest release assets on GitHub automatically.
* **Dynamic Landing Page Hydration:** The hero badge, announcement bar, and download hub automatically display the latest release tag without requiring code changes for future updates.
* **Database Security Rules:** Deployed updated security rules to Cloud Firestore.

---

## 📦 Release Assets & Download Links

| Platform | File Name | Description |
| :--- | :--- | :--- |
| **Android (Recommended)** | `app-arm64-v8a-release.apk` | Native Android APK for modern 64-bit devices (Android 8.0+) |
| **Android (Universal/32-bit)** | `app-armeabi-v7a-release.apk` | Compatible with older 32-bit Android devices |
| **Windows Desktop** | `Reminda-Setup.exe` | Standalone Windows 10/11 64-bit Installer |

---

## 🛠️ Verification & Checksums
* Tested on Windows 11 & Android 14/15
* 100% Offline-First with Cloud Firestore fallback
