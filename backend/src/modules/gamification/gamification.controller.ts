import { Body, Controller, Get, HttpCode, Post, Query, UseGuards } from '@nestjs/common';
import { GamificationService } from './gamification.service';
import { GamificationProfileQueryDto } from './dto/gamification-profile.query.dto';
import { ClaimQuestDto } from './dto/claim-quest.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('gamification')
export class GamificationController {
  constructor(private readonly gamificationService: GamificationService) {}

  @Get('profile')
  profile(@CurrentUser() user: JwtUserPayload, @Query() query: GamificationProfileQueryDto) {
    return this.gamificationService.getProfile(user.id, query.workspace_id);
  }

  @Post('claim-quest')
  @HttpCode(200)
  claimQuest(@CurrentUser() user: JwtUserPayload, @Body() dto: ClaimQuestDto) {
    return this.gamificationService.claimQuest(user.id, dto.workspace_id);
  }
}
