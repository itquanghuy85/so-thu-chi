import { Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import type { App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import * as path from 'path';
import { AppException } from '../exceptions/app.exception';

export interface VerifiedSocialUser {
  uid: string;
  email: string | null;
  fullName: string | null;
}

/// Verifies Firebase ID tokens issued after a Google/Apple sign-in on the
/// client (Mục "Đăng nhập với Google/Apple"). Initialized once from the
/// service account key created for this project (see backend/README.md).
@Injectable()
export class FirebaseAdminService implements OnModuleInit {
  private app!: App;

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const existing = getApps();
    if (existing.length > 0) {
      this.app = existing[0];
      return;
    }
    const keyPath = this.configService.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH') || 'firebase-service-account.json';
    const resolved = path.isAbsolute(keyPath) ? keyPath : path.join(process.cwd(), keyPath);
    this.app = initializeApp({
      credential: cert(resolved),
    });
  }

  async verifyIdToken(idToken: string): Promise<VerifiedSocialUser> {
    try {
      const decoded = await getAuth(this.app).verifyIdToken(idToken);
      return {
        uid: decoded.uid,
        email: decoded.email ?? null,
        fullName: (decoded.name as string | undefined) ?? null,
      };
    } catch {
      throw new AppException('UNAUTHORIZED', 'Token đăng nhập không hợp lệ hoặc đã hết hạn');
    }
  }
}
