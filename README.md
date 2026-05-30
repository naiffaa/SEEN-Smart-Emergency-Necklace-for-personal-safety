SEEN4 
=======

Seen4 is a Flutter-based personal safety application that connects vulnerable users with their emergency contacts through real-time SOS alerts, Bluetooth-connected hardware, live GPS tracking, and audio/visual evidence capture. The system is built around a custom ESP32 wearable device that allows users to trigger emergencies hands-free, even without touching their phone.

------------------------------------------------------------

THE PROBLEM IT SOLVES
=====================

People in vulnerable situations — whether due to age, disability, or personal safety risks — often cannot reach their phone in an emergency. Seen4 solves this by pairing a physical wearable device with a mobile app. A single press of the device's emergency button immediately alerts trusted contacts with the user's live location, recorded audio, and full incident details, all synced in real time through Firebase.

------------------------------------------------------------

HARDWARE — SEEN DEVICE
======================

The SEEN device is a custom-built wearable powered by an ESP32 microcontroller. It operates independently and communicates with the mobile app over Bluetooth Low Energy (BLE). When an emergency is triggered — either through the physical button or the app — the device begins capturing evidence and transmitting data immediately.

  Component  |  Purpose

  ESP32 Microcontroller  |  The brain of the device. Controls all components, manages BLE communication with the mobile app, and handles data transmission to Firebase.
  GPS Module  |  Tracks the user's real-time location and streams latitude/longitude coordinates to the app and Firestore during an active alert.
  Camera Module  |  Captures visual evidence (images/video) when an emergency is triggered, uploaded to Firebase Storage for emergency contacts and admins to review.
  Microphone  |  Records audio during an emergency. The recording is encoded in AAC format (128kbps, 44100Hz) and uploaded automatically to Firebase Storage under the alert's evidence folder.
  Emergency Button  |  A physical push button that triggers the SOS alert system without needing to open the app — critical for hands-free emergencies.
  Battery Module  |  Powers the entire device. Battery level is monitored and synced to the app via BLE so the user always knows the device's charge status.

BLE COMMUNICATION
=================

The ESP32 communicates with the Flutter app using the Nordic UART Service (NUS) BLE profile:

  UUID  |  Role

  6E400001-B5A3-F393-E0A9-E50E24DCCA9E  |  NUS Service
  6E400002-B5A3-F393-E0A9-E50E24DCCA9E  |  Command characteristic (app → device)
  6E400003-B5A3-F393-E0A9-E50E24DCCA9E  |  Status/notify characteristic (device → app)

The app continuously listens to the device's status stream via SeenBleService and BleSyncService, syncing GPS coordinates, battery level, microphone status, and device state (Ready / Armed / Disarmed / Emergency) to Firestore in real time.

------------------------------------------------------------

MOBILE APP
==========

USER ROLES
==========

The app supports three distinct roles, each with a completely separate dashboard and navigation flow:

1. Vulnerable User
The person being protected. After signing up and pairing their SEEN device, they can:
- Monitor their paired device's connection status and battery level from the dashboard
- Trigger an SOS alert manually from the app (with a 5-second countdown to cancel)
- Receive SOS triggers from the physical device button automatically
- Add and manage emergency contacts (searched by email, stored with name and relation)
- View device location history and alert history
- Edit their profile, change language, and manage account settings

2. Emergency Contact
A trusted person linked to one or more vulnerable users. They can:
- View a real-time dashboard of all linked vulnerable users and their current status (Safe / Alert)
- Receive instant push notifications when a linked user triggers an SOS
- Open full alert detail pages showing location, audio recording link, timestamps, and alert status
- Acknowledge or resolve active alerts
- View the full alert history for each linked user
- Manage their own settings and notification preferences

3. Admin
A system administrator with full oversight. They can:
- View a live system overview: total users, active alerts, total devices, online/offline device counts
- Browse and manage all registered users (vulnerable users, emergency contacts)
- View all system alerts with full details and status
- Review problem reports submitted by users, with the ability to mark them as resolved
- Export incident reports as PDF documents
- Manage system-wide settings

------------------------------------------------------------

FEATURES
========

CORE SAFETY FEATURES
====================
- One-tap SOS — triggers from the app dashboard or the physical device button, with a 5-second cancellable countdown when triggered from the app
- Alert fan-out — when SOS fires, the system immediately notifies all linked emergency contacts by writing to their linkedUsers and alerts Firestore collections, and sends push notifications via Firebase Cloud Messaging
- Live GPS tracking — the ESP32's GPS module streams coordinates over BLE; BleSyncService writes them to Firestore in real time so emergency contacts can track the user's location during an incident
- Audio evidence recording — when an alert is triggered, EvidenceRecordingService starts recording audio immediately (AAC-LC, 128kbps, 44100Hz, mono) and uploads the file to Firebase Storage under evidence/{uid}/{alertId}/audio.m4a
- Camera evidence — the device's camera module captures visual evidence during an emergency, also uploaded to Firebase Storage

DEVICE FEATURES
===============
- BLE device pairing — scan for nearby SEEN devices, pair by device ID, and maintain an auto-reconnect connection in the background
- Device status monitoring — live connection state, battery percentage, armed/disarmed state, and safety status displayed on the dashboard
- Device history — view past device events and status changes

APP FEATURES
============
- Role-based routing — on login, the app reads the user's role from Firestore and routes them to the correct dashboard automatically
- Bilingual UI — full Arabic and English support with RTL layout switching, persisted across sessions via shared_preferences
- Profile management — users can update their name, phone, age, gender, and other profile fields
- Emergency contact management — vulnerable users add contacts by email; the app looks up the contact's UID in Firestore and links the accounts bidirectionally
- Help & support — in-app help page and problem reporting with submission to Firestore
- Terms & conditions — in-app terms page
- PDF export — admins can generate and print PDF incident reports using the pdf and printing packages
- Charts & analytics — admin dashboard uses fl_chart to visualize alert and user statistics

------------------------------------------------------------

TECH STACK
==========

  Layer  |  Technology

  Framework  |  Flutter (Dart)
  Authentication  |  Firebase Auth (Email/Password)
  Database  |  Cloud Firestore
  File Storage  |  Firebase Storage
  Push Notifications  |  Firebase Cloud Messaging (FCM)
  Bluetooth  |  flutter_blue_plus
  Local Notifications  |  flutter_local_notifications
  Audio Recording  |  record
  Charts  |  fl_chart
  PDF Generation  |  pdf + printing
  Localization  |  flutter_localizations
  Permissions  |  permission_handler
  Local Storage  |  shared_preferences
  File Paths  |  path_provider

------------------------------------------------------------

PROJECT STRUCTURE
=================

`
lib/
├── main.dart                              # App entry point, Firebase init, locale setup
├── firebase_options.dart                  # Generated Firebase config
├── core/
│   ├── routing/
│   │   ├── auth_gate.dart                 # Listens to auth state → routes to role or home
│   │   └── role_router.dart              # Routes authenticated users by role
│   ├── session/
│   │   └── user_session.dart             # Loads and stores current user role from Firestore
│   ├── theme/
│   │   ├── app_theme.dart                # Global Material theme definition
│   │   └── colors.dart                   # App color palette
│   ├── layout/
│   │   └── main_layout.dart              # Shared scaffold/navigation wrapper
│   ├── localization/
│   │   └── app_language.dart             # Language switching (EN/AR) with persistence
│   └── widgets/
│       └── app_settings_scaffold.dart    # Reusable settings page scaffold
├── features/
│   ├── onboarding/                        # Sign in, sign up, forgot password, onboarding slides, home
│   ├── sos/
│   │   └── sos_screen.dart               # SOS trigger logic + emergency contact fan-out
│   ├── contacts/
│   │   ├── contacts_screen.dart          # Emergency contacts list
│   │   └── emergency_history_screen.dart # Alert history for the vulnerable user
│   ├── devices/
│   │   ├── models/
│   │   │   └── seen_ble_message.dart     # BLE message data model (GPS, battery, mic, status)
│   │   ├── services/
│   │   │   ├── seen_ble_service.dart     # BLE scan, connect, send commands, receive notifications
│   │   │   ├── ble_sync_service.dart     # Background service: syncs BLE messages to Firestore
│   │   │   └── evidence_recording_service.dart  # Audio recording + Firebase Storage upload
│   │   ├── pair_device_screen.dart       # BLE device scanning and pairing UI
│   │   ├── device_setup_screen.dart      # Initial device configuration
│   │   ├── device_location_screen.dart   # Live map/location view from device GPS
│   │   └── device_history_screen.dart    # Historical device events
│   └── dashboard/
│       ├── vulnerable_user/
│       │   ├── vu_shell.dart             # Bottom nav shell for vulnerable user
│       │   ├── vu_dashboard.dart         # Main dashboard: device status, SOS button, live data
│       │   ├── add_emergency_contact_screen.dart
│       │   ├── pair_device_screen2.dart
│       │   ├── setup_device_screen.dart
│       │   └── vulnerable_settings_page.dart
│       ├── emergency_contact/
│       │   ├── ec_shell.dart             # Bottom nav shell for emergency contact
│       │   ├── ec_dashboard.dart         # Live view of linked users and active alerts
│       │   ├── ec_linked_users_page.dart
│       │   ├── ec_linked_user_details_page.dart
│       │   ├── ec_alerts_page.dart
│       │   ├── ec_alert_details_page.dart
│       │   └── ec_settings_page.dart
│       └── admin/
│           ├── admin_shell.dart          # Bottom nav shell for admin
│           ├── admin_dashboard.dart      # System overview: users, alerts, devices
│           ├── admin_user_management_page.dart
│           ├── admin_user_details_page.dart
│           ├── admin_alerts_list_page.dart
│           ├── admin_alert_reports_page.dart
│           ├── admin_report_details_page.dart
│           ├── admin_issues_report_page.dart
│           ├── admin_issue_details_page.dart
│           ├── admin_reports_page.dart
│           └── admin_settings_page.dart
└── screens/
    └── account/
        ├── account_page.dart             # Profile overview + navigation to account settings
        ├── edit_profile_page.dart        # Edit name, phone, age, gender
        ├── language_page.dart            # Switch between Arabic and English
        ├── help_support_page.dart        # In-app help content
        ├── report_problem_page.dart      # Submit problem reports to Firestore
        └── terms_page.dart              # Terms and conditions
`

------------------------------------------------------------

FIRESTORE DATA STRUCTURE
========================

`
users/
  {uid}/
    name, email, phone, age, gender
    role: "vulnerableUser" | "emergencyContact" | "admin"
    createdAt

    contacts/                       # (vulnerable users only)
      {contactId}/
        contactUserId, name, email, relation

    linkedUsers/                    # (emergency contacts only)
      {vulnerableUserId}/
        name, phone, status, location
        lastUpdate, streamUrl, streamStatus

    alerts/
      {alertId}/
        status: "Triggered" | "Acknowledged" | "Resolved"
        location, timestamp, audioUrl, ...

    devices/
      {deviceId}/
        status: "connected" | "safe" | "emergency"
        battery, lat, lng, ...

alerts/                             # (global alerts collection)
  {alertId}/
    userId, emergencyContactId
    status, location, timestamp, audioUrl
`

------------------------------------------------------------

GETTING STARTED
===============

PREREQUISITES
=============

- Flutter SDK ^3.10.8
- Dart SDK ^3.10.8
- A Firebase project with the following enabled:
  - Authentication (Email/Password)
  - Cloud Firestore
  - Firebase Storage
  - Firebase Cloud Messaging

SETUP
=====

1. Clone the repository
   `bash
   git clone https://github.com/naiffaa/Seen4.git
   cd Seen4
   `

2. Install dependencies
   `bash
   flutter pub get
   `

3. Configure Firebase

   Use the FlutterFire CLI to generate your firebase_options.dart:
   `bash
   flutterfire configure
   `
   Place google-services.json in android/app/ and GoogleService-Info.plist in ios/Runner/.

4. Run the app
   `bash
   flutter run
   `

REQUIRED DEVICE PERMISSIONS
===========================

  Permission  |  Reason

  Bluetooth (Scan + Connect)  |  Pairing and communicating with the SEEN ESP32 device
  Location  |  GPS coordinates during SOS events and device tracking
  Microphone  |  Audio evidence recording during emergencies
  Notifications  |  Receiving real-time SOS push notifications
  Storage (Android)  |  Temporary audio file storage before upload

------------------------------------------------------------

SUPPORTED PLATFORMS
===================

  Platform  |  Status

  Android  |  ✅ Fully supported
  iOS  |  ✅ Fully supported
  macOS  |  ⚠️ Partial (BLE limited)
  Windows  |  ⚠️ Partial (BLE limited)
  Linux  |  ⚠️ Partial (BLE limited)
  Web  |  ❌ BLE not supported

> Full BLE and device functionality is only available on Android and iOS.

------------------------------------------------------------

LICENSE
=======

This project is proprietary. All rights reserved.

------------------------------------------------------------

CONTACT
=======

For questions, collaboration, or project inquiries:


Ghala Alahmari

Email: galahmarii@gmail.com

LinkedIn: linkedin.com/in/ghala-alahmari


Naifa Alarifi

Email: naifa.arifi@gmail.com

LinkedIn: linkedin.com/in/naifa-al-arifi-64602229b


Noura Aljandol

Email: noura04mj@gmail.com

LinkedIn: linkedin.com/in/norah-aljandol-a17843218


