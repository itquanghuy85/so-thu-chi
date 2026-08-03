import { Column, CreateDateColumn, Entity, JoinColumn, ManyToOne, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';
import { User } from '../../users/entities/user.entity';

/// One row per *device* (unique on `token`), not per user — a user can be
/// logged in on several devices at once (Mục — "hai máy cùng đăng nhập 1
/// tài khoản") and every one of them should be reachable for pushes. Used
/// to replace the earlier single `users.fcm_token` column, which only ever
/// remembered the most-recently-registered device and silently dropped
/// pushes to any other device on the same account.
@Entity('push_tokens')
export class PushToken {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ name: 'user_id' })
  userId: string;

  @ManyToOne(() => User, { onDelete: 'CASCADE' })
  @JoinColumn({ name: 'user_id' })
  user: User;

  @Column({ unique: true })
  token: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
