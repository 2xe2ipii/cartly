# Cartly design

**Status:** Phase 1 draft. This file records decisions as they are made; the API contract and clear-bought behavior are still open.

## Request flow

```text
Tap in Flutter → screen controller → API client → NestJS → Firestore
Tap in Flutter ← screen controller ← API client ← NestJS ← Firestore
```

Flutter will call only NestJS. The backend will validate requests and build Firestore paths from the required `X-User-Id` header. One user has one list; no separate list document is needed.

## Firestore model and list query

Each item is one document at `users/{userId}/items/{itemId}`. The `itemId` is a generated document ID.

| Field | Type | Purpose |
| --- | --- | --- |
| `name` | string | Trimmed, nonempty item name |
| `quantity` | integer | Number of units, at least 1 |
| `isBought` | boolean | Starts `false`; controls the two display groups |
| `createdAt` | timestamp | Set when created; never changed by a bought toggle |

The backend will query that user's `items` collection with `isBought` ascending, then `createdAt` descending. Firestore returns unbought items first and newest items first within each group; Dart will not re-sort them. The required collection-scope composite index is declared in `firestore.indexes.json`. Separate item documents allow a single item to be updated or deleted without rewriting the whole list.

## Decisions still to record

- API endpoints, response shapes, and user-story mapping.
- Clear-bought implementation and its database round-trip tradeoff.
- Final tradeoffs and handling of items with equal `createdAt` values.
