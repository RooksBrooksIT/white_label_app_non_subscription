# ServNex: Developer Documentation & Project Guide

## 1. Project Overview
**ServNex** is a white-labeled service management platform designed for scalability and multi-tenancy. It allows service organizations to manage their engineers, track attendance, and provide a client-facing portal for AMC management.

---

## 2. Directory Structure

| Path | Purpose |
| :--- | :--- |
| **`lib/services/`** | Singleton services for core infrastructure (Auth, Firestore, Theme, Notification). |
| **`lib/frontend/screens/`** | UI screens partitioned into Admin, Engineer, and Customer workflows. |
| **`lib/backend/`** | Business logic that bridges services and the UI (specifically for complex features like Attendance). |
| **`lib/subscription/`** | Logic for multi-tenant billing, plans, and the "White-Labeling" customization interface. |
| **`lib/utils/`** | Shared UI components, constants, and helper classes. |

---

## 3. Core Developer Workflows

### 3.1 Adding a New Feature
1. **Define the Service**: If the feature requires data, add the logic to `FirestoreService` using the tenant-aware `collection()` method.
2. **Create the UI**: Add a new screen in `lib/frontend/screens/`. Use `ThemeService.instance` for all styling.
3. **Register on Dashboard**: Add the navigation entry to `lib/frontend/screens/admin_dashboard.dart` or the relevant role dashboard.

### 3.2 Working with Multitenancy
**Never hardcode a collection name.** Always use the `FirestoreService.instance.collection(name)` method. This ensures that the user's active `tenantId` is automatically prefixed to the database path.

### 3.3 Theming & White-Labeling
The app's appearance is dynamic.
- **To use colors**: Use `ThemeService.instance.primaryColor` instead of `Colors.blue`.
- **To add a branding token**: Update `ThemeService` and the `branding_customization_screen.dart` to allow admins to configure the new token.

---

## 4. Key Services Reference

### [FirestoreService](file:///d:/Rooks%20Tech/white_label_non_subscription/lib/services/firestore_service.dart)
- `instance.collection(name)`: Primary way to access tenant-isolated data.
- `isTenantActive()`: Gating mechanism to check if an organization's subscription is valid.

### [AuthStateService](file:///d:/Rooks%20Tech/white_label_non_subscription/lib/services/auth_state_service.dart)
- `getInitialScreen()`: The startup logic that routes users based on their role and session.
- `loginUser()`: Handles dynamic organization lookup during authentication.

### [ThemeService](file:///d:/Rooks%20Tech/white_label_non_subscription/lib/services/theme_service.dart)
- Reactive singleton that broadcasts changes to UI components when an Admin saves new branding settings.

---

## 5. Coding Standards
- **File Naming**: Use `snake_case.dart`.
- **Class Naming**: Use `PascalCase`.
- **Logic Placement**: Prefer placing logic in **Services** or **Backend** helper classes rather than directly inside `StatefulWidget` states for better testability.
- **Icons**: Use `Icons.rounded` where possible to keep the premium aesthetic consistent.

---

## 6. Deployment & Configuration
- **Firebase**: The project is pre-configured with `firebase_options.dart`. Update this via the FlutterFire CLI if you change the Firebase project.
- **Environment Variables**: Use the `.env` file for API keys and sensitive configuration.

---

## 7. Useful Commands
- `flutter pub get`: Refresh dependencies.
- `flutter pub run flutter_launcher_icons:main`: Regenerate app icons after updating `assets/images/icon.png`.
- `flutter build apk --split-per-abi`: Recommended command for generating production-ready APKs.
