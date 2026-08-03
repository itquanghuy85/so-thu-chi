import { Column, CreateDateColumn, Entity, PrimaryGeneratedColumn, UpdateDateColumn } from 'typeorm';

@Entity('users')
export class User {
  @PrimaryGeneratedColumn('uuid')
  id: string;

  @Column({ unique: true })
  email: string;

  // Nullable: users created via Google/Apple sign-in (social-login.dto) never set a password.
  @Column({ name: 'password_hash', type: 'varchar', nullable: true })
  passwordHash: string | null;

  @Column({ name: 'full_name' })
  fullName: string;

  @Column({ type: 'varchar', nullable: true })
  phone: string | null;

  @Column({ name: 'avatar_url', type: 'varchar', nullable: true })
  avatarUrl: string | null;

  // App-lock PIN (Mục 14, "hai máy cùng đăng nhập 1 tài khoản" — synced
  // across every device on this account, not per-device). Hashed the same
  // way as passwordHash — never stored/transmitted in plaintext; each
  // device caches this hash locally (GET /auth/pin) to verify PIN entry
  // offline via bcrypt.compare, since app-lock must keep working without
  // network.
  @Column({ name: 'pin_hash', type: 'varchar', nullable: true })
  pinHash: string | null;

  @Column({ default: 'vi' })
  locale: string;

  @CreateDateColumn({ name: 'created_at' })
  createdAt: Date;

  @UpdateDateColumn({ name: 'updated_at' })
  updatedAt: Date;
}
