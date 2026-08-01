import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { UserXp } from './entities/user-xp.entity';
import { XpEvent } from './entities/xp-event.entity';
import { Achievement } from './entities/achievement.entity';
import { UserAchievement } from './entities/user-achievement.entity';
import { QuestClaim } from './entities/quest-claim.entity';
import { GamificationService } from './gamification.service';
import { GamificationController } from './gamification.controller';

@Module({
  imports: [TypeOrmModule.forFeature([UserXp, XpEvent, Achievement, UserAchievement, QuestClaim])],
  controllers: [GamificationController],
  providers: [GamificationService],
  exports: [GamificationService],
})
export class GamificationModule {}
