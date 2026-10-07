# Cartly

A simple shopping list app: one user, one list. The mobile app will use Flutter, the API will use NestJS, and the API will store items in Cloud Firestore. Flutter will call the API and will not connect to Firestore directly.

## Project status

The repository is being built in phases. The environment and credential template are prepared; the application is not runnable yet. The next phase is the Firestore model and API design in `DESIGN.md`, followed by backend and mobile implementation in separate commits.

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

Complete commands for running the API and mobile app will be added as those parts are built.
