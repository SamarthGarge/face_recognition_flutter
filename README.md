# Face Recognition Flutter

A cross-platform Flutter application for real-time face detection and recognition, with native integrations for Android, iOS, desktop, and web targets.

## ✨ Features

- Face detection and recognition workflow in Flutter
- Multi-platform project structure (`android`, `ios`, `linux`, `macos`, `windows`, `web`)
- Asset support for model/config/resources
- Native performance integrations using C++/CMake where needed
- Clean, extensible codebase for experimentation and production prototypes

## 🧱 Tech Stack

- **Flutter / Dart** (core app and UI)
- **C++ + CMake** (native processing/performance modules)
- **Swift** (iOS-specific native layer)
- **Platform folders** generated and customized for each supported target

## 📁 Project Structure

- `lib/` – Main Flutter application code
- `assets/` – Models, images, and static resources
- `android/`, `ios/` – Mobile platform implementations
- `linux/`, `macos/`, `windows/` – Desktop platform implementations
- `web/` – Web runner and config
- `pubspec.yaml` – Dependencies and asset declarations

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install)
- Dart SDK (bundled with Flutter)
- Platform toolchains:
  - Android Studio / SDK (Android)
  - Xcode (iOS/macOS)
  - CMake + compiler toolchain (desktop/native builds)

### Installation

```bash
git clone https://github.com/SamarthGarge/face_recognition_flutter.git
cd face_recognition_flutter
flutter pub get
```

### Run

```bash
flutter run
```

To run on a specific device/platform:

```bash
flutter devices
flutter run -d <device_id>
```

## ⚙️ Configuration Notes

- Ensure camera permissions are enabled on mobile platforms.
- If using local face models, keep them in `assets/` and declare them in `pubspec.yaml`.
- For native modules, verify CMake/toolchain setup for your target OS.

## 🛠 Development

Useful commands:

```bash
flutter analyze
flutter test
flutter build apk
flutter build ios
flutter build web
```
