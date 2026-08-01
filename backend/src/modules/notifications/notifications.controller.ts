import { Body, Controller, Delete, Patch, UseGuards } from '@nestjs/common';
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

  @Delete('fcm-token')
  unregisterToken(@CurrentUser() user: JwtUserPayload) {
    return this.notificationsService.unregisterToken(user.id);
  }
}
