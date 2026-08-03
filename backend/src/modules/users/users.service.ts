import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from './entities/user.entity';

@Injectable()
export class UsersService {
  constructor(@InjectRepository(User) private readonly usersRepository: Repository<User>) {}

  findByEmail(email: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { email } });
  }

  findById(id: string): Promise<User | null> {
    return this.usersRepository.findOne({ where: { id } });
  }

  create(data: Partial<User>): Promise<User> {
    const user = this.usersRepository.create(data);
    return this.usersRepository.save(user);
  }

  async updateProfile(userId: string, data: { fullName?: string; phone?: string }): Promise<User> {
    await this.usersRepository.update({ id: userId }, data);
    return (await this.findById(userId))!;
  }

  async updatePasswordHash(userId: string, passwordHash: string): Promise<void> {
    await this.usersRepository.update({ id: userId }, { passwordHash });
  }

  async updateAvatarUrl(userId: string, avatarUrl: string): Promise<void> {
    await this.usersRepository.update({ id: userId }, { avatarUrl });
  }

  async updatePinHash(userId: string, pinHash: string | null): Promise<void> {
    await this.usersRepository.update({ id: userId }, { pinHash });
  }

  async delete(userId: string): Promise<void> {
    await this.usersRepository.delete({ id: userId });
  }
}
