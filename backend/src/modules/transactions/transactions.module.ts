import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Transaction } from './entities/transaction.entity';
import { TransactionEntry } from './entities/transaction-entry.entity';
import { Vault } from '../vaults/entities/vault.entity';
import { Customer } from '../customers/entities/customer.entity';
import { TransactionsService } from './transactions.service';
import { TransactionsController } from './transactions.controller';
import { GamificationModule } from '../gamification/gamification.module';
import { BudgetsModule } from '../budgets/budgets.module';
import { NotificationsModule } from '../notifications/notifications.module';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([Transaction, TransactionEntry, Vault, Customer]),
    GamificationModule,
    BudgetsModule,
    NotificationsModule,
    AuditModule,
  ],
  controllers: [TransactionsController],
  providers: [TransactionsService],
  exports: [TransactionsService],
})
export class TransactionsModule {}
