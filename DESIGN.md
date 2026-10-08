# Cartly design

## Request flow

```text
Tap → Flutter widget → list controller → API client → NestJS route/service → Firestore
Screen ← widget state ← controller ← HTTP response ← NestJS ← Firestore result
```

When a user taps an action in the app, the Flutter UI delegates the request to the list controller and API client layer. The mobile app never talks to Cloud Firestore directly and never places raw `http` calls inside widget trees. Instead, NestJS handles every request, reads the `X-User-Id` header to scope Firestore document paths, validates the incoming payload, and communicates with Firestore using the Firebase Admin SDK.

## Firestore model

Each item is stored as an individual document inside the subcollection `users/{userId}/items/{itemId}` with an auto-generated document ID. Storing each item as its own document allows us to perform fine-grained updates without locking or reading the entire list.

| Field | Type | Purpose |
| --- | --- | --- |
| `name` | string | Trimmed item name |
| `quantity` | integer | Number of items to buy (at least 1) |
| `isBought` | boolean | Toggled when an item is marked bought or put back |
| `createdAt` | timestamp | Server timestamp recorded at item creation |

To satisfy the sorting requirement where unbought items come first and newest items appear on top, I created a composite index on `isBought ASC, createdAt DESC` in `firestore.indexes.json`. Because Firestore handles the sort on the database layer, the API returns pre-sorted data directly to the Dart controller without requiring client-side reordering.

## API endpoints

| Route | Result | Stories |
| --- | --- | --- |
| `GET /items` | Returns sorted list of items with status `200` | US-1, US-6 |
| `POST /items` | Validates input, creates new unbought item, returns `201` | US-2, US-6 |
| `PATCH /items/:id` | Updates item `isBought` status, returns `204` or `404` | US-3, US-6 |
| `DELETE /items/:id` | Deletes a single item, returns `204` or `404` | US-4, US-6 |
| `DELETE /items/bought` | Clears all bought items for the user, returns `204` | US-5, US-6 |

Validation happens on NestJS before writing to Firestore. Every endpoint enforces user path scoping using `X-User-Id`, so requests attempting to access another user's items return a clean `404` error with readable error details.

## Choices and trade-offs

### 1. Document-per-item vs. Single-document array (The US-5 round-trip trade-off)
The brief asks for clearing all bought items in a single database round trip. In Firestore, deleting multiple documents requires a query step to collect the matching document IDs followed by a batch commit, which takes two database round trips behind the NestJS service.

I evaluated a few ways to achieve a literal single database round trip:
* **Single Document Array (`users/{userId}`):** Storing all items inside a single array in one document would allow a single atomic `UPDATE` call. However, this introduces high risk of write concurrency conflicts when a user edits from multiple devices, and it caps the shopping list size at Firestore's 1MB document limit.
* **Async Background Queue / Cloud Tasks:** Triggering an async worker returns an HTTP `202` quickly, but introduces Pub/Sub queues and eventual consistency overhead that over-engineers a simple mobile app.
* **Relational SQL Database:** Using Postgres or MySQL would let us run `DELETE FROM items WHERE user_id = ? AND is_bought = true` in a single SQL statement, but we would lose Firestore's serverless scaling and simple document model.

I chose the document-per-item approach with a read-then-batch-delete pattern. It keeps item mutations simple, prevents document size caps, and allows Firestore's native index to handle sorting smoothly, even though it costs two internal database calls for bulk clearing.

### 2. Trusted user ID header over full authentication
Rather than adding login and session management, the API relies on the `X-User-Id` HTTP header to scope database paths. NestJS validates the header format on every request before touching Firestore. Full authentication and OAuth are explicitly left out of scope per project guidelines to keep the app focused and simple.
