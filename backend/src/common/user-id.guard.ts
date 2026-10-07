import {
  BadRequestException,
  CanActivate,
  ExecutionContext,
  Injectable,
} from '@nestjs/common';

export interface UserRequest {
  headers: Record<string, string | string[] | undefined>;
  userId?: string;
}

@Injectable()
export class UserIdGuard implements CanActivate {
  canActivate(context: ExecutionContext): boolean {
    const request = context.switchToHttp().getRequest<UserRequest>();
    const userId = request.headers['x-user-id'];

    if (typeof userId !== 'string' || !/^[A-Za-z0-9_-]{1,128}$/.test(userId)) {
      throw new BadRequestException({
        code: 'INVALID_USER_ID',
        message:
          'X-User-Id must be 1–128 letters, numbers, underscores, or hyphens.',
      });
    }

    request.userId = userId;
    return true;
  }
}
