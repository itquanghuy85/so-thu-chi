import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { DailyClosing } from './entities/daily-closing.entity';
import { DailyClosingsService } from './daily-closings.service';
import { DailyClosingsController } from './daily-closings.controller';
import { VaultsModule } from '../vaults/vaults.module';
import { AuditModule } from '../audit/audit.module';

@Module({
  imports: [TypeOrmModule.forFeature([DailyClosing]), VaultsModule, AuditModule],
  controllers: [DailyClosingsController],
  providers: [DailyClosingsService],
  exports: [DailyClosingsService],
})
export class DailyClosingsModule {}
