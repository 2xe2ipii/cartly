# Cartly design

**Phase 1 design complete; US-5's one-database-round-trip criterion remains unmet.**

## Request flow

```text
Tap → Flutter widget → list controller → API client → NestJS validation/service → Firestore
Screen ← controller ← API client ← HTTP response ← NestJS ← Firestore result
```

Flutter calls only NestJS; widgets do not issue HTTP. NestJS validates input and scopes Firestore paths to the required `X-User-Id` header.

## Firestore model

Each item is a document at `users/{userId}/items/{itemId}` with a generated ID. No separate list document is needed.

| Field | Type | Rule |
| --- | --- | --- |
| `name` | string | Trimmed and nonempty |
| `quantity` | integer | At least 1 |
| `isBought` | boolean | Initially `false` |
| `createdAt` | timestamp | Server timestamp at creation; unchanged by toggles |

One document per item permits targeted changes. Firestore orders the list by `isBought ASC, createdAt DESC` using the collection-scope index in `firestore.indexes.json`; Dart keeps that order. Ties use Firestore's implicit `__name__ DESC` order. [Index ordering](https://firebase.google.com/docs/firestore/query-data/index-overview)

## API contract

| Endpoint | Input → Firestore action → success | Stories |
| --- | --- | --- |
| `GET /items` | Ordered query → `200 {"items":[...]}` | US-1, US-6 |
| `POST /items` | `{"name":"Milk","quantity":2}` → create unbought item → `201 {"id":"..."}` | US-2, US-6 |
| `PATCH /items/:id` | `{"isBought":true}` or `false` → update item → `204` | US-3, US-6 |
| `DELETE /items/:id` | Delete item → `204` | US-4, US-6 |
| `DELETE /items/bought` | Delete bought items → `204`, also when empty | US-5, US-6 |

All routes reject a missing or invalid path-segment user ID with `400`. Paths use that ID, so another user's item ID yields `404`. Invalid inputs get `400` before any write; missing items get `404`, and database failures get 5xx. Errors contain readable `{ "code": "...", "message": "..." }`, which Flutter displays. List items include only `id`, `name`, `quantity`, and `isBought`. Flutter shows loading, empty, and error/retry states, then reloads the database-ordered list after changes.

## Choices and costs

1. **Clear bought:** Query this user's `isBought == true` documents, then delete their references in one batch for a small list; larger lists need more batches. An empty result needs no write, and unbought items are untouched. This is one app request but at least two database calls (read, commit), so **US-5's literal one-round-trip condition is unmet**. Evaluated 1-round-trip alternatives were rejected for Phase 1:
   - *Async Cloud Function / Task Queue:* Achieves near-zero HTTP latency (~10ms) via `202 Accepted`, but introduces Pub/Sub queue infrastructure, eventual consistency, and over-engineering for Phase 1 list scales.
   - *Single Document Array (`users/{userId}`):* Achieves a true 1-round-trip `UPDATE`, but causes write-concurrency conflicts on multi-device edits and risks hitting Firestore's 1MB document size limit.
   - *Soft Delete + TTL:* Google background TTL cleans up expired docs, but explicit bulk deletion on demand still requires querying document IDs first (2 DB calls), while passive auto-expiration violates US-5's explicit "Clear Bought" user requirement.
   - *Relational SQL Database:* `DELETE FROM items WHERE ...` runs in 1 database statement, but forfeits Firestore's real-time SDK listeners and offline sync.
   [Deletion guidance](https://firebase.google.com/docs/firestore/manage-data/delete-data) · [Batched writes](https://firebase.google.com/docs/firestore/manage-data/transactions)
2. **Trusted header:** Backend path scoping cannot prove who supplied `X-User-Id`; a caller can impersonate a known ID. Login is outside scope. The server SDK bypasses Firestore Security Rules, so NestJS enforces this boundary on every route. [Server SDK security](https://firebase.google.com/docs/firestore/security/rules-conditions)
