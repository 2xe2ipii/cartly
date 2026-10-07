import { createParamDecorator, ExecutionContext } from '@nestjs/common';

import type { UserRequest } from './user-id.guard';

export const UserId = createParamDecorator(
  (_data: unknown, context: ExecutionContext): string => {
    const request = context.switchToHttp().getRequest<UserRequest>();
    return request.userId as string;
  },
);
