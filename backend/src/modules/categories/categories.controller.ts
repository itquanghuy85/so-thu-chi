import { Body, Controller, Delete, Get, Param, Patch, Post, Query, UseGuards } from '@nestjs/common';
import { CategoriesService } from './categories.service';
import { CreateCategoryDto } from './dto/create-category.dto';
import { UpdateCategoryDto } from './dto/update-category.dto';
import { ListCategoriesQueryDto } from './dto/list-categories.query.dto';
import { JwtAuthGuard } from '../../common/guards/jwt-auth.guard';
import { WorkspaceMemberGuard } from '../../common/guards/workspace-member.guard';

@UseGuards(JwtAuthGuard, WorkspaceMemberGuard)
@Controller('workspaces/:id/categories')
export class CategoriesController {
  constructor(private readonly categoriesService: CategoriesService) {}

  @Get()
  list(@Param('id') workspaceId: string, @Query() query: ListCategoriesQueryDto) {
    return this.categoriesService.list(workspaceId, query.group);
  }

  @Post()
  create(@Param('id') workspaceId: string, @Body() dto: CreateCategoryDto) {
    return this.categoriesService.create(workspaceId, dto);
  }

  @Patch(':categoryId')
  update(@Param('id') workspaceId: string, @Param('categoryId') categoryId: string, @Body() dto: UpdateCategoryDto) {
    return this.categoriesService.update(workspaceId, categoryId, dto);
  }

  @Delete(':categoryId')
  remove(@Param('id') workspaceId: string, @Param('categoryId') categoryId: string) {
    return this.categoriesService.remove(workspaceId, categoryId);
  }
}
