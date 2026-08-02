import { Body, Controller, Delete, Get, Param, Post, UseGuards } from '@nestjs/common';
import { CustomersService } from './customers.service';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';
import { CurrentUser } from '../../common/decorators/current-user.decorator';
import type { JwtUserPayload } from '../../common/decorators/current-user.decorator';

@UseGuards(JwtAuthGuard)
@Controller()
export class CustomersController {
  constructor(private readonly customersService: CustomersService) {}

  @UseGuards(WorkspaceMemberGuard)
  @Get('workspaces/:id/customers')
  list(@Param('id') workspaceId: string) {
    return this.customersService.list(workspaceId);
  }

  @UseGuards(WorkspaceMemberGuard)
  @Post('workspaces/:id/customers')
  create(@Param('id') workspaceId: string, @Body() dto: CreateCustomerDto) {
    return this.customersService.create(workspaceId, dto);
  }

  // `:id` here is the customer id, not the workspace id — membership check
  // happens inside the service after resolving the customer's workspace.
  @Get('customers/:id/debt-history')
  debtHistory(@Param('id') customerId: string, @CurrentUser() user: JwtUserPayload) {
    return this.customersService.debtHistory(customerId, user.id);
  }

  @Delete('customers/:id')
  remove(@Param('id') customerId: string, @CurrentUser() user: JwtUserPayload) {
    return this.customersService.remove(customerId, user.id);
  }
}
