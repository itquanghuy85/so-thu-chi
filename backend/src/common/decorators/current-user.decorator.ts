import { createParamDecorator, ExecutionContext } from '@nestjs/common';

export interface JwtUserPayload {
  id: string;
  email: string;
}

/**
 * Extracts the authenticated user (set by JwtStrategy.validate) from the
 * request. Usage: `@CurrentUser() user: JwtUserPayload` or
 * `@CurrentUser('id') userId: string`.
 */
export const CurrentUser = createParamDecorator(
  (field: keyof JwtUserPayload | undefined, ctx: ExecutionContext) => {
    const request = ctx.switchToHttp().getRequest();
    const user = request.user as JwtUserPayload;
    return field ? user?.[field] : user;
  },
);
