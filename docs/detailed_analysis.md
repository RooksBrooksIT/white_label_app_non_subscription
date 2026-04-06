# Detailed Project Analysis: ServNex

## 1. Architectural Philosophy
ServNex is architected as a **Multi-Tenant White-Label Solution** built with Flutter and Firebase. It employs a **Service-Oriented Architecture (SOA)** where business logic is encapsulated in singleton services (e.g., `FirestoreService`, `AuthStateService`, `ThemeService`).

### Key Design Patterns:
- **Singleton Services**: Ensures a single source of truth for global states (Auth, Theme, Database).
- **Tenant Isolation**: Data is separated by `tenantId` (e.g., `OrganizationName_YYYYMMDD`), ensuring that one client's data is never visible to another.
- **Dynamic White-Labeling**: The UI adaptively rebrands itself by fetching a `branding/config` document for the active tenant during the bootstrap process.

---

## 2. Multitenancy & Data Isolation
The project implements a "Database-per-Tenant" logic within a single Firestore instance using collection prefixing and nesting.

### The Global Lookup Pattern
To handle login for users across multiple tenants, a `global_user_directory` collection is used:
- **`uid` (Doc ID)**:
  - `tenantId`: The specific organization bucket.
  - `role`: (admin, engineer, customer).
  - `appName`: For branding context.

### Data Pathing
- Standard path: `/{tenantId}/data/{collectionName}/{documentId}`
- This structure allows the app to support multiple "sub-apps" or datasets under a single organization if needed.

---

## 3. Core Technical Modules

### A. Authentication & Routing (`AuthStateService`)
The entry point (`main.dart`) uses `AuthStateService.getInitialScreen()` to determine the user's destination.
1. **Firebase Session**: Checks for an active `FirebaseAuth` user.
2. **Global Metadata**: Fetches the user's `tenantId` and `role`.
3. **Branding Sync**: Dynamically loads colors/logos before the UI renders.
4. **Subscription Gate**: Validates if the tenant has an active payment plan.
5. **Dashboard Routing**: Directs to `admindashboard`, `EngineerPage`, or `AMCCustomerMainPage`.

### B. Dynamic Theming (`ThemeService`)
The app's aesthetic is not hardcoded. It supports:
- **Custom Primary/Secondary Colors**.
- **Organization Logos**.
- **Custom Font Families** (e.g., Lufga).
- **Dark/Light Mode** toggles stored per tenant.

### C. Resource Management (`FirestoreService`)
A high-level abstraction over `cloud_firestore` that handles:
- **Automatic Path Injection**: Developers call `collection('tickets')`, and the service injects the user's `tenantId`.
- **Subscription Tracking**: Logic for trial periods (30 days), monthly/yearly cycles, and feature toggles (geo-location, barcode, reporting).

---

## 4. Key Workflows

### Engineer Lifecycle
1. **Registration**: Admin creates an engineer account within their tenant.
2. **Attendance**: Engineer marks attendance via `engineer_attendance_screen.dart`, which uses `geolocator` to verify location.
3. **Task Execution**: Engineers receive push notifications (FCM) for new tickets, update status (Pending -> In Progress -> Completed), and can scan barcodes to verify they are working on the correct asset.
4. **Tracking**: The `location_service.dart` periodically streams the engineer's coordinates to Firestore for the Admin's real-time map view.

### Admin Operations
1. **Branding**: Admins can change the app's look and feel via `branding_customization_screen.dart`.
2. **AMC Management**: specialized flow for creating Annual Maintenance Contracts.
3. **Inventory**: Management of "Brand & Model" configurations that customers select when creating tickets.

---

## 5. Technology Stack Deep Dive

| Layer | Technology | Purpose |
| :--- | :--- | :--- |
| **Backend** | Firebase Firestore | Real-time NoSQL storage. |
| **Auth** | Firebase Auth | Email, OTP, and Role-based management. |
| **Maps** | Google Maps & Flutter Map | Engineer tracking and customer location. |
| **Scanner** | `mobile_scanner` | Barcode/QR code identification for assets. |
| **Files** | Firebase Storage | Profile pics, ticket attachments, and generated PDFs. |
| **Reporting** | `pdf` & `printing` | Generating service summaries and invoices. |
| **Animations** | `lottie` | Premium loading states and success animations. |
| **Persistence** | `shared_preferences`| Local caching of session and basic config. |

---

## 6. Critical Files Analysis
- `lib/main.dart`: The hub for initialization and global provider setup.
- `lib/services/auth_state_service.dart`: The brains behind secure, multi-tenant login.
- `lib/frontend/screens/admin_dashboard.dart`: A complex UI orchestrator for 40+ features.
- `lib/services/firestore_service.dart`: The primary data access layer.

---

## 7. Future Scalability & Recommendations
1. **Cloud Functions Partitioning**: Consider moving complex report generation and notification triggers to Firebase Functions to reduce client-side overhead.
2. **State Management**: Current use of `Provider` is solid, but as the app grows, `Riverpod` could offer better compile-time safety for the complex tenant/branding streams.
3. **Offline Support**: While Firestore has built-in persistence, a more explicit "Offline Mode" for engineers in low-connectivity areas would enhance reliability.
