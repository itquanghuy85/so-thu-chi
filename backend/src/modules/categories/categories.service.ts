import { Injectable } from '@nestjs/common';
import { InjectDataSource, InjectRepository } from '@nestjs/typeorm';
import { DataSource, Repository } from 'typeorm';
import { Category } from './entities/category.entity';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { Transaction } from '../transactions/entities/transaction.entity';
import { AppException } from '../../common/exceptions/app.exception';

@Injectable()
export class CategoriesService {
  constructor(
    @InjectRepository(Category) private readonly categoriesRepository: Repository<Category>,
    @InjectDataSource() private readonly dataSource: DataSource,
  ) {}

  async list(workspaceId: string, group?: 'income' | 'expense') {
    const categories = await this.categoriesRepository.find({
      where: group ? { workspaceId, groupName: group } : { workspaceId },
      order: { name: 'ASC' },
    });
    return categories.map((c) => ({ id: c.id, name: c.name, group_name: c.groupName, icon: c.icon }));
  }

  async create(workspaceId: string, dto: CreateCategoryDto) {
    const category = this.categoriesRepository.create({
      workspaceId,
      name: dto.name,
      groupName: dto.group_name,
      icon: dto.icon ?? null,
    });
    await this.categoriesRepository.save(category);
    return { id: category.id, name: category.name, group_name: category.groupName, icon: category.icon };
  }

  async update(workspaceId: string, categoryId: string, dto: UpdateCategoryDto) {
    const category = await this.categoriesRepository.findOne({ where: { id: categoryId, workspaceId } });
    if (!category) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy danh mục');
    }
    if (dto.name) category.name = dto.name;
    await this.categoriesRepository.save(category);
    return { id: category.id, name: category.name, group_name: category.groupName, icon: category.icon };
  }

  /// Mục 12.19: "Không thể xóa danh mục nếu đã có giao dịch sử dụng".
  async remove(workspaceId: string, categoryId: string) {
    const category = await this.categoriesRepository.findOne({ where: { id: categoryId, workspaceId } });
    if (!category) {
      throw new AppException('NOT_FOUND', 'Không tìm thấy danh mục');
    }
    const usageCount = await this.dataSource
      .getRepository(Transaction)
      .count({ where: { categoryId } });
    if (usageCount > 0) {
      throw new AppException(
        'CONFLICT',
        `Không thể xóa vì đã có ${usageCount} giao dịch sử dụng`,
      );
    }
    await this.categoriesRepository.delete({ id: categoryId, workspaceId });
    return { success: true };
  }
}
