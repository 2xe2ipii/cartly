import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException, NotFoundException } from '@nestjs/common';
import type { Firestore } from 'firebase-admin/firestore';

import { ItemsService } from './items.service';

function makeService(failure?: Error) {
  const calls: Array<{ userId: string; itemId: string; action: string; value: unknown }> = [];
  const firestore = {
    collection: (name: string) => {
      assert.equal(name, 'users');
      return {
        doc: (userId: string) => ({
          collection: (collectionName: string) => {
            assert.equal(collectionName, 'items');
            return {
              doc: (itemId: string) => ({
                update: async (value: unknown) => {
                  calls.push({ userId, itemId, action: 'update', value });
                  if (failure) throw failure;
                },
                delete: async (value: unknown) => {
                  calls.push({ userId, itemId, action: 'delete', value });
                  if (failure) throw failure;
                },
              }),
            };
          },
        }),
      };
    },
  } as unknown as Firestore;
  return { service: new ItemsService(firestore), calls };
}

test('updates bought state only at the header user path', async () => {
  const { service, calls } = makeService();

  await service.setBought('shopper_1', 'milk', { isBought: true });
  await service.setBought('shopper_1', 'milk', { isBought: false });

  assert.deepEqual(calls, [
    { userId: 'shopper_1', itemId: 'milk', action: 'update', value: { isBought: true } },
    { userId: 'shopper_1', itemId: 'milk', action: 'update', value: { isBought: false } },
  ]);
});

test('rejects invalid bought state and item IDs before Firestore', async () => {
  const { service, calls } = makeService();

  await assert.rejects(service.setBought('shopper_1', 'milk', { isBought: 'true' }), BadRequestException);
  await assert.rejects(service.setBought('shopper_1', 'other/user', { isBought: true }), BadRequestException);
  await assert.rejects(service.remove('shopper_1', 'other/user'), BadRequestException);
  assert.deepEqual(calls, []);
});

test('deletes one item with an existence precondition', async () => {
  const { service, calls } = makeService();

  await service.remove('shopper_1', 'milk');

  assert.deepEqual(calls, [
    { userId: 'shopper_1', itemId: 'milk', action: 'delete', value: { exists: true } },
  ]);
});

test('missing update or delete returns a clear 404', async () => {
  for (const code of [5, 9]) {
    const error = Object.assign(new Error('missing'), { code });
    const { service } = makeService(error);
    for (const operation of [
      service.setBought('shopper_1', 'milk', { isBought: true }),
      service.remove('shopper_1', 'milk'),
    ]) {
      await assert.rejects(operation, (failure: unknown) => {
        assert.ok(failure instanceof NotFoundException);
        assert.deepEqual(failure.getResponse(), {
          code: 'ITEM_NOT_FOUND', message: 'Item not found.',
        });
        return true;
      });
    }
  }
});
