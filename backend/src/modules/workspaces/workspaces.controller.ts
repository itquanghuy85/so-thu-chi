import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { WorkspacesService } from './workspaces.service';
import { CreateWorkspaceDto } from './dto/create-workspace.dto';
import { JoinWorkspaceDto } from './dto/join-workspace.dto';
import { UpdateMemberRoleDto } from './dto/update-member-role.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('workspaces')
export class WorkspacesController {
  constructor(private readonly workspacesService: WorkspacesService) {}

  @Get()
  list(@CurrentUser() user: JwtUserPayload) {
    return this.workspacesService.listForUser(user.id);
  }

  @Post()
  create(@CurrentUser() user: JwtUserPayload, @Body() dto: CreateWorkspaceDto) {
    return this.workspacesService.create(user.id, dto);
  }

  @Post('join')
  @HttpCode(200)
  join(@CurrentUser() user: JwtUserPayload, @Body() dto: JoinWorkspaceDto) {
    return this.workspacesService.join(user.id, dto);
  }

  @UseGuards(WorkspaceMemberGuard)
  @Get(':id')
  detail(@Param('id') id: string) {
    return this.workspacesService.getDetail(id);
  }

  @UseGuards(WorkspaceMemberGuard)
  @Post(':id/invite-code')
  @HttpCode(200)
  regenerateInviteCode(@Param('id') id: string, @CurrentUser() user: JwtUserPayload) {
    return this.workspacesService.regenerateInviteCode(id, user.id);
  }

  // `:id` here is the workspace id (guarded), `:userId` is the member to remove.
  @UseGuards(WorkspaceMemberGuard)
  @Delete(':id/members/:userId')
  removeMember(@Param('id') id: string, @Param('userId') userId: string, @CurrentUser() user: JwtUserPayload) {
    return this.workspacesService.removeMember(id, userId, user.id);
  }

  @UseGuards(WorkspaceMemberGuard)
  @Patch(':id/members/:userId/role')
  updateMemberRole(
    @Param('id') id: string,
    @Param('userId') userId: string,
    @CurrentUser() user: JwtUserPayload,
    @Body() dto: UpdateMemberRoleDto,
  ) {
    return this.workspacesService.updateMemberRole(id, userId, user.id, dto.role);
  }
}
