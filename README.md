# Cartly

A simple shopping list app: one user, one list. The mobile app will use Flutter, the API will use NestJS, and the API will store items in Cloud Firestore. Flutter will call the API and will not connect to Firestore directly.

## Project status

The architecture and index are documented in `DESIGN.md`. All five NestJS item routes are implemented and verified against the configured Firebase project. The mobile app is pending.

| User story | Status |
| --- | --- |
| US-1: See my list | Partly done: backend route and live database ordering verified; mobile screen pending |
| US-2: Add an item | Partly done: backend route verified; mobile form pending |
| US-3: Mark bought or unbought | Partly done: backend route verified; mobile toggle and reorder pending |
| US-4: Delete an item | Partly done: backend route verified; mobile action pending |
| US-5: Clear bought items | Partly done: backend route verified; mobile action pending; literal one-database-round-trip criterion remains unmet |
| US-6: Only see my own items | Partly done: every backend route is scoped to the supplied user ID; mobile header integration pending |

## Environment

Each developer needs their own Firebase project and service-account JSON key outside this repository. Copy `backend/.env.example` to `backend/.env`, then set the absolute key path and project ID. The local `.env` and JSON key must not be committed.

To start the backend on a clean machine, install Node.js 20.19 or later, then run:

```sh
cd backend
npm ci
cp .env.example .env
# Edit .env with your Firebase project ID and the absolute key path.
npm run build
npm run start
```

The server listens on `PORT` from `backend/.env` (3000 by default). Every item request needs an `X-User-Id` header containing 1–128 letters, numbers, underscores, or hyphens. The API provides `GET /items`, `POST /items`, `PATCH /items/:id`, `DELETE /items/:id`, and `DELETE /items/bought`. Run `npm test` in `backend/` for the focused service and guard tests.

Before an ordered list query can work in a new Firebase project, create the `items` collection-scope composite index defined in `firestore.indexes.json` (`isBought` ascending, `createdAt` descending). You can create it in the Firebase console or, after signing in with Firebase CLI, run this from the repository root:

```sh
firebase deploy --only firestore:indexes --project your-firebase-project-id
```

The configured development project has this index in `READY` state. The live `GET /items` route and the other item routes passed an isolated API smoke test; temporary test documents were removed. For a new project, wait until Firestore reports the index as ready before testing the ordered list route.
