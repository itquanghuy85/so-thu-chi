import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryColumn } from 'typeorm';
import { Achievement } from './achievement.entity';

@Entity('user_achievements')
export class UserAchievement {
  @PrimaryColumn({ name: 'user_id' })
  userId: string;

  @PrimaryColumn({ name: 'achievement_id' })
  achievementId: string;

  @ManyToOne(() => Achievement, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'achievement_id' })
  achievement: Achievement;

  @Column({ name: 'workspace_id' })
  workspaceId: string;

  @CreateDateColumn({ name: 'unlocked_at' })
  unlockedAt: Date;
}
