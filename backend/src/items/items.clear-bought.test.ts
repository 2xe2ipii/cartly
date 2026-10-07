import assert from 'node:assert/strict';
import { test } from 'node:test';
import type { Firestore } from 'firebase-admin/firestore';

import { ItemsService } from './items.service';

function makeService(boughtCount: number) {
  const state = {
    userIds: [] as string[],
    filters: [] as Array<[string, string, boolean]>,
    batches: [] as Array<Array<{ id: string }>>,
    commits: 0,
  };
  const docs = Array.from({ length: boughtCount }, (_, index) => {
    const id = `bought-${index}`;
    return { ref: { id } };
  });
  const firestore = {
    collection: (name: string) => {
      assert.equal(name, 'users');
      return {
        doc: (userId: string) => {
          state.userIds.push(userId);
          return {
            collection: (collectionName: string) => {
              assert.equal(collectionName, 'items');
              return {
                where: (field: string, operator: string, value: boolean) => {
                  state.filters.push([field, operator, value]);
                  return { get: async () => ({ docs }) };
                },
              };
            },
          };
        },
      };
    },
    batch: () => {
      const deletes: Array<{ id: string }> = [];
      state.batches.push(deletes);
      return {
        delete: (ref: { id: string }) => {
          deletes.push({ id: ref.id });
        },
        commit: async () => { state.commits += 1; },
      };
    },
  } as unknown as Firestore;
  return { service: new ItemsService(firestore), state };
}

test('clear bought is a no-op when the user has no bought items', async () => {
  const { service, state } = makeService(0);

  await service.clearBought('shopper_1');

  assert.deepEqual(state.userIds, ['shopper_1']);
  assert.deepEqual(state.filters, [['isBought', '==', true]]);
  assert.equal(state.batches.length, 0);
  assert.equal(state.commits, 0);
});

test('clear bought deletes only queried items in bounded batches', async () => {
  const { service, state } = makeService(401);

  await service.clearBought('shopper_1');

  assert.deepEqual(state.filters, [['isBought', '==', true]]);
  assert.deepEqual(state.batches.map((batch) => batch.length), [400, 1]);
  assert.equal(state.commits, 2);
  assert.deepEqual(state.batches[0][0], { id: 'bought-0' });
  assert.deepEqual(state.batches[1][0], { id: 'bought-400' });
});
