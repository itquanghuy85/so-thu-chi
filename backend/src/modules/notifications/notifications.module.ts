import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { NotificationsService } from './notifications.service';
import { NotificationsController } from './notifications.controller';
import { FirebaseAdminService } from '../../common/firebase/firebase-admin.service';
import { PushToken } from './entities/push-token.entity';

@Module({
  imports: [TypeOrmModule.forFeature([PushToken])],
  controllers: [NotificationsController],
  providers: [NotificationsService, FirebaseAdminService],
  exports: [NotificationsService],
})
export class NotificationsModule {}
