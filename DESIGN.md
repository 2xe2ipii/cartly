# Cartly design

**Status:** Phase 1 draft. This file records decisions as they are made; clear-bought behavior and final tradeoffs are still open.

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

## API contract

Every request requires `X-User-Id`. The backend rejects a missing, blank, or invalid document-path ID with HTTP 400 and uses only that ID to select Firestore paths. An item ID under another user's path is treated as missing (HTTP 404).

| Method and path | Request → success response | Stories |
| --- | --- | --- |
| `GET /items` | No body → `200 {"items":[...]}` in database order | US-1, US-6 |
| `POST /items` | `{"name":"Milk","quantity":2}` → `201 {"id":"..."}` | US-2, US-6 |
| `PATCH /items/:id` | `{"isBought":true}` or `false` → `204` | US-3, US-6 |
| `DELETE /items/:id` | No body → `204` | US-4, US-6 |
| `DELETE /items/bought` | No body → `204`, including when none are bought | US-5, US-6 |

Each returned item contains only `id`, `name`, `quantity`, and `isBought`; the backend uses `createdAt` for sorting but the screen does not need it. Setting an explicit `isBought` value makes a retried patch safe. After a successful change, Flutter reloads `GET /items` to display the database's order.

Invalid names, quantities, or patch values receive HTTP 400 before a write. Missing items receive HTTP 404. Errors use `{"code":"VALIDATION_ERROR","message":"Quantity must be at least 1."}` as the response shape, with a specific code and readable message for each case. A database failure receives a 5xx response; the list screen shows an error with retry.

## Decisions still to record

- Clear-bought implementation and its database round-trip tradeoff.
- Final tradeoffs and handling of items with equal `createdAt` values.
