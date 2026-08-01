import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { ShiftsService } from './shifts.service';
import { OpenShiftDto } from './dto/open-shift.dto';
import { CloseShiftDto } from './dto/close-shift.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:id/shifts')
export class ShiftsController {
  constructor(private readonly shiftsService: ShiftsService) {}

  @Get()
  list(@Param('id') workspaceId: string) {
    return this.shiftsService.list(workspaceId);
  }

  @Get('current')
  current(@Param('id') workspaceId: string, @CurrentUser() user: JwtUserPayload) {
    return this.shiftsService.getCurrentOpen(workspaceId, user.id);
  }

  @Post('open')
  open(@Param('id') workspaceId: string, @CurrentUser() user: JwtUserPayload, @Body() dto: OpenShiftDto) {
    return this.shiftsService.open(workspaceId, user.id, dto);
  }

  @Post(':shiftId/close')
  close(
    @Param('id') workspaceId: string,
    @Param('shiftId') shiftId: string,
    @CurrentUser() user: JwtUserPayload,
    @Body() dto: CloseShiftDto,
  ) {
    return this.shiftsService.close(workspaceId, user.id, shiftId, dto);
  }
}
