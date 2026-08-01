import { Body, Controller, Delete, Get, Param, Patch, Post, UseGuards } from '@nestjs/common';
import { BudgetsService } from './budgets.service';
import { CreateBudgetDto } from './dto/create-budget.dto';
import { UpdateBudgetDto } from './dto/update-budget.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:id/budgets')
export class BudgetsController {
  constructor(private readonly budgetsService: BudgetsService) {}

  @Get()
  list(@Param('id') workspaceId: string) {
    return this.budgetsService.list(workspaceId);
  }

  @Post()
  create(@Param('id') workspaceId: string, @Body() dto: CreateBudgetDto) {
    return this.budgetsService.create(workspaceId, dto);
  }

  @Patch(':budgetId')
  update(@Param('id') workspaceId: string, @Param('budgetId') budgetId: string, @Body() dto: UpdateBudgetDto) {
    return this.budgetsService.update(workspaceId, budgetId, dto);
  }

  @Delete(':budgetId')
  remove(@Param('id') workspaceId: string, @Param('budgetId') budgetId: string) {
    return this.budgetsService.remove(workspaceId, budgetId);
  }
}
