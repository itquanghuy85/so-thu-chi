import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Customer } from './entities/customer.entity';
import { Vault } from '../vaults/entities/vault.entity';
import { Transaction } from '../transactions/entities/transaction.entity';
import { TransactionEntry } from '../transactions/entities/transaction-entry.entity';
import { CreateCustomerDto } from './dto/create-customer.dto';
import { AppException } from '../../common/exceptions/app.exception';
import { assertWorkspaceMember } from '../../common/utils/workspace-access.util';

@Injectable()
export class CustomersService {
  constructor(
    @InjectRepository(Customer) private readonly customersRepository: Repository<Customer>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async list(workspaceId: string) {
    const customers = await this.customersRepository.find({
      where: { workspaceId },
      relations: { debtVault: true },
      order: { createdAt: 'DESC' },
    });
    return customers.map((c) => ({
      id: c.id,
      name: c.name,
      phone: c.phone,
      debt_balance: c.debtVault?.currentBalance ?? 0,
      created_at: c.createdAt,
    }));
  }

  async create(workspaceId: string, dto: CreateCustomerDto) {
    return this.dataSource.transaction(async (manager) => {
      const debtVault = manager.create(Vault, {
        workspaceId,
        name: `Công nợ - ${dto.name}`,
        type: 'debt_customer',
        currentBalance: 0,
      });
      await manager.save(debtVault);

      const customer = manager.create(Customer, {
        workspaceId,
        name: dto.name,
        phone: dto.phone ?? null,
        debtVaultId: debtVault.id,
      });
      await manager.save(customer);

      return {
        id: customer.id,
        name: customer.name,
        phone: customer.phone,
        debt_balance: debtVault.currentBalance,
      };
    });
  }

  async debtHistory(customerId: string, userId: string) {
    const customer = await this.customersRepository.findOne({ where: { id: customerId } });
    if (!customer) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy khách hàng');
    }
    await assertWorkspaceMember(this.dataSource, customer.workspaceId, userId);

    const entries = await this.dataSource.getRepository(TransactionEntry).find({
      where: { vaultId: customer.debtVaultId },
      relations: { transaction: { category: true } },
    });
    const transactionsById = new Map<string, Transaction>();
    for (const entry of entries) {
      if (entry.transaction) {
        transactionsById.set(entry.transaction.id, entry.transaction);
      }
    }
    const transactions = [...transactionsById.values()].sort(
      (a, b) => new Date(b.createdAt).getTime() - new Date(a.createdAt).getTime(),
    );

    return transactions.map((t) => ({
      id: t.id,
      type: t.type,
      amount: t.amount,
      note: t.note,
      status: t.status,
      category: t.category ? { id: t.category.id, name: t.category.name } : null,
      created_at: t.createdAt,
    }));
  }
}
