import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { VaultsService } from './vaults.service';
import { CreateVaultDto } from './dto/create-vault.dto';
import { ReconcileVaultDto } from './dto/reconcile-vault.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller()
export class VaultsController {
  constructor(private readonly vaultsService: VaultsService) {}

  @UseGuards(WorkspaceMemberGuard)
  @Get('workspaces/:id/vaults')
  list(@Param('id') workspaceId: string) {
    return this.vaultsService.listForWorkspace(workspaceId);
  }

  @UseGuards(WorkspaceMemberGuard)
  @Post('workspaces/:id/vaults')
  create(@Param('id') workspaceId: string, @Body() dto: CreateVaultDto) {
    return this.vaultsService.create(workspaceId, dto);
  }

  // Not workspace-scoped by path (`:id` here is the vault id) — membership
  // is checked inside the service after resolving the vault's workspace.
  @Post('vaults/:id/reconcile')
  reconcile(@Param('id') vaultId: string, @CurrentUser() user: JwtUserPayload, @Body() dto: ReconcileVaultDto) {
    return this.vaultsService.reconcile(vaultId, user.id, dto);
  }

  @Delete('vaults/:id')
  remove(@Param('id') vaultId: string, @CurrentUser() user: JwtUserPayload) {
    return this.vaultsService.remove(vaultId, user.id);
  }
}
