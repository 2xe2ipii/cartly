import assert from 'node:assert/strict';
import { test } from 'node:test';
import { BadRequestException, type ExecutionContext } from '@nestjs/common';

import { UserIdGuard, type UserRequest } from './user-id.guard';

function contextFor(request: UserRequest): ExecutionContext {
  return {
    switchToHttp: () => ({ getRequest: () => request }),
  } as unknown as ExecutionContext;
}

test('accepts a valid user ID and attaches it to the request', () => {
  const request: UserRequest = { headers: { 'x-user-id': 'shopper_1' } };
  const guard = new UserIdGuard();

  assert.equal(guard.canActivate(contextFor(request)), true);
  assert.equal(request.userId, 'shopper_1');
});

test('rejects missing and path-unsafe user IDs', () => {
  const guard = new UserIdGuard();

  for (const userId of [undefined, '', 'other/user']) {
    const request: UserRequest = { headers: { 'x-user-id': userId } };
    assert.throws(
      () => guard.canActivate(contextFor(request)),
      (error: unknown) => error instanceof BadRequestException,
    );
  }
});
