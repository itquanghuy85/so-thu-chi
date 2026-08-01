import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { DailyClosingsService } from './daily-closings.service';
import { CreateDailyClosingDto } from './dto/create-daily-closing.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:id/daily-closings')
export class DailyClosingsController {
  constructor(private readonly dailyClosingsService: DailyClosingsService) {}

  @Get()
  list(@Param('id') workspaceId: string) {
    return this.dailyClosingsService.list(workspaceId);
  }

  @Get('today')
  today(@Param('id') workspaceId: string) {
    return this.dailyClosingsService.todayStatus(workspaceId);
  }

  @Post()
  close(@Param('id') workspaceId: string, @CurrentUser() user: JwtUserPayload, @Body() dto: CreateDailyClosingDto) {
    return this.dailyClosingsService.close(workspaceId, user.id, dto);
  }
}
