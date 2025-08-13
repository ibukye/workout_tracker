# AtlasLog (Workout Tracker)

📖 Read this in [日本語](README.ja.md)

A simple yet powerful strength training logger designed to effortlessly track your daily workouts and visualize your progress. Developed with Flutter, it runs smoothly on both iOS and Android.

## Table of Contents
* [✨ Key Features](#-key-features)
* [🛠️ Tech Stack](#-tech-stack)
* [📂 Project Structure](#-project-structure)
* [🚀 Setup and Usage](#-setup-and-usage)
* [📝 Future Plans (TODO)](#-future-plans-todo)
* [📄 License](#-license)

---

## ✨ Key Features

This app is packed with features to keep you motivated and help maximize your results.

* **Workout Logging**:
    * Intuitively record your Weight, Reps, and Sets.
    * Assisted input based on your previous records for a seamless data entry experience.

* **Interactive Calendar**:
    * Automatically marks the days you trained on the home screen calendar.
    * Easily look back at past workout history by tapping on any date.

* **Customizable Exercises**:
    * Freely add, edit, and delete categories like "Chest," "Arms," and "Back."
    * Create your own personalized workout menu by adding, editing, and deleting individual exercises.
    * Effortlessly reorder exercises with a simple drag-and-drop interface.

* **Advanced Logging Screen**:
    * The detail screen always displays your history for the same exercise on the current day, along with your all-time max weight.
    * Stay conscious of your past achievements while pushing for your next set.
    * The layout remains stable thanks to a scrollable history area, even with a high number of sets.

* **Weekly Routine Planner**:
    * Set up your workout schedule for each day of the week in advance.
    * Makes it easy to manage your training plan, such as "Chest Day" or "Leg Day."
    * Start your workout for the day with a single tap from the routine screen.

* **Notification System**:
    * Sends a reminder notification 30 minutes after you finish logging a workout to take your protein.

---

## 🛠️ Tech Stack

This application is built using the following technologies:

* **Framework**: Flutter
* **Language**: Dart
* **Database**: `drift` (A reactive persistence library for Flutter built on top of SQLite)
* **State Management**: `Provider`
* **Key Libraries**:
    * `table_calendar`: For a highly customizable calendar view.
    * `flutter_local_notifications`: To implement local notification features.
    * `permission_handler`: For managing app permissions.
    * `path_provider`: To access the device's file system.

---

## 📂 Project Structure

The project is organized by feature to ensure maintainability and scalability.

```
lib
├── data/
│   ├── database.dart         # Drift database definitions and queries
│   └── database.g.dart       # Auto-generated file
│
├── screens/
│   ├── home_screen.dart          # Home screen (Calendar and history)
│   ├── add_workout_screen.dart   # Exercise list and editing screen
│   ├── add_workout_detail_screen.dart # Detailed workout logging screen
│   ├── routine_screen.dart       # Weekly routine setup screen
│   ├── settings_screen.dart      # Settings screen
│   └── main_screen.dart          # Main screen with the bottom navigation bar
│
└── main.dart                   # App entry point, DI, theme setup, etc.
```

---

## 🚀 Setup and Usage

1.  Set up your **Flutter SDK**.
2.  Clone this repository.
    ```bash
    git clone [https://github.com/your-username/your-repository-name.git](https://github.com/your-username/your-repository-name.git)
    cd your-repository-name
    ```
3.  Install the required packages.
    ```bash
    flutter pub get
    ```
4.  Build the `drift` generated files. (You need to run this again if you modify `database.dart`)
    ```bash
    flutter pub run build_runner build --delete-conflicting-outputs
    ```
5.  Run the app.
    ```bash
    flutter run
    ```

---

## 📝 Future Plans (TODO)

* [ ] **Statistics & Graphs Feature**:
    * A line chart showing max weight progression for each exercise.
    * Visualization of monthly training volume per body part.
* [ ] **Implement Settings Screen**:
    * Theme switching (Light/Dark mode).
    * Database backup and restore functionality.
* [ ] **Ad Monetization**:
    * Consider implementing timed ads (e.g., 3-minute intervals).
* [ ] **Other Enhancements**:
    * Swipe-to-delete functionality for workout history on the home screen.

---

## 📄 License

This project is licensed under the [MIT License](LICENSE).