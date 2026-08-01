import { Module } from '@nestjs/common';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule } from '@nestjs/typeorm';
import { buildTypeOrmOptions } from './config/typeorm.config';
import { AuthModule } from './modules/auth/auth.module';
import { UsersModule } from './modules/users/users.module';
import { WorkspacesModule } from './modules/workspaces/workspaces.module';
import { VaultsModule } from './modules/vaults/vaults.module';
import { CategoriesModule } from './modules/categories/categories.module';
import { TransactionsModule } from './modules/transactions/transactions.module';
import { CustomersModule } from './modules/customers/customers.module';
import { ReportsModule } from './modules/reports/reports.module';
import { GamificationModule } from './modules/gamification/gamification.module';
import { BudgetsModule } from './modules/budgets/budgets.module';
import { RecurringModule } from './modules/recurring/recurring.module';
import { ShiftsModule } from './modules/shifts/shifts.module';
import { NotificationsModule } from './modules/notifications/notifications.module';
import { AuditModule } from './modules/audit/audit.module';
import { DailyClosingsModule } from './modules/daily-closings/daily-closings.module';

@Module({
  imports: [
    ConfigModule.forRoot({ isGlobal: true }),
    TypeOrmModule.forRootAsync({
      imports: [ConfigModule],
      inject: [ConfigService],
      useFactory: buildTypeOrmOptions,
    }),
    AuthModule,
    UsersModule,
    WorkspacesModule,
    VaultsModule,
    CategoriesModule,
    TransactionsModule,
    CustomersModule,
    ReportsModule,
    GamificationModule,
    BudgetsModule,
    RecurringModule,
    ShiftsModule,
    NotificationsModule,
    AuditModule,
    DailyClosingsModule,
  ],
})
export class AppModule {}
