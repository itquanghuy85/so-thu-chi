import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import type { App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getMessaging } from 'firebase-admin/messaging';
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
  private readonly logger = new Logger(FirebaseAdminService.name);

  constructor(private readonly configService: ConfigService) {}

  onModuleInit() {
    const existing = getApps();
    if (existing.length > 0) {
      this.app = existing[0];
      return;
    }

    // Cloud hosts (Render, etc.) build straight from the git repo, which
    // never contains the service account file (git-ignored — it's a
    // secret). There, the whole JSON key is pasted as a single env var
    // instead. Local dev keeps using the file, per backend/README.md.
    const inlineJson = this.configService.get<string>('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (inlineJson) {
      this.app = initializeApp({ credential: cert(JSON.parse(inlineJson)) });
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

  /// Best-effort push send — a failure here (invalid/expired token, FCM
  /// outage) must never bubble up and break the caller's actual mutation
  /// (transaction creation, recurring run, etc.), so every error is caught
  /// and just logged.
  async sendMulticast(tokens: string[], title: string, body: string, data?: Record<string, string>): Promise<void> {
    if (tokens.length === 0) return;
    try {
      await getMessaging(this.app).sendEachForMulticast({
        tokens,
        notification: { title, body },
        data,
      });
    } catch (err) {
      this.logger.warn(`Push notification send failed: ${(err as Error).message}`);
    }
  }
}
