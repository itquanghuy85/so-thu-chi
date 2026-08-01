import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Customer } from './entities/customer.entity';
import { Vault } from '../vaults/entities/vault.entity';
import { Transaction } from '../transactions/entities/transaction.entity';
import { TransactionEntry } from '../transactions/entities/transaction-entry.entity';
import { CustomersService } from './customers.service';
import { CustomersController } from './customers.controller';

@Module({
  imports: [TypeOrmModule.forFeature([Customer, Vault, Transaction, TransactionEntry])],
  controllers: [CustomersController],
  providers: [CustomersService],
  exports: [CustomersService],
})
export class CustomersModule {}
