import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException } from '@nestjs/common';
import type { Firestore } from 'firebase-admin/firestore';

import { ItemsService } from './items.service';

interface TestItem {
  id: string;
  name: string;
  quantity: number;
  isBought: boolean;
}

function makeService(documents: TestItem[] = []) {
  const state = {
    userIds: [] as string[],
    orders: [] as Array<[string, string]>,
    created: [] as Array<Record<string, unknown>>,
  };
  const query = {
    orderBy(field: string, direction: string) {
      state.orders.push([field, direction]);
      return query;
    },
    async get() {
      return {
        docs: documents.map((item) => ({
          id: item.id,
          get: (field: keyof TestItem) => item[field],
        })),
      };
    },
  };
  const items = {
    orderBy: query.orderBy,
    doc: () => ({
      id: 'new-item',
      create: async (data: Record<string, unknown>) => {
        state.created.push(data);
      },
    }),
  };
  const firestore = {
    collection: (name: string) => {
      assert.equal(name, 'users');
      return {
        doc: (userId: string) => {
          state.userIds.push(userId);
          return {
            collection: (collectionName: string) => {
              assert.equal(collectionName, 'items');
              return items;
            },
          };
        },
      };
    },
  } as unknown as Firestore;

  return { service: new ItemsService(firestore), state };
}

test('lists only the requested user path in Firestore order', async () => {
  const { service, state } = makeService([
    { id: 'new', name: 'Milk', quantity: 2, isBought: false },
    { id: 'old', name: 'Bread', quantity: 1, isBought: true },
  ]);

  const result = await service.list('shopper_1');

  assert.deepEqual(state.userIds, ['shopper_1']);
  assert.deepEqual(state.orders, [
    ['isBought', 'asc'],
    ['createdAt', 'desc'],
  ]);
  assert.deepEqual(result.items.map((item) => item.id), ['new', 'old']);
  assert.deepEqual(Object.keys(result.items[0]), [
    'id', 'name', 'quantity', 'isBought',
  ]);
});

test('rejects invalid names and quantities before touching Firestore', async () => {
  const { service, state } = makeService();

  for (const body of [
    { name: '   ', quantity: 1 },
    { name: 'Milk', quantity: 0 },
    { name: 'Milk', quantity: 1.5 },
  ]) {
    await assert.rejects(service.create('shopper_1', body), BadRequestException);
  }

  assert.deepEqual(state.userIds, []);
  assert.deepEqual(state.created, []);
});

test('creates a trimmed, unbought item with a server timestamp', async () => {
  const { service, state } = makeService();

  const result = await service.create('shopper_1', {
    name: '  Milk  ', quantity: 2, isBought: true,
  });

  assert.deepEqual(result, { id: 'new-item' });
  assert.deepEqual(state.userIds, ['shopper_1']);
  assert.equal(state.created[0].name, 'Milk');
  assert.equal(state.created[0].quantity, 2);
  assert.equal(state.created[0].isBought, false);
  assert.ok(state.created[0].createdAt);
});
