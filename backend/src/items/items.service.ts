import {
  BadRequestException,
  Inject,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { FieldValue, type Firestore } from 'firebase-admin/firestore';

import { FIRESTORE } from '../firestore/firestore.module';

export interface Item {
  id: string;
  name: string;
  quantity: number;
  isBought: boolean;
}

@Injectable()
export class ItemsService {
  constructor(@Inject(FIRESTORE) private readonly firestore: Firestore) {}

  async list(userId: string): Promise<{ items: Item[] }> {
    const snapshot = await this.itemsFor(userId)
      .orderBy('isBought', 'asc')
      .orderBy('createdAt', 'desc')
      .get();

    return {
      items: snapshot.docs.map((doc) => ({
        id: doc.id,
        name: doc.get('name') as string,
        quantity: doc.get('quantity') as number,
        isBought: doc.get('isBought') as boolean,
      })),
    };
  }

  async create(userId: string, body: unknown): Promise<{ id: string }> {
    const input = body && typeof body === 'object' && !Array.isArray(body)
      ? (body as Record<string, unknown>)
      : {};
    const name = typeof input.name === 'string' ? input.name.trim() : '';

    if (!name) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'Name is required.',
      });
    }
    if (name.length > 100) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'Name must be 100 characters or less.',
      });
    }
    if (typeof input.quantity !== 'number' ||
        !Number.isInteger(input.quantity) || input.quantity < 1 || input.quantity > 9999) {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'Quantity must be an integer between 1 and 9999.',
      });
    }

    const ref = this.itemsFor(userId).doc();
    await ref.create({
      name,
      quantity: input.quantity,
      isBought: false,
      createdAt: FieldValue.serverTimestamp(),
    });
    return { id: ref.id };
  }

  async setBought(userId: string, itemId: string, body: unknown): Promise<void> {
    const input = body && typeof body === 'object' && !Array.isArray(body)
      ? (body as Record<string, unknown>)
      : {};
    if (typeof input.isBought !== 'boolean') {
      throw new BadRequestException({
        code: 'VALIDATION_ERROR',
        message: 'isBought must be true or false.',
      });
    }

    try {
      await this.itemFor(userId, itemId).update({ isBought: input.isBought });
    } catch (error) {
      this.rethrowMissingItem(error);
    }
  }

  async remove(userId: string, itemId: string): Promise<void> {
    try {
      await this.itemFor(userId, itemId).delete({ exists: true });
    } catch (error) {
      this.rethrowMissingItem(error);
    }
  }

  async clearBought(userId: string): Promise<void> {
    const snapshot = await this.itemsFor(userId)
      .where('isBought', '==', true)
      .get();

    if (snapshot.docs.length === 0) {
      return;
    }

    const batch = this.firestore.batch();
    for (const doc of snapshot.docs) {
      batch.delete(doc.ref);
    }
    await batch.commit();
  }

  private itemFor(userId: string, itemId: string) {
    if (!/^[A-Za-z0-9_-]{1,128}$/.test(itemId)) {
      throw new BadRequestException({
        code: 'INVALID_ITEM_ID',
        message: 'Item ID is invalid.',
      });
    }
    return this.itemsFor(userId).doc(itemId);
  }

  private rethrowMissingItem(error: unknown): never {
    const code = error && typeof error === 'object' && 'code' in error
      ? error.code
      : undefined;
    if (code === 5 || code === 9) {
      throw new NotFoundException({
        code: 'ITEM_NOT_FOUND',
        message: 'Item not found.',
      });
    }
    throw error;
  }

  private itemsFor(userId: string) {
    return this.firestore.collection('users').doc(userId).collection('items');
  }
}
