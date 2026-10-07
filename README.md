# Cartly

A simple shopping list app: one user, one list. The mobile app will use Flutter, the API will use NestJS, and the API will store items in Cloud Firestore. Flutter will call the API and will not connect to Firestore directly.

## Project status

The architecture and index are documented in `DESIGN.md`. The NestJS backend now builds and starts, but it has no item routes yet; the mobile app is not built.

| User story | Status |
| --- | --- |
| US-1: See my list | Not started |
| US-2: Add an item | Not started |
| US-3: Mark bought or unbought | Not started |
| US-4: Delete an item | Not started |
| US-5: Clear bought items | Not started |
| US-6: Only see my own items | Not started |

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

The server listens on `PORT` from `backend/.env` (3000 by default). A request to `/` currently returns 404 because item routes have not been added. Starting the server initializes Firebase Admin, but a live Firestore request has not yet been verified.
