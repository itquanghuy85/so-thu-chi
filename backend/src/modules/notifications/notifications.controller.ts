import { Body, Controller, Delete, HttpCode, Patch, UseGuards } from '@nestjs/common';
import { NotificationsService } from './notifications.service';
import { RegisterFcmTokenDto } from './dto/register-fcm-token.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('notifications')
export class NotificationsController {
  constructor(private readonly notificationsService: NotificationsService) {}

  @Patch('fcm-token')
  registerToken(@CurrentUser() user: JwtUserPayload, @Body() dto: RegisterFcmTokenDto) {
    return this.notificationsService.registerToken(user.id, dto.token);
  }

  /// Body carries the specific device's token to remove — see
  /// `NotificationsService.unregisterToken`'s doc comment for why this
  /// can't just be "the" token for the current user anymore.
  @Delete('fcm-token')
  @HttpCode(200)
  unregisterToken(@Body() dto: RegisterFcmTokenDto) {
    return this.notificationsService.unregisterToken(dto.token);
  }
}
