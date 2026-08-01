import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, IsNull, Repository } from 'typeorm';
import { Budget } from './entities/budget.entity';
import { Transaction } from '../transactions/entities/transaction.entity';
import { CreateBudgetDto } from './dto/create-budget.dto';
import { UpdateBudgetDto } from './dto/update-budget.dto';
import { AppException } from '../../common/exceptions/app.exception';

@Injectable()
export class BudgetsService {
  constructor(
    @InjectRepository(Budget) private readonly budgetsRepository: Repository<Budget>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async create(workspaceId: string, dto: CreateBudgetDto) {
    const existing = await this.budgetsRepository.findOne({
      where: { workspaceId, categoryId: dto.category_id ?? IsNull() },
    });
    if (existing) {
      throw new AppException(
        'CONFLICT',
        dto.category_id ? 'Danh mục này đã có ngân sách, hãy sửa thay vì tạo mới' : 'Đã có ngân sách tổng, hãy sửa thay vì tạo mới',
      );
    }
    const budget = this.budgetsRepository.create({
      workspaceId,
      categoryId: dto.category_id ?? null,
      limitAmount: dto.limit_amount,
    });
    await this.budgetsRepository.save(budget);
    return this.getOne(workspaceId, budget.id);
  }

  async update(workspaceId: string, budgetId: string, dto: UpdateBudgetDto) {
    const budget = await this.budgetsRepository.findOne({ where: { id: budgetId, workspaceId } });
    if (!budget) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy ngân sách');
    }
    budget.limitAmount = dto.limit_amount;
    await this.budgetsRepository.save(budget);
    return this.getOne(workspaceId, budget.id);
  }

  /// Re-fetches with the `category` relation loaded — `.save()` doesn't
  /// populate relations on the in-memory entity, so building the response
  /// straight off it would always show `category: null` even when set.
  private async getOne(workspaceId: string, budgetId: string) {
    const budget = await this.budgetsRepository.findOne({ where: { id: budgetId, workspaceId }, relations: { category: true } });
    if (!budget) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy ngân sách');
    }
    return this.toDto(budget, await this.spentThisMonth(workspaceId, budget.categoryId));
  }

  async remove(workspaceId: string, budgetId: string) {
    const budget = await this.budgetsRepository.findOne({ where: { id: budgetId, workspaceId } });
    if (!budget) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy ngân sách');
    }
    await this.budgetsRepository.delete({ id: budgetId, workspaceId });
    return { success: true };
  }

  async list(workspaceId: string) {
    const budgets = await this.budgetsRepository.find({
      where: { workspaceId },
      relations: { category: true },
      order: { createdAt: 'ASC' },
    });
    return Promise.all(
      budgets.map(async (b) => this.toDto(b, await this.spentThisMonth(workspaceId, b.categoryId))),
    );
  }

  private toDto(budget: Budget, spent: number) {
    return {
      id: budget.id,
      category: budget.category ? { id: budget.category.id, name: budget.category.name } : null,
      limit_amount: budget.limitAmount,
      spent_this_month: spent,
      remaining: budget.limitAmount - spent,
      over_budget: spent > budget.limitAmount,
    };
  }

  /// Returns the budgets (category-specific + the workspace-wide one, if
  /// any) that this transaction's amount just pushed over their monthly
  /// limit — i.e. spend was at-or-under the limit before this amount was
  /// added and is over it now. Used to fire a one-time "over budget" push
  /// notification instead of one on every subsequent expense.
  async checkJustCrossedLimit(
    workspaceId: string,
    categoryId: string | null,
    justAddedAmount: number,
  ): Promise<{ categoryName: string | null; limitAmount: number; spent: number }[]> {
    const candidates = await this.budgetsRepository.find({
      where: categoryId ? [{ workspaceId, categoryId }, { workspaceId, categoryId: IsNull() }] : [{ workspaceId, categoryId: IsNull() }],
      relations: { category: true },
    });
    const crossed: { categoryName: string | null; limitAmount: number; spent: number }[] = [];
    for (const budget of candidates) {
      const spent = await this.spentThisMonth(workspaceId, budget.categoryId);
      const spentBefore = spent - justAddedAmount;
      if (spentBefore <= budget.limitAmount && spent > budget.limitAmount) {
        crossed.push({ categoryName: budget.category?.name ?? null, limitAmount: budget.limitAmount, spent });
      }
    }
    return crossed;
  }

  private async spentThisMonth(workspaceId: string, categoryId: string | null): Promise<number> {
    const now = new Date();
    const monthStart = new Date(now.getFullYear(), now.getMonth(), 1);

    const qb = this.dataSource
      .getRepository(Transaction)
      .createQueryBuilder('t')
      .select('COALESCE(SUM(t.amount), 0)', 'sum')
      .where('t.workspaceId = :workspaceId', { workspaceId })
      .andWhere('t.type = :type', { type: 'expense' })
      .andWhere('t.status = :status', { status: 'completed' })
      .andWhere('t.createdAt >= :monthStart', { monthStart });

    if (categoryId) {
      qb.andWhere('t.categoryId = :categoryId', { categoryId });
    }

    const raw = await qb.getRawOne<{ sum: string }>();
    return parseInt(raw?.sum ?? '0', 10) || 0;
  }
}
