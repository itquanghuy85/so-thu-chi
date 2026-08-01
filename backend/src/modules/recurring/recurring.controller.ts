import { Body, Controller, Delete, Get, HttpCode, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { RecurringService } from './recurring.service';
import { CreateRecurringDto } from './dto/create-recurring.dto';
import { UpdateRecurringDto } from './dto/update-recurring.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:id/recurring')
export class RecurringController {
  constructor(private readonly recurringService: RecurringService) {}

  @Get()
  list(@Param('id') workspaceId: string) {
    return this.recurringService.list(workspaceId);
  }

  @Post()
  create(@Param('id') workspaceId: string, @CurrentUser() user: JwtUserPayload, @Body() dto: CreateRecurringDto) {
    return this.recurringService.create(user.id, workspaceId, dto);
  }

  @Patch(':recurringId')
  update(@Param('id') workspaceId: string, @Param('recurringId') recurringId: string, @Body() dto: UpdateRecurringDto) {
    return this.recurringService.update(workspaceId, recurringId, dto);
  }

  @Delete(':recurringId')
  remove(@Param('id') workspaceId: string, @Param('recurringId') recurringId: string) {
    return this.recurringService.remove(workspaceId, recurringId);
  }

  @Post('run-due')
  @HttpCode(200)
  runDue(@Param('id') workspaceId: string) {
    return this.recurringService.runDue(workspaceId);
  }
}
