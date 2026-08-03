import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { cert, getApps, initializeApp } from 'firebase-admin/app';
import type { App } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getMessaging } from 'firebase-admin/messaging';
import { getStorage } from 'firebase-admin/storage';
import * as path from 'path';
import { AppException } from '../exceptions/app.exception';

// From android/app/google-services.json / ios/Runner/GoogleService-Info.plist
// (project `sothuchi-d055a`) — same bucket for both platforms.
const STORAGE_BUCKET = 'sothuchi-d055a.firebasestorage.app';

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
      this.app = initializeApp({ credential: cert(JSON.parse(inlineJson)), storageBucket: STORAGE_BUCKET });
      return;
    }

    const keyPath = this.configService.get<string>('FIREBASE_SERVICE_ACCOUNT_PATH') || 'firebase-service-account.json';
    const resolved = path.isAbsolute(keyPath) ? keyPath : path.join(process.cwd(), keyPath);
    this.app = initializeApp({
      credential: cert(resolved),
      storageBucket: STORAGE_BUCKET,
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

  /// "Ảnh đại diện" (Trang cá nhân): uploads under a fixed per-user path
  /// (`avatars/<userId>.jpg`, so a re-upload just overwrites the old one —
  /// no orphaned files to clean up) and returns a public download URL in
  /// the same `firebasestorage.googleapis.com/...?alt=media&token=...`
  /// shape the Firebase client SDKs generate. That token-based URL form is
  /// deliberate: it bypasses Firebase Storage Security Rules for the GET
  /// itself (knowing the token is the authorization), which sidesteps two
  /// real constraints here — the bucket's default rules require a Firebase
  /// Auth session, which email/password users on this app never have
  /// (they authenticate against this backend's own JWT instead, Firebase
  /// Auth is only used transiently for the Google/Apple sign-in exchange);
  /// and it needs no bucket-level "public" IAM/ACL grant, only Storage
  /// write access on the existing service account. A fresh random token
  /// per upload also makes the URL change every time, so clients don't
  /// need to cache-bust a stale cached image after changing photos.
  async uploadAvatar(userId: string, buffer: Buffer, contentType: string): Promise<string> {
    const bucket = getStorage(this.app).bucket();
    const filePath = `avatars/${userId}.jpg`;
    const file = bucket.file(filePath);
    const token = randomUUID();
    try {
      await file.save(buffer, {
        contentType,
        metadata: { metadata: { firebaseStorageDownloadTokens: token } },
      });
    } catch (err) {
      this.logger.error(`Avatar upload failed: ${(err as Error).message}`);
      throw new AppException('INTERNAL_ERROR', 'Không thể tải ảnh lên. Vui lòng thử lại sau.');
    }
    return `https://firebasestorage.googleapis.com/v0/b/${bucket.name}/o/${encodeURIComponent(filePath)}?alt=media&token=${token}`;
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
