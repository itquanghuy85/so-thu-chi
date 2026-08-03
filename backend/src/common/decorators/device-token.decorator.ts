import { createParamDecorator, ExecutionContext } from '@nestjs/common';

/// Reads the `X-Fcm-Token` header the mobile app attaches to every request
/// once it has registered a push token (see `DioClient`'s request
/// interceptor on the mobile side). Used to exclude the *acting device*
/// (not the acting user) from a workspace notification about its own
/// action — see `NotificationsService.notifyWorkspace`'s `excludeToken`.
/// `undefined` for older clients or requests with no registered token yet;
/// callers must treat that as "don't exclude anyone".
export const DeviceToken = createParamDecorator((_: unknown, ctx: ExecutionContext): string | undefined => {
  const request = ctx.switchToHttp().getRequest();
  const header = request.headers['x-fcm-token'];
  return typeof header === 'string' && header.length > 0 ? header : undefined;
});
