# ShinoChat Flutter App

ShinoChat is a Flutter client for the Shinokawa Chat backend.

Repository description suggestion:

> Flutter client for Shinokawa Chat with real-time streaming, local sync cache, and cross-platform builds.

## Key Features

- Username/password login via backend auth API.
- Real-time streaming chat responses.
- Conversation management (create, update, delete).
- Local cache and sync with Drift + SQLite.
- Attachment support (image picker + file picker).
- Persisted session, theme mode, and locale preferences.
- Multi-platform targets: Android, iOS, macOS, Linux, Windows, and Web.

## Tech Stack

- Flutter (Dart)
- HTTP client: `package:http`
- Local database: `drift` + SQLite (`sqlite3_flutter_libs`)
- Persistence: `shared_preferences`, `path_provider`
- UI helpers: `google_fonts`, `flutter_markdown`, `flutter_math_fork`

## Project Structure

```text
lib/
  core/       # theme + locale helpers
  data/       # API client, auth/session store, local DB
  models/     # app domain models
  screens/    # login + chat home screens
  widgets/    # reusable widgets
```

## Quick Start

### Prerequisites

- Flutter stable SDK (Dart >= 3.10.4)
- Java 17 + Android SDK (for Android builds)
- Xcode + CocoaPods (for iOS/macOS builds)

### Install dependencies

```bash
flutter pub get
```

### Run the app

```bash
flutter run
```

### Quality checks

```bash
flutter analyze
flutter test
```

## Build Outputs

### Android APK (release)

```bash
flutter build apk --release
```

Output:

- `build/app/outputs/flutter-apk/app-release.apk`

### iOS IPA (unsigned)

```bash
flutter build ios --release --no-codesign
mkdir -p build/ios/ipa/Payload
cp -R build/ios/iphoneos/Runner.app build/ios/ipa/Payload/Runner.app
cd build/ios/ipa && zip -r ShinoChat-unsigned.ipa Payload
```

Output:

- `build/ios/ipa/ShinoChat-unsigned.ipa`

## GitHub Actions CI

Workflow files:

- `.github/workflows/build-and-release.yml`
- `.github/workflows/build-android.yml`
- `.github/workflows/build-ios.yml`

Cloud build (no local Android SDK required):

- Every push to `main` builds Android APK and iOS IPA on GitHub runners.
- Manual run is supported through `workflow_dispatch`.

Artifacts:

- `release-android` (contains `app-release.apk`)
- `release-ios` (contains `ShinoChat-unsigned.ipa`)

Optional release publishing:

- `build-and-release.yml` publishes a GitHub Release only when commit message contains `YYYY.YYYY` (for example, `2026.0425`) or when manually dispatched.
- Android signing secrets (optional): `SIGNING_KEY`, `KEY_STORE_PASSWORD`, `ALIAS`, `KEY_PASSWORD`.

## Notes

- Android package ID is currently `com.example.flutter_app`. Change it before production release.
- iOS artifact in CI is unsigned. Add signing certificates/provisioning profiles for distributable IPA.
