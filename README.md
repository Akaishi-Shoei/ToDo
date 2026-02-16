# Flutter ToDo App (Windows Desktop)

A simple ToDo list application built with Flutter for Windows desktop.
This application allows users to add and delete.

---

## Features

- Add new tasks
- Delete tasks
- Local persistence using shared_preferences
- Tasks remain after application restart

---

## Tech Stack

- Flutter
- Dart
- shared_preferences
- Windows Desktop
- Material 3

---

## Technical Notes

- Implemented asynchronous processing using Future and async/await to prevent UI blocking.
- Managed application state using StatefulWidget.
- Ensured data persistence using shared_preferences.
- Handled Material 3 AppBar surface tint behavior when customizing the AppBar color.


---

## How to Run

```bash
flutter pub get
flutter run -d windows
