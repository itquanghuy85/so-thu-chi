import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { TransactionsService } from './transactions.service';
import { CreateTransactionDto } from './dto/create-transaction.dto';
import { ListTransactionsQueryDto } from './dto/list-transactions.query.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller('transactions')
export class TransactionsController {
  constructor(private readonly transactionsService: TransactionsService) {}

  @UseGuards(WorkspaceMemberGuard)
  @Get()
  list(@CurrentUser() user: JwtUserPayload, @Query() query: ListTransactionsQueryDto) {
    return this.transactionsService.list(user.id, query);
  }

  @UseGuards(WorkspaceMemberGuard)
  @Post()
  create(@CurrentUser() user: JwtUserPayload, @Body() dto: CreateTransactionDto) {
    return this.transactionsService.create(user.id, dto);
  }

  // `:id` here is the transaction id, not the workspace id — membership is
  // checked inside the service after resolving the transaction's workspace.
  @Post(':id/void')
  void(@Param('id') id: string, @CurrentUser() user: JwtUserPayload) {
    return this.transactionsService.void(id, user.id);
  }
}
