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
];

export function buildTypeOrmOptions(configService: ConfigService): TypeOrmModuleOptions {
  const nodeEnv = configService.get<string>('NODE_ENV') ?? 'development';
  return {
    type: 'postgres',
    host: configService.get<string>('DB_HOST'),
    port: configService.get<number>('DB_PORT'),
    username: configService.get<string>('DB_USER'),
    password: configService.get<string>('DB_PASSWORD'),
    database: configService.get<string>('DB_NAME'),
    entities,
    // MVP: let TypeORM sync the schema from entities instead of hand-written
    // migrations. Switch this off (and add real migrations) before running
    // against a production database.
    synchronize: nodeEnv !== 'production',
    logging: nodeEnv === 'development' ? ['error', 'warn'] : false,
  };
}
