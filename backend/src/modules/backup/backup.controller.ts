import { Body, Controller, Get, Param, Post, UseGuards } from '@nestjs/common';
import { BackupService } from './backup.service';
import type { BackupPayload } from './backup.types';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller()
export class BackupController {
  constructor(private readonly backupService: BackupService) {}

  @UseGuards(WorkspaceMemberGuard)
  @Get('workspaces/:id/backup')
  export_(@Param('id') workspaceId: string, @CurrentUser() user: JwtUserPayload) {
    return this.backupService.exportBackup(workspaceId, user.id);
  }

  @Post('workspaces/restore')
  restore(@CurrentUser() user: JwtUserPayload, @Body() body: BackupPayload) {
    return this.backupService.restoreBackup(user.id, body);
  }
}
