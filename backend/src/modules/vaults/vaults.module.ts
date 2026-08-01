import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Vault } from './entities/vault.entity';
import { VaultsService } from './vaults.service';
import { VaultsController } from './vaults.controller';
import { GamificationModule } from '../gamification/gamification.module';

@Module({
  imports: [TypeOrmModule.forFeature([Vault]), GamificationModule],
  controllers: [VaultsController],
  providers: [VaultsService],
  exports: [VaultsService],
})
export class VaultsModule {}
