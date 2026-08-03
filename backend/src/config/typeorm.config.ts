import { ConfigService } from '@nestjs/config';
import { TypeOrmModuleOptions } from '@nestjs/typeorm';
import { User } from '../modules/users/entities/user.entity';
import { Workspace } from '../modules/workspaces/entities/workspace.entity';
import { WorkspaceMember } from '../modules/workspaces/entities/workspace-member.entity';
import { Vault } from '../modules/vaults/entities/vault.entity';
import { Category } from '../modules/categories/entities/category.entity';
import { Transaction } from '../modules/transactions/entities/transaction.entity';
import { TransactionEntry } from '../modules/transactions/entities/transaction-entry.entity';
import { Customer } from '../modules/customers/entities/customer.entity';
import { UserXp } from '../modules/gamification/entities/user-xp.entity';
import { XpEvent } from '../modules/gamification/entities/xp-event.entity';
import { Achievement } from '../modules/gamification/entities/achievement.entity';
import { UserAchievement } from '../modules/gamification/entities/user-achievement.entity';
import { QuestClaim } from '../modules/gamification/entities/quest-claim.entity';
import { Budget } from '../modules/budgets/entities/budget.entity';
import { RecurringTransaction } from '../modules/recurring/entities/recurring-transaction.entity';
import { Shift } from '../modules/shifts/entities/shift.entity';
import { AuditLog } from '../modules/audit/entities/audit-log.entity';
import { DailyClosing } from '../modules/daily-closings/entities/daily-closing.entity';
import { PushToken } from '../modules/notifications/entities/push-token.entity';

export const entities = [
  User,
  Workspace,
  WorkspaceMember,
  Vault,
  Category,
  Transaction,
  TransactionEntry,
  Customer,
  UserXp,
  XpEvent,
  Achievement,
  UserAchievement,
  QuestClaim,
  Budget,
  RecurringTransaction,
  Shift,
  AuditLog,
  DailyClosing,
  PushToken,
];

export function buildTypeOrmOptions(configService: ConfigService): TypeOrmModuleOptions {
  const nodeEnv = configService.get<string>('NODE_ENV') ?? 'development';

  // Managed Postgres hosts (Neon, Render, Supabase, ...) hand out one
  // connection string instead of discrete host/port/user/password — prefer
  // it when set, falling back to the discrete DB_* vars for local dev
  // (unchanged from before).
  const databaseUrl = configService.get<string>('DATABASE_URL');
  const connection: Partial<TypeOrmModuleOptions> = databaseUrl
    ? { url: databaseUrl }
    : {
        host: configService.get<string>('DB_HOST'),
        port: configService.get<number>('DB_PORT'),
        username: configService.get<string>('DB_USER'),
        password: configService.get<string>('DB_PASSWORD'),
        database: configService.get<string>('DB_NAME'),
      };

  return {
    type: 'postgres',
    ...connection,
    // Managed Postgres hosts require TLS and typically present a
    // certificate not in Node's default trust store — DB_SSL=true relaxes
    // that check rather than needing the provider's CA bundle configured.
    ssl: configService.get<string>('DB_SSL') === 'true' ? { rejectUnauthorized: false } : false,
    entities,
    // MVP: schema is synced straight from the entities instead of
    // hand-written migrations, intentionally left on even in production for
    // this pass (single-tenant shop app, not a multi-environment SaaS yet).
    // Set DB_SYNC=false once real migrations exist.
    synchronize: configService.get<string>('DB_SYNC') !== 'false',
    logging: nodeEnv === 'development' ? ['error', 'warn'] : false,
  };
}
