# Cartly

Cartly is a shopping list app built with Flutter (frontend), NestJS (backend API), and Cloud Firestore (database). The architecture isolates Firestore behind NestJS using `X-User-Id` header scoping. For complete design decisions, schemas, and trade-off analysis, see [DESIGN.md](DESIGN.md).

## User story status

| Story | Status | Implementation details |
| --- | --- | --- |
| US-1: See my list | Done | Pre-sorted by database (`isBought ASC, createdAt DESC`). Includes loading, empty, and error states. |
| US-2: Add an item | Done | Validates name and quantity (minimum 1) on both client and backend before writing to Firestore. |
| US-3: Mark bought or unbought | Done | Item toggle API endpoint updates Firestore and triggers list reordering. |
| US-4: Delete an item | Done | Deletes single item from list; handles missing item 404 responses gracefully. |
| US-5: Clear bought items | Partly done | UI confirmation dialog and backend bulk batch delete implemented. The literal single database round-trip acceptance criterion remains unmet (requires query + batch commit in Firestore; see trade-offs in DESIGN.md). |
| US-6: Only see my own items | Done | All endpoints enforce user path scoping based on the `X-User-Id` header. |

## Setup & Local Execution

### Prerequisites
- **Node.js**: v20.19+
- **Flutter**: v3.29+
- **Firebase Project**: Cloud Firestore database enabled

### 1. Backend Configuration
Install dependencies and copy environment variables in `backend/`:

```sh
cd backend
npm ci
cp .env.example .env
```

Configure `backend/.env` with your project parameters:
```dotenv
GOOGLE_CLOUD_PROJECT=your-firebase-project-id
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
PORT=3000
```

### 2. Firestore Composite Index Setup
Deploy the composite index defined in `firestore.indexes.json` (`isBought ASC, createdAt DESC`) via Firebase CLI:

```sh
firebase deploy --only firestore:indexes --project your-firebase-project-id
```

*Note: Alternatively, create the composite index directly in the Firebase Console.*

### 3. Start & Verify Backend API
Build and launch the API server:

```sh
cd backend
npm run build
npm run start
```
The server runs on `http://127.0.0.1:3000`.

To verify API connectivity:
```sh
curl -i -H 'X-User-Id: demo_user' http://127.0.0.1:3000/items
```

### 4. Run the Flutter App

#### iOS Simulator (macOS)
```sh
cd app
flutter pub get
flutter run -d booted --dart-define=API_BASE_URL=http://127.0.0.1:3000 --dart-define=USER_ID=demo_user
```

#### Android Emulator
```sh
cd app
flutter pub get
flutter run -d <device-id> --dart-define=API_BASE_URL=http://10.0.2.2:3000 --dart-define=USER_ID=demo_user
```

#### Windows Desktop
```sh
cd app
flutter pub get
flutter run -d windows --dart-define=API_BASE_URL=http://127.0.0.1:3000 --dart-define=USER_ID=demo_user
```

## Testing

- **Backend Unit & Integration Tests**: Run `npm test` inside `backend/`.
- **Flutter Unit & Widget Tests**: Run `flutter test` inside `app/`.
- **Flutter End-to-End Integration Test**: Run `flutter test integration_test/shopping_flow_test.dart -d booted --dart-define=API_BASE_URL=http://127.0.0.1:3000` inside `app/` (requires running API and booted simulator).
