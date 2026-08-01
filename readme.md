

# TÀI LIỆU ĐẶC TẢ KỸ THUẬT PHẦN MỀM

## Ứng dụng Quản lý Dòng tiền cho Chủ Shop & Gia đình

**Tên dự án:** Sổ Thu Chi (mã kỹ thuật nội bộ: MoneyFlow)  
**Phiên bản tài liệu:** 4.1 – Hoàn chỉnh toàn diện, tối ưu định dạng tiền tệ & đa ngôn ngữ  
**Ngày:** 2026-07-31  
**Mục tiêu:** Xây dựng ứng dụng giúp chủ shop hoặc chủ gia đình theo dõi toàn bộ dòng tiền một cách minh bạch, dễ dàng và thông minh.

---

## Mục lục

1. [Giới thiệu chung](#1-giới-thiệu-chung)  
2. [Yêu cầu người dùng và phạm vi](#2-yêu-cầu-người-dùng-và-phạm-vi)  
3. [Kiến trúc hệ thống](#3-kiến-trúc-hệ-thống)  
4. [Công nghệ và công cụ](#4-công-nghệ-và-công-cụ)  
5. [Thiết kế cơ sở dữ liệu chi tiết](#5-thiết-kế-cơ-sở-dữ-liệu-chi-tiết)  
6. [Thiết kế API chi tiết](#6-thiết-kế-api-chi-tiết)  
7. [Xác thực và phân quyền](#7-xác-thực-và-phân-quyền)  
8. [Luồng nghiệp vụ chính](#8-luồng-nghiệp-vụ-chính)  
9. [Hệ thống Gamification (Game Leon)](#9-hệ-thống-gamification-game-leon)  
10. [Tính năng AI – Nhập liệu bằng giọng nói](#10-tính-năng-ai--nhập-liệu-bằng-giọng-nói)  
11. [Hệ thống thông báo](#11-hệ-thống-thông-báo)  
12. [Thiết kế giao diện người dùng chi tiết](#12-thiết-kế-giao-diện-người-dùng-chi-tiết)  
13. [Chiến lược offline-first và đồng bộ](#13-chiến-lược-offline-first-và-đồng-bộ)  
14. [Bảo mật và hiệu năng](#14-bảo-mật-và-hiệu-năng)  
15. [Kế hoạch phát triển và triển khai](#15-kế-hoạch-phát-triển-và-triển-khai)  
16. [Phụ lục](#16-phụ-lục)  
17. [Mô hình kinh doanh: Freemium & Quảng cáo](#17-mô-hình-kinh-doanh-freemium--quảng-cáo)  
18. [Cấu trúc dự án Flutter](#18-cấu-trúc-dự-án-flutter)  
19. [Quy tắc Validation](#19-quy-tắc-validation)  
20. [Chiến lược Test](#20-chiến-lược-test)  
21. [Đa ngôn ngữ (i18n)](#21-đa-ngôn-ngữ-i18n)

---

## 1. Giới thiệu chung

### 1.1. Tổng quan
Sổ Thu Chi là ứng dụng quản lý tài chính cá nhân/nhóm dành cho:
- Chủ cửa hàng nhỏ (shop quần áo, tạp hóa, ăn uống…).
- Chủ gia đình muốn quản lý chi tiêu, tiết kiệm và các khoản đóng góp.

### 1.2. Bài toán
- Chủ shop thường không biết chính xác mình có bao nhiêu tiền (tiền mặt, ngân hàng, ví điện tử, công nợ).
- Ghi chép thủ công dễ sai sót, không theo dõi được dòng tiền chi tiết.
- Khó phân biệt tiền shop và tiền cá nhân.
- Cần một công cụ đơn giản, nhanh chóng, có thể dùng mọi lúc mọi nơi.

### 1.3. Giải pháp
- **Mô hình túi tiền (Vault)**: Mỗi nơi chứa tiền là một túi. Giao dịch luôn là sự di chuyển tiền giữa các túi.
- **Giao dịch kép (Double-entry)**: Đảm bảo số dư luôn khớp.
- **Đa không gian làm việc**: Tách bạch shop, gia đình, quỹ riêng.
- **AI và tự động hóa**: Nhập liệu bằng giọng nói, quét hóa đơn, đồng bộ ngân hàng.
- **Gamification**: Tạo động lực quản lý tài chính qua nhân vật Leon.

---

## 2. Yêu cầu người dùng và phạm vi

### 2.1. Đối tượng người dùng
- **Chủ sở hữu (Owner)**: Toàn quyền trong workspace.
- **Quản lý (Manager)**: Có thể xem báo cáo, quản lý giao dịch, công nợ.
- **Thu ngân (Cashier)**: Chỉ tạo giao dịch thu/chi trong ca, xem túi được gán.
- **Thành viên gia đình (Member)**: Xem và thêm giao dịch (nếu được phân quyền).

### 2.2. Tính năng cốt lõi
1. Quản lý túi tiền (tạo, sửa, xóa, kiểm kê).
2. Tạo giao dịch thu, chi, chuyển tiền (thủ công hoặc bằng giọng nói).
3. Quản lý công nợ khách hàng (bán thiếu, trả nợ, nhắc nợ).
4. Báo cáo dòng tiền, lợi nhuận, số dư theo thời gian.
5. Mời thành viên, phân quyền chi tiết.
6. Hoạt động offline, đồng bộ khi có mạng.
7. Gamification với nhân vật Leon (chủ đề game).
8. Tích hợp AI (voice, OCR), thông báo đẩy.

---

## 3. Kiến trúc hệ thống

### 3.1. Mô hình tổng thể
```
[Mobile App]  ↔  [API Gateway (Kong/Nginx)]  ↔  [Microservices]  ↔  [PostgreSQL]
[Web App]           (REST / WebSocket)            ↑                [Redis]
                                                   ↓
                                            [Message Queue (RabbitMQ)]
                                                   ↓
                                            [Workers: Bank Sync, OCR, Voice, Notification]
```

### 3.2. Các service chính
- **Gateway**: Định tuyến, xác thực, rate limit.
- **Auth Service**: Đăng ký/đăng nhập, JWT, OAuth2.
- **Workspace Service**: CRUD workspace, thành viên, vai trò.
- **Vault Service**: Quản lý túi tiền, kiểm kê.
- **Transaction Service**: Xử lý giao dịch (event sourcing), đảm bảo double-entry.
- **Debt Service**: Khách hàng, công nợ.
- **Report Service**: Tổng hợp báo cáo (dùng materialized view).
- **Gamification Service**: XP, level, quest, achievements.
- **Voice Service**: Nhận dạng giọng nói, NLU.
- **Notification Service**: Gửi push/in-app notification.

### 3.3. Offline-first
- Mobile có SQLite local, lưu transaction vào hàng đợi.
- Khi online, gửi batch lên server, giải quyết xung đột bằng vector clock.

---

## 4. Công nghệ và công cụ

| Lớp | Công nghệ | Ghi chú |
| :--- | :--- | :--- |
| Mobile | Flutter 3.x | Đa nền tảng, UI phong phú, hỗ trợ animation |
| Web | React 18 + Next.js | SEO tốt, dễ mở rộng |
| Backend | Node.js + NestJS | Kiến trúc module, dễ test |
| Database | PostgreSQL 15 + Redis 7 | PostgreSQL chính, Redis cache/realtime |
| Message Queue | RabbitMQ | Xử lý bất đồng bộ |
| Object Storage | MinIO (tương thích S3) | Lưu ảnh hóa đơn, avatar |
| Push Notification | Firebase Cloud Messaging | Cả Android và iOS |
| CI/CD | GitHub Actions, Docker, Kubernetes | Triển khai tự động |
| AI/ML | Whisper.cpp (STT on-device), TensorFlow Lite (NLU nhẹ), OpenAI GPT-4o mini (NLU cloud) | |
| Real-time | WebSocket (Socket.io) | Cập nhật số dư, thông báo |

---

## 5. Thiết kế cơ sở dữ liệu chi tiết

### 5.1. Lược đồ quan hệ (tối giản hóa cho tài liệu)
- **users** 1–∞ **workspace_members** ∞–1 **workspaces**
- **workspaces** 1–∞ **vaults**, **categories**, **transactions**, **customers**, **quests**, ...
- **transactions** 1–∞ **transaction_entries** ∞–1 **vaults**
- **customers** 1–1 **vaults** (loại debt_customer)

### 5.2. Định nghĩa bảng chi tiết

#### 5.2.1. users
```sql
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(100),
    avatar_url TEXT,
    phone VARCHAR(20),
    email_verified BOOLEAN DEFAULT FALSE,
    locale VARCHAR(5) NOT NULL DEFAULT 'vi',  -- 'vi' | 'en', dùng cho i18n (Mục 21)
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_users_email ON users(email);
```

#### 5.2.2. workspaces
```sql
CREATE TABLE workspaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    owner_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(20) NOT NULL CHECK (type IN ('shop','family')),
    avatar_url TEXT,
    invite_code VARCHAR(20) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### 5.2.3. roles
```sql
CREATE TABLE roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(50) NOT NULL,
    permissions JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```
Ví dụ permissions mặc định:
- **Owner**: `{"*": true}`
- **Manager**: `{"vaults:view": true, "transactions:*": true, "debt:*": true, "reports:view": true}`
- **Cashier**: `{"vaults:view": ["assigned"], "transactions:create": true}`

#### 5.2.4. workspace_members
```sql
CREATE TABLE workspace_members (
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_id UUID NOT NULL REFERENCES roles(id),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (workspace_id, user_id)
);
```

#### 5.2.5. vaults
```sql
CREATE TABLE vaults (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    type VARCHAR(30) NOT NULL CHECK (type IN ('cash','bank','ewallet','debt_customer','owner_wallet','virtual')),
    current_balance DECIMAL(15,0) NOT NULL DEFAULT 0,
    last_reconciled_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_vaults_workspace ON vaults(workspace_id);
```
Các loại vault:
- `cash`: tiền mặt (két, ví)
- `bank`: tài khoản ngân hàng
- `ewallet`: Momo, ZaloPay...
- `debt_customer`: công nợ của một khách hàng (tự động tạo khi thêm khách)
- `owner_wallet`: ví cá nhân của chủ
- `virtual`: dùng cho bút toán kép (ví dụ: `doanh thu`, `chi phí`)

#### 5.2.6. categories
```sql
CREATE TABLE categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    group_name VARCHAR(20) NOT NULL CHECK (group_name IN ('income','expense')),
    icon VARCHAR(50),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### 5.2.7. transactions
```sql
CREATE TABLE transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    type VARCHAR(20) NOT NULL CHECK (type IN ('income','expense','transfer','debt_increase','debt_decrease')),
    category_id UUID REFERENCES categories(id),
    amount DECIMAL(15,0) NOT NULL,
    note TEXT,
    status VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('pending','completed','voided')),
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    metadata JSONB
);
CREATE INDEX idx_transactions_workspace_date ON transactions(workspace_id, created_at DESC);
```

#### 5.2.8. transaction_entries (double-entry)
```sql
CREATE TABLE transaction_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    transaction_id UUID NOT NULL REFERENCES transactions(id) ON DELETE CASCADE,
    vault_id UUID NOT NULL REFERENCES vaults(id),
    side CHAR(1) NOT NULL CHECK (side IN ('D','C')), -- Debit / Credit
    amount DECIMAL(15,0) NOT NULL
);
CREATE INDEX idx_entries_transaction ON transaction_entries(transaction_id);
```

Ví dụ: thu 500k tiền mặt bán hàng:
- Entry 1: vault `cash` side D, amount 500000
- Entry 2: vault `revenue` (virtual) side C, amount 500000

#### 5.2.9. customers
```sql
CREATE TABLE customers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(100),
    phone VARCHAR(20),
    debt_vault_id UUID UNIQUE REFERENCES vaults(id) ON DELETE SET NULL,
    due_date DATE,                    -- ngày hẹn trả nợ mặc định cho khách này
    note TEXT,                        -- ghi chú nội bộ về khách hàng
    search_text TEXT,                 -- tên đã chuẩn hóa: bỏ dấu, lowercase, để tìm không dấu
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_customers_workspace ON customers(workspace_id);
CREATE INDEX idx_customers_due ON customers(workspace_id, due_date)
    WHERE debt_vault_id IS NOT NULL;
CREATE INDEX idx_customers_search ON customers USING gin (search_text gin_trgm_ops);
```
**Tìm kiếm không dấu:** `search_text` được server tính lại mỗi khi `name` thay đổi (trigger hoặc ở tầng Service), bằng cách bỏ dấu tiếng Việt, chuyển lowercase và loại ký tự đặc biệt (vd: “Nguyễn Văn Á” → `nguyen van a`). Khi người dùng gõ tìm kiếm ở màn hình Công nợ (Mục 12.10), client gửi nguyên input; server chuẩn hóa input theo cùng quy tắc rồi so khớp với `search_text` (`ILIKE '%...%'` hoặc full-text search). Phía server dùng `lodash.deburr` hoặc bảng map dấu tiếng Việt tự viết; phía Flutter (khi cần lọc local trên SQLite) dùng package `diacritic`. Cùng quy tắc chuẩn hóa này có thể áp dụng cho tìm kiếm danh mục (`categories`) nếu cần.

#### 5.2.10. reconciliations
```sql
CREATE TABLE reconciliations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    vault_id UUID NOT NULL REFERENCES vaults(id),
    system_balance DECIMAL(15,0) NOT NULL,
    actual_balance DECIMAL(15,0) NOT NULL,
    difference DECIMAL(15,0) GENERATED ALWAYS AS (actual_balance - system_balance) STORED,
    reason TEXT,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### 5.2.11. shifts
```sql
CREATE TABLE shifts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    vault_id UUID NOT NULL REFERENCES vaults(id), -- túi tiền mặt của ca
    start_at TIMESTAMPTZ NOT NULL,
    end_at TIMESTAMPTZ,
    opening_balance DECIMAL(15,0),
    closing_balance DECIMAL(15,0),
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','closed'))
);
```

#### 5.2.12. voice_commands
```sql
CREATE TABLE voice_commands (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id),
    transcript TEXT,
    intent VARCHAR(50),
    entities JSONB,
    status VARCHAR(20) DEFAULT 'pending',
    transaction_id UUID REFERENCES transactions(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

#### 5.2.13. Gamification tables
```sql
CREATE TABLE user_xp (
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    xp INT NOT NULL DEFAULT 0,
    level INT NOT NULL DEFAULT 1,
    PRIMARY KEY (workspace_id, user_id)
);

CREATE TABLE quests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    type VARCHAR(50), -- daily, weekly, achievement
    description TEXT NOT NULL,
    target INT NOT NULL,
    reward_xp INT NOT NULL,
    starts_at TIMESTAMPTZ,
    ends_at TIMESTAMPTZ
);

CREATE TABLE user_quests (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    quest_id UUID NOT NULL REFERENCES quests(id) ON DELETE CASCADE,
    progress INT DEFAULT 0,
    completed_at TIMESTAMPTZ,
    PRIMARY KEY (user_id, quest_id)
);

CREATE TABLE achievements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    criteria JSONB NOT NULL,
    reward JSONB
);

CREATE TABLE user_achievements (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    achievement_id UUID NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, achievement_id)
);

CREATE TABLE leon_outfits (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    outfit_type VARCHAR(50)
);
```

#### 5.2.14. notifications
```sql
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    type VARCHAR(50) NOT NULL,
    title VARCHAR(255) NOT NULL,
    body TEXT,
    data JSONB,
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_notifications_user ON notifications(workspace_id, user_id, created_at DESC);
```

#### 5.2.15. push_tokens
```sql
CREATE TABLE push_tokens (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    token TEXT NOT NULL UNIQUE,
    platform VARCHAR(10) NOT NULL CHECK (platform IN ('android','ios','web')),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_push_tokens_user ON push_tokens(user_id) WHERE is_active = TRUE;
```
Mục đích: Lưu FCM/APNs device token. Một user có thể có nhiều token (đăng nhập nhiều thiết bị). Khi gửi notification, server gửi đến tất cả token active. Token được đăng ký khi user đăng nhập và hủy khi đăng xuất.

#### 5.2.16. recurring_transactions
```sql
CREATE TABLE recurring_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    created_by UUID NOT NULL REFERENCES users(id),
    template JSONB NOT NULL,
    -- template: { type, from_vault_id, to_vault_id, amount, category_id, note }
    frequency VARCHAR(20) NOT NULL CHECK (frequency IN ('daily','weekly','monthly','yearly')),
    next_run DATE NOT NULL,
    end_date DATE,
    is_active BOOLEAN DEFAULT TRUE,
    last_run_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_recurring_active ON recurring_transactions(next_run)
    WHERE is_active = TRUE;
```
Mục đích: Cron job chạy hàng ngày lúc 00:05 UTC, truy vấn `next_run <= CURRENT_DATE AND is_active = TRUE`, tạo transaction thực từ `template`, cập nhật `next_run` theo `frequency` và `last_run_at = NOW()`.

---

### 5.3. Bảng bổ sung: Audit Log
```sql
CREATE TABLE audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID REFERENCES workspaces(id) ON DELETE CASCADE,
    actor_id UUID NOT NULL REFERENCES users(id),
    action VARCHAR(60) NOT NULL,
    -- Các giá trị hành động:
    -- 'transaction.create', 'transaction.void'
    -- 'vault.reconcile', 'vault.create', 'vault.update'
    -- 'member.invite', 'member.remove', 'role.update'
    -- 'shift.open', 'shift.close'
    -- 'customer.create', 'customer.update'
    -- 'workspace.update', 'subscription.upgrade'
    entity_type VARCHAR(50),   -- 'transaction','vault','customer','role','shift',...
    entity_id UUID,
    old_values JSONB,          -- snapshot trước khi thay đổi (NULL nếu là create)
    new_values JSONB,          -- snapshot sau khi thay đổi (NULL nếu là delete)
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_workspace ON audit_logs(workspace_id, created_at DESC);
CREATE INDEX idx_audit_actor ON audit_logs(actor_id, created_at DESC);
CREATE INDEX idx_audit_entity ON audit_logs(entity_type, entity_id);
```

### 5.4. Bảng bổ sung: Cashier Vault Assignment
```sql
CREATE TABLE cashier_vaults (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    vault_id UUID NOT NULL REFERENCES vaults(id) ON DELETE CASCADE,
    assigned_by UUID NOT NULL REFERENCES users(id),
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, vault_id)
);
CREATE INDEX idx_cashier_vaults_user ON cashier_vaults(user_id);
```
Mục đích: Khi middleware kiểm tra quyền `vaults:view` của Cashier, join thêm với bảng này để chỉ trả về các vault được phân công. Owner/Manager quản lý phân công tại: Cài đặt → Quản lý thành viên → chọn Cashier → Gán túi tiền.

### 5.5. Bảng bổ sung: Ngân sách (Budget)
```sql
CREATE TABLE budgets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    workspace_id UUID NOT NULL REFERENCES workspaces(id) ON DELETE CASCADE,
    category_id UUID REFERENCES categories(id) ON DELETE SET NULL,
    name VARCHAR(100),
    amount DECIMAL(15,0) NOT NULL CHECK (amount > 0),
    period VARCHAR(10) NOT NULL CHECK (period IN ('weekly','monthly','yearly')),
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    alert_threshold INT NOT NULL DEFAULT 80
        CHECK (alert_threshold BETWEEN 1 AND 100),
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_budgets_workspace ON budgets(workspace_id, start_date DESC);
```
Lưu ý:
- `end_date` do client tính và gửi lên (monthly → `start_date + 1 month - 1 day`). Server validate `end_date > start_date`.
- `alert_threshold = 80` → cảnh báo khi chi tiêu đạt 80% hạn mức.
- Tính toán số tiền đã chi: JOIN với `transaction_entries` theo `category_id` và khoảng thời gian `start_date → end_date`.

### 5.6. SQLite/Drift Local Schema (Flutter)

Package: **`drift: ^2.x`**. Kiểu dữ liệu ánh xạ:

| PostgreSQL | Drift | Ghi chú |
|---|---|---|
| UUID | `TextColumn` | Lưu dạng string |
| VARCHAR, TEXT | `TextColumn` | |
| DECIMAL, NUMERIC | `RealColumn` | |
| BOOLEAN | `BoolColumn` | |
| INT | `IntColumn` | |
| TIMESTAMPTZ | `TextColumn` | ISO 8601 UTC string |
| DATE | `TextColumn` | `yyyy-MM-dd` |
| JSONB | `TextColumn` | JSON string |

```dart
// lib/data/local/tables/

class UsersTable extends Table {
  TextColumn get id => text()();
  TextColumn get email => text()();
  TextColumn get fullName => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class WorkspacesTable extends Table {
  TextColumn get id => text()();
  TextColumn get ownerId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()(); // 'shop' | 'family'
  TextColumn get inviteCode => text().nullable()();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class VaultsTable extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  TextColumn get type => text()();
  RealColumn get currentBalance => real().withDefault(const Constant(0.0))();
  TextColumn get lastReconciledAt => text().nullable()();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

class CategoriesTable extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text()();
  TextColumn get groupName => text()(); // 'income' | 'expense'
  TextColumn get icon => text().nullable()();
  @override
  Set<Column> get primaryKey => {id};
}

class TransactionsTable extends Table {
  TextColumn get id => text()();         // local UUID trước sync
  TextColumn get workspaceId => text()();
  TextColumn get type => text()();
  TextColumn get categoryId => text().nullable()();
  RealColumn get amount => real()();
  TextColumn get note => text().nullable()();
  TextColumn get status => text()();     // 'pending_sync'|'completed'|'voided'
  TextColumn get createdBy => text()();
  TextColumn get fromVaultId => text().nullable()();
  TextColumn get toVaultId => text().nullable()();
  TextColumn get createdAt => text()();
  TextColumn get updatedAt => text()();
  BoolColumn get isSynced => boolean().withDefault(const Constant(false))();
  TextColumn get serverId => text().nullable()(); // UUID server trả về sau sync
  @override
  Set<Column> get primaryKey => {id};
}

class CustomersTable extends Table {
  TextColumn get id => text()();
  TextColumn get workspaceId => text()();
  TextColumn get name => text().nullable()();
  TextColumn get phone => text().nullable()();
  TextColumn get debtVaultId => text().nullable()();
  TextColumn get dueDate => text().nullable()();
  TextColumn get updatedAt => text()();
  @override
  Set<Column> get primaryKey => {id};
}

// Hàng đợi offline – lưu operation khi không có mạng
class SyncQueueTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get operation => text()();
  // Ví dụ: 'create_transaction', 'void_transaction', 'reconcile'
  TextColumn get payload => text()(); // JSON body của API request
  TextColumn get createdAt => text()();
  IntColumn get retryCount => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();
}

@DriftDatabase(tables: [
  UsersTable, WorkspacesTable, VaultsTable, CategoriesTable,
  TransactionsTable, CustomersTable, SyncQueueTable,
])
class AppDatabase extends _\$AppDatabase {
  AppDatabase(QueryExecutor e) : super(e);
  @override
  int get schemaVersion => 1;
}
```

Lưu ý quan trọng:
- Khi tạo transaction offline: `id = uuid_v4()`, `isSynced = false`, thêm vào `SyncQueueTable`.
- `SyncService` xử lý queue theo FIFO khi app có kết nối, retry tối đa 3 lần.
- Sau sync thành công: cập nhật `serverId = server_uuid`, `isSynced = true`, xóa khỏi queue.

---

## 6. Thiết kế API chi tiết

Base URL: `https://api.moneyflow.app/v1`  
Tất cả response JSON. Auth: `Authorization: Bearer <access_token>`.

### 6.0. Định dạng lỗi chuẩn (Error Response Format)

Mọi response lỗi đều theo cấu trúc:
```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "Số tiền phải lớn hơn 0",
    "details": [
      { "field": "amount", "message": "phải lớn hơn 0" }
    ]
  }
}
```

Bảng mã lỗi:

| HTTP Status | code | Mô tả |
|---|---|---|
| 400 | `VALIDATION_ERROR` | Dữ liệu gửi lên không hợp lệ |
| 401 | `UNAUTHORIZED` | Không có hoặc token hết hạn |
| 401 | `INVALID_CREDENTIALS` | Email/password sai |
| 401 | `EMAIL_NOT_VERIFIED` | Email chưa xác thực |
| 403 | `FORBIDDEN` | Không có quyền thực hiện thao tác này |
| 404 | `NOT_FOUND` | Tài nguyên không tồn tại |
| 409 | `CONFLICT` | Dữ liệu bị xung đột (email đã tồn tại, shift đang mở...) |
| 422 | `INSUFFICIENT_BALANCE` | Số dư túi tiền không đủ |
| 422 | `VAULT_NOT_IN_WORKSPACE` | Vault không thuộc workspace hiện tại |
| 429 | `RATE_LIMIT_EXCEEDED` | Vượt quá giới hạn request |
| 500 | `INTERNAL_ERROR` | Lỗi hệ thống nội bộ |

### 6.1. Authentication
#### `POST /auth/register`
Request:
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!",
  "full_name": "Nguyen Van A"
}
```
Response 201:
```json
{
  "user": { "id": "uuid", "email": "...", ... },
  "access_token": "...",
  "refresh_token": "..."
}
```

#### `POST /auth/login`
Request:
```json
{
  "email": "user@example.com",
  "password": "SecurePass123!"
}
```
Response 200: (tương tự trên)

#### `POST /auth/refresh`
Request: `{ "refresh_token": "..." }`  
Response: cặp token mới.

#### `POST /auth/forgot-password`
Request: `{ "email": "user@example.com" }`  
Response 200: `{ "message": "Nếu email tồn tại, mã OTP đã được gửi" }`  
Server tạo OTP 6 số, hết hạn sau 15 phút, lưu vào Redis.

#### `POST /auth/reset-password`
Request:
```json
{
  "email": "user@example.com",
  "otp": "123456",
  "new_password": "NewSecurePass123!"
}
```
Response 200: `{ "message": "Mật khẩu đã được đặt lại" }`  
Lỗi: 400 `INVALID_OTP` | 400 `OTP_EXPIRED`.

#### `POST /auth/verify-email`
Request: `{ "email": "user@example.com", "otp": "123456" }`  
Response 200: `{ "message": "Email đã xác thực", "access_token": "...", "refresh_token": "..." }`

#### `PATCH /auth/change-password`
Request:
```json
{
  "current_password": "OldPass123!",
  "new_password": "NewPass456!"
}
```
Response 200: `{ "message": "Mật khẩu đã cập nhật" }`  
Lỗi: 400 `INVALID_CREDENTIALS` nếu mật khẩu hiện tại sai.

#### `POST /auth/register-token`
Request: `{ "token": "fcm_device_token", "platform": "android" }`  
Response 200: `{ "message": "Token đã đăng ký" }`  
Gọi sau khi đăng nhập thành công để lưu push token vào bảng `push_tokens`.

#### `DELETE /auth/logout`
Request: `{ "refresh_token": "...", "push_token": "fcm_token" }`  
Server: thu hồi refresh token, vô hiệu hóa push token tương ứng.
#### `GET /workspaces`
Response:
```json
[
  {
    "id": "uuid",
    "name": "Shop ABC",
    "type": "shop",
    "owner_id": "...",
    "member_count": 3,
    "role": "owner"
  }
]
```

#### `POST /workspaces`
Request:
```json
{
  "name": "Gia đình",
  "type": "family"
}
```

#### `GET /workspaces/{id}/members`
#### `POST /workspaces/{id}/invite`
```json
{
  "email": "newmember@example.com",
  "role_id": "uuid"
}
```
#### `PUT /workspaces/{id}/members/{user_id}/role`
```json
{ "role_id": "uuid" }
```

### 6.3. Vaults
#### `GET /workspaces/{id}/vaults`
Response:
```json
[
  {
    "id": "uuid",
    "name": "Túi thu ngân",
    "type": "cash",
    "current_balance": 1500000,
    "last_reconciled_at": null
  }
]
```

#### `POST /workspaces/{id}/vaults`
```json
{
  "name": "TK ACB",
  "type": "bank",
  "initial_balance": 5000000
}
```

#### `GET /vaults/{id}`
Trả về chi tiết vault, bao gồm lịch sử giao dịch (phân trang).

#### `POST /vaults/{id}/reconcile`
```json
{
  "actual_balance": 1480000,
  "reason": "Thiếu 20k do khách trả thiếu"
}
```
Response: tạo reconciliation và nếu lệch, tự động tạo transaction điều chỉnh.

### 6.4. Transactions
#### `GET /transactions?workspace_id=...&type=income&vault_id=...&from_date=...&to_date=...&page=1&limit=20`
Response:
```json
{
  "data": [
    {
      "id": "uuid",
      "type": "income",
      "amount": 300000,
      "note": "Bán tai nghe",
      "category": { "id": "...", "name": "Bán hàng" },
      "from_vault": { "id": "...", "name": "Doanh thu" },
      "to_vault": { "id": "...", "name": "Tiền mặt" },
      "created_at": "..."
    }
  ],
  "pagination": { "page": 1, "total_pages": 10 }
}
```

#### `POST /transactions`
Tùy loại, body khác nhau:
- **Income:** 
```json
{
  "type": "income",
  "workspace_id": "...",
  "to_vault_id": "cash_vault_id",
  "from_vault_id": "revenue_virtual_id",
  "amount": 300000,
  "category_id": "...",
  "note": "Bán tai nghe"
}
```
- **Expense:** 
```json
{
  "type": "expense",
  "workspace_id": "...",
  "from_vault_id": "bank_vault_id",
  "to_vault_id": "expense_virtual_id",
  "amount": 100000,
  "category_id": "...",
  "note": "Tiền điện"
}
```
- **Transfer:**
```json
{
  "type": "transfer",
  "workspace_id": "...",
  "from_vault_id": "acb_vault_id",
  "to_vault_id": "momo_vault_id",
  "amount": 500000,
  "note": "Chuyển tiền qua Momo"
}
```
- **Debt increase (bán thiếu):**
```json
{
  "type": "debt_increase",
  "customer_id": "...",
  "amount": 500000,
  "note": "Bán thiếu quạt"
}
```
- **Debt decrease (trả nợ):**
```json
{
  "type": "debt_decrease",
  "customer_id": "...",
  "to_vault_id": "cash_vault_id",
  "amount": 200000
}
```

Response: transaction object kèm entries.  
Lưu ý: Server tự động tạo entries và cập nhật vault balances trong một transaction DB.

#### `POST /transactions/{id}/void`
Tạo reversal entries, cập nhật balances.

### 6.5. Customers & Debt
#### `GET /workspaces/{id}/customers`
#### `POST /workspaces/{id}/customers`
```json
{
  "name": "Nguyễn Văn B",
  "phone": "0901234567"
}
```
Hệ thống tự tạo vault `debt_customer` cho khách này.

#### `GET /customers/{id}/debt-history`
#### `POST /customers/{id}/debt-increase` và `debt-decrease` (đã gộp vào transactions)

### 6.6. Reports
#### `GET /reports/cashflow?workspace_id=...&period=this_month`
Response:
```json
{
  "period": "2026-07",
  "total_income": 15000000,
  "total_expense": 8000000,
  "net_cashflow": 7000000,
  "details": {
    "income": [ { "category": "Bán hàng", "amount": 12000000 }, ... ],
    "expense": [ { "category": "Nhập hàng", "amount": 5000000 }, ... ]
  }
}
```

#### `GET /reports/profit-loss?workspace_id=...&period=...`
#### `GET /reports/vault-summary?workspace_id=...`

### 6.7. Voice AI
#### `POST /voice/commands` (multipart/form-data)
- `audio`: file .wav
- `context`: JSON (workspace_id, current_shift_vault_id, recent_categories...)
Response:
```json
{
  "id": "cmd-uuid",
  "status": "resolved",
  "transaction": { ... }
}
```
Nếu cần confirm: `status: "confirmation_required"` kèm `questions`.

#### `POST /voice/commands/{id}/confirm`
```json
{
  "answers": { "vault": "cash_vault_id" }
}
```

### 6.8. Gamification
#### `GET /gamification/profile?workspace_id=...`
#### `POST /gamification/claim-quest/{quest_id}`
#### `POST /gamification/equip-outfit` (body: `{ "outfit_type": "royal_cape" }`)

### 6.9. Notifications
#### `GET /notifications?workspace_id=...&page=...`
#### `PUT /notifications/{id}/read`

### 6.10. WebSocket
Kết nối: `wss://api.moneyflow.app/ws?token=jwt_token`  
Server push event:
- `vault_updated`: `{ vault_id, new_balance }`
- `new_notification`: `{ notification_id, title, body }`
- `xp_updated`: `{ xp, level }`

### 6.11. Sync API (Offline-first)

#### `POST /sync/transactions`
Gửi bách giao dịch offline lên server.
Request:
```json
{
  "transactions": [
    {
      "local_id": "uuid-local-001",
      "type": "income",
      "workspace_id": "...",
      "to_vault_id": "...",
      "from_vault_id": "...",
      "amount": 300000,
      "category_id": "...",
      "note": "Bán tai nghe",
      "created_at": "2026-07-31T10:00:00Z"
    }
  ]
}
```
Response 200:
```json
{
  "results": [
    { "local_id": "uuid-local-001", "server_id": "uuid-server", "status": "success" },
    { "local_id": "uuid-local-002", "status": "error", "error": { "code": "INSUFFICIENT_BALANCE", "message": "..." } }
  ]
}
```
Server xử lý tuần tự theo `created_at`. Nếu một transaction lỗi, các transaction tiếp theo vẫn được xử lý.

#### `GET /sync/updates?since={timestamp}&workspace_id={id}`
Lấy tất cả thay đổi từ server kể từ timestamp.
Response 200:
```json
{
  "server_time": "2026-07-31T12:00:00Z",
  "vaults": [ { ...vault objects... } ],
  "categories": [ { ...category objects... } ],
  "customers": [ { ...customer objects... } ],
  "transactions": [ { ...transactions updated since timestamp... } ]
}
```
Client lưu `server_time` để dùng làm `since` cho lần sync tiếp theo.

### 6.12. Shift API (Ca làm việc)

#### `GET /workspaces/{id}/shifts?status=active&page=1&limit=20`
Response: danh sách shift kèm tóm tắt (tổng thu, tổng chi, số giao dịch).

#### `POST /workspaces/{id}/shifts`
Mở ca mới.
Request:
```json
{
  "user_id": "cashier_uuid",
  "vault_id": "cash_vault_uuid"
}
```
Lỗi 409 `CONFLICT` nếu cashier đã có ca đang mở.

#### `GET /shifts/{id}`
Response: thông tin ca + danh sách giao dịch trong ca (phân trang).

#### `POST /shifts/{id}/close`
Đóng ca.
Request:
```json
{
  "actual_closing_balance": 1500000,
  "note": "Ca buổi sáng bình thường"
}
```
Server: tính `closing_balance` từ số dư hệ thống. Nếu `actual_closing_balance` lệch, tạo reconciliation tự động. Gửi notification cho owner.

#### `GET /shifts/{id}/summary`
Response:
```json
{
  "shift_id": "uuid",
  "cashier": { "id": "...", "full_name": "..." },
  "vault": { "id": "...", "name": "Túi thu ngân" },
  "start_at": "2026-07-31T08:00:00Z",
  "end_at": "2026-07-31T17:00:00Z",
  "opening_balance": 500000,
  "closing_balance": 2300000,
  "total_income": 2100000,
  "total_expense": 300000,
  "transaction_count": 15,
  "reconciliation": null
}
```

### 6.13. Budget API

- `GET /budgets?workspace_id=...` – Lấy danh sách ngân sách hiện tại (lọc ngân sách có `start_date <= today <= end_date`).
- `POST /budgets` – Tạo ngân sách.
```json
{
  "workspace_id": "...",
  "category_id": "...",
  "name": "Chi phí ăn uống tháng 8",
  "amount": 5000000,
  "period": "monthly",
  "start_date": "2026-08-01",
  "end_date": "2026-08-31",
  "alert_threshold": 80
}
```
- `GET /budgets/{id}/status` – Trạng thái thực tế:
```json
{
  "budget_id": "uuid",
  "category": "...",
  "limit": 5000000,
  "spent": 3800000,
  "remaining": 1200000,
  "percent_used": 76,
  "status": "warning",
  "is_over_budget": false
}
```
- `PATCH /budgets/{id}` – Cập nhật ngân sách.
- `DELETE /budgets/{id}` – Xóa ngân sách.

### 6.14. Recurring Transactions API (Giao dịch định kỳ)

- `GET /recurring-transactions?workspace_id=...`
- `POST /recurring-transactions`
```json
{
  "workspace_id": "...",
  "template": {
    "type": "expense",
    "from_vault_id": "...",
    "to_vault_id": "...",
    "amount": 10000000,
    "category_id": "...",
    "note": "Trả tiền mặt bằng"
  },
  "frequency": "monthly",
  "next_run": "2026-08-01",
  "end_date": "2027-08-01"
}
```
- `PATCH /recurring-transactions/{id}` – Cập nhật / tạm dừng (`{ "is_active": false }`).
- `DELETE /recurring-transactions/{id}` – Xóa hoàn toàn.

### 6.15. Forecast AI API (Phase 4 – Pro)

#### `GET /forecast/cashflow?workspace_id=...&days=7`
Yêu cầu: `is_pro = true`. Dự báo dựa trên dữ liệu lịch sử 90 ngày gần nhất.
Response:
```json
{
  "predictions": [
    { "date": "2026-08-01", "predicted_balance": 12500000, "confidence": 0.85 },
    { "date": "2026-08-02", "predicted_balance": 11800000, "confidence": 0.82 }
  ],
  "warnings": [
    {
      "date": "2026-08-05",
      "vault": "Túi tiền mặt",
      "message": "Số dư dự kiến xuống dưới 1.000.000đ",
      "predicted_balance": 750000
    }
  ],
  "recurring_summary": [
    { "date": "2026-08-01", "description": "Tiền mặt bằng", "amount": -10000000 }
  ]
}
```

---

## 7. Xác thực và phân quyền

- JWT access token (15 phút), refresh token (30 ngày).
- Phân quyền: mỗi API endpoint được bảo vệ bởi middleware kiểm tra `workspace_id` và quyền từ role của user trong workspace đó.
- Quyền granular: kiểm tra `permissions` JSONB. Ví dụ: `can('transactions:create')`.
- Giới hạn vault: Cashier chỉ được phép xem các vault được gán (lưu trong bảng `cashier_vaults` hoặc trong metadata của role).

---

## 8. Luồng nghiệp vụ chính

### 8.1. Ghi nhận giao dịch bán hàng
1. User chọn “+ Giao dịch” hoặc nhấn mic.
2. Nhập/ nói thông tin.
3. Client gửi API tạo transaction.
4. Server:
   - Validate, tạo transaction.
   - Tạo entries, cập nhật vault balances.
   - Nếu là ca làm việc, ghi nhận vào shift.
   - Gửi event WebSocket vault_updated.
   - Kiểm tra quest, tăng XP.
   - Gửi notification nếu cần (vd: số dư thấp).
5. Client cập nhật UI.

### 8.2. Kiểm kê
1. Vào vault detail, nhấn “Kiểm kê”.
2. Nhập số tiền thực.
3. Server:
   - Lưu reconciliation.
   - Nếu lệch, tạo transaction chuyển chênh lệch vào `vault_discrepancy`.
   - Gửi notification cho owner.
4. Hiển thị kết quả.

### 8.3. Quản lý công nợ
- **Bán thiếu**: Chọn khách, nhập số tiền -> server tạo transaction debt_increase, tăng nợ vault của khách.
- **Trả nợ**: Chọn khách, nhập số tiền, chọn túi nhận -> server tạo transaction debt_decrease, giảm nợ, tăng tiền vào túi tương ứng.

### 8.4. Luồng quản lý ca làm việc (Shift)

**Mở ca:**
1. Owner/Manager vào Cài đặt → Ca làm việc → “+ Mở ca mới”.
2. Chọn thu ngân (Cashier), chọn túi tiền mặt cho ca.
3. Server ghi `opening_balance = vault.current_balance`, tạo shift với `status = active`.
4. Cashier được thông báo: “Bạn đã được phân công ca từ [giờ mở ca]”.

**Trong ca:**
- Cashier tạo giao dịch bình thường. Server tự động gẫn `shift_id` vào transaction nếu vault thuộc ca đang mở.
- Cashier có thể xem tóm tắt ca hiện tại: tổng thu, tổng chi, số giao dịch kể từ khi mở ca.

**Đóng ca:**
1. Cashier nhấn “Đóng ca”, nhập số tiền thực tế trong túi.
2. Server kiểm tra chênh lệch:
   - Nếu khớp (sai số < 1.000đ): đóng ca ngay.
   - Nếu lệch: tạo reconciliation tự động, ghi chênh lệch vào `vault_discrepancy`.
3. Gửi notification cho owner: “Ca của NV A đã đóng. Thu: 2.100.000đ | Chi: 300.000đ | Chênh lệch: -20.000đ”.
4. Owner có thể xem báo cáo ca chi tiết qua `GET /shifts/{id}/summary`.

### 8.5. Luồng mời thành viên qua Deep Link

1. Owner vào Cài đặt → Quản lý thành viên → “Mời thành viên”.
2. Chọn phương thức:
   - **Qua email**: Nhập email, chọn vai trò, gửi. Server tạo invite link dạng `moneyflow://invite/{workspace_id}/{invite_token}` (hết hạn sau 7 ngày), gửi email.
   - **Qua mã mời**: Chia sẻ `invite_code` từ bảng `workspaces`. Bất kỳ ai có mã có thể tham gia với vai trò mặc định (Member).
3. Người nhận click link → app mở màn hình Accept Invitation:
   - Hiển thị thông tin workspace (tên, loại, số thành viên), tên người mời, vai trò được giao.
   - Nút “Tham gia” → gọi `POST /invitations/{token}/accept`.
4. Server thêm vào `workspace_members`, gửi notification cho owner.

API bổ sung:
- `GET /invitations/{token}` – Kiểm tra token còn hiệu lực, trả về thông tin workspace.
- `POST /invitations/{token}/accept` – Xác nhận tham gia.
- `DELETE /workspaces/{id}/members/{user_id}` – Xóa thành viên.

### 8.6. Tự động nhắc nợ (Cron Job)

1. Cron job chạy hàng ngày lúc **08:00 giờ theo múi giờ workspace** (lưu `timezone` trong `workspaces`).
2. Truy vấn khách hàng có `debt_vault.current_balance > 0` và:
   - `due_date = today` (nhắc ngày đến hạn).
   - `due_date < today` (cảnh báo quá hạn, nhắc mỗi 3 ngày).
3. Gửi push notification cho owner:
   - “Hôm nay có {N} khách đến hạn trả nợ. Tổng: {amount}”.
   - Nếu đã quá hạn: “⚠️ {customer} nợ {amount} quá hạn {N} ngày”.
4. (Tùy chọn Pro) Gửi SMS/Zalo cho khách theo mẫu:
   > “Chào {tên khách}, {tên shop} nhắc bạn có khoản nợ {amount}. Xin vui lòng thanh toán. Cảm ơn!”
   Chuẩn consent: chỉ gửi nếu khách đã xác nhận số điện thoại.

---

## 9. Hệ thống Gamification (Game Leon)

- **XP actions**:
  - Tạo giao dịch: +5 XP (max 50/ngày)
  - Kiểm kê khớp: +30 XP
  - Thu hồi nợ: +20 XP
  - Mời thành viên: +50 XP
  - Sử dụng voice: +5 XP (max 25/ngày)
- **Level**: XP cần = 100 * level^2.
- **Quests**: Ví dụ “Thợ săn giao dịch” – tạo 20 giao dịch trong tuần, thưởng 100 XP.
- **Achievements & Outfits**: Mỗi achievement gắn với outfit. Khi mở khóa, user có thể mặc cho Leon.
- **Theme Leon**: Giao diện thay đổi với asset 2D, animation Lottie.

---

## 10. Tính năng AI – Nhập liệu bằng giọng nói

### 10.1. Nguyên lý
- Chạy on-device STT (whisper.cpp) để chuyển giọng nói thành text.
- NLU engine (TensorFlow Lite) phân tích intent và entities. Nếu độ tin cậy thấp, gửi lên cloud (GPT-4o mini).
- Context resolver bổ sung vault mặc định, khách hàng gần đây.
- Nếu thiếu thông tin, hỏi lại bằng text-to-speech.

**Voice input Cơ bản (Free) vs Nâng cao (Pro)** – làm rõ cho bảng so sánh gói ở Mục 17.1:
- **Cơ bản (Free):** Chỉ dùng pipeline on-device (whisper.cpp + TensorFlow Lite). Nhận diện tốt các câu lệnh đơn giản, một giao dịch/lần nói. Không gọi cloud AI.
- **Nâng cao (Pro):** Khi độ tin cậy on-device thấp hoặc câu lệnh phức tạp (nhiều giao dịch, số tiền dạng "rưỡi", từ địa phương), hệ thống tự động fallback sang Cloud NLU (GPT-4o mini) để tăng độ chính xác (xem Mục 10.4, 10.6). Free vẫn có fallback cloud nhưng giới hạn số lần gọi/ngày thấp hơn nhiều so với Pro (xem 10.7).

### 10.2. Ví dụ xử lý
Câu: “thu 300k bán tai nghe”
- STT → “thu 300k bán tai nghe”
- NLU → intent: create_income, amount: 300000, item: “tai nghe”, category: “bán hàng” (suy luận từ item)
- Context: current_shift_vault_id = cash_vault_id → gán to_vault.
- Tạo transaction.

### 10.3. Luồng tương tác
1. Nhấn mic.
2. Nói.
3. Hiển thị card xác nhận với các trường đã điền. Nếu đúng, tự động lưu sau 3 giây; nếu sai, sửa rồi lưu.
4. Nếu thiếu vault, app hỏi “Bạn muốn tiền vào đâu?”, người dùng nói “tiền mặt” hoặc chọn từ list.

### 10.4. Xử lý câu lệnh phức tạp

Hệ thống hỗ trợ một lần nói tạo nhiều giao dịch:

| Câu lệnh | Kết quả |
|---|---|
| “hôm qua thu 500k tiền mặt bán áo, chi 200k tiền điện” | Tạo 2 transaction, `created_at = yesterday` |
| “Khách A trả 300k, khách B trả 500k đều tiền mặt” | Tạo 2 debt_decrease, cần confirm tên khách |
| “Chuyển hết tiền từ Momo về ACB” | Resolver lấy `current_balance` của Momo, tạo transfer |
| “thu 1 triệu rưỡi” | amount = 1.500.000đ (xử lý “rưỡi” = 500.000) |
| “bán thiếu anh Tùng 2 cửc gà” | debt_increase, cần confirm “2 cửc” = bao nhiêu tiền |

Nếu NLU phân tích được nhiều intent, server trả về danh sách transactions cần confirm (không tự tạo).  
Nếu độ tin cậy < 0.7 bất kỳ field nào → yêu cầu xác nhận.

### 10.5. Học thói quen người dùng (Personalization)

Server lưu `user_preferences` (JSONB trong bảng `users` hoặc bảng riêng):
```json
{
  "default_income_vault": "cash_vault_id",
  "default_expense_vault": "cash_vault_id",
  "recent_categories": ["cat_ban_hang", "cat_nhap_hang"],
  "recent_customers": ["cust_a", "cust_b"]
}
```
Context resolver ưu tiên: vault đang mở ca > default vault của user > vault loại `cash` đầu tiên.

### 10.6. Xử lý tiếng ồn và giọng địa phương

- On-device STT (whisper.cpp small model) xử lý tốt giọng Nam/Bắc. Fine-tune model nếu cần cho giọng Miền Trung.
- Cloud NLU (GPT-4o mini) hiểu từ địa phương: “chén” = “bát”, “cắc” = “100k”, “óc” = 1.000đ.
- Danh sách mapping tốc ký số: `k/K = 1.000`, `tr/trieu = 1.000.000`, `cắc/cây = 100.000`.
- Nếu STT trả về text không rõ (confidence < 0.5): hiển thị thông báo “Không hiểu rõ. Vui lòng nói lại” kèm text đã nhận dạng.

### 10.7. Tối ưu chi phí AI (token & tần suất gọi cloud)

- **Cache intent theo user**: Với cùng một câu lệnh và cùng context, tái sử dụng kết quả NLU đã lưu trong Redis (key: hash của `transcript + workspace_id`), TTL 1 giờ.
- **Prompt ngắn gọn**: Chỉ gửi lên cloud phần text cần phân tích, không kèm lịch sử hội thoại dài; dùng few-shot example rút gọn trong system prompt.
- **On-device ưu tiên**: Mặc định luôn chạy NLU on-device (TensorFlow Lite) trước. Chỉ fallback lên Cloud NLU (GPT-4o mini) khi confidence on-device < 0.7.
- **Giới hạn gọi cloud theo gói**: Free tối đa **20 lần/ngày**, Pro tối đa **200 lần/ngày**. Khi vượt hạn mức, hệ thống báo "Đã hết lượt AI hôm nay, thử lại vào ngày mai hoặc nâng cấp Pro" và tiếp tục xử lý bằng on-device NLU (độ chính xác thấp hơn).
- Bộ đếm lượt gọi lưu trong Redis theo `user_id` + ngày hiện tại (reset lúc 00:00 theo timezone workspace).

---

## 11. Hệ thống thông báo

### 11.1. Kênh
- Push notification (FCM/APNs)
- In-app (trung tâm thông báo, badge)

### 11.2. Loại thông báo (tái hiện từ mục trước)
- **Giao dịch:** “Thu 300k – Bán tai nghe (NV A)”
- **Số dư thấp:** “Túi Thu ngân còn 850k”
- **Công nợ:** “Khách Bích sắp đến hạn trả 2tr”
- **Kiểm kê:** “Kiểm kê túi ca sáng: thiếu 50k”
- **Gamification:** “Leon lên cấp 5!”
- **Hệ thống:** “Bạn được mời vào Shop ABC”

### 11.3. Cấu trúc bảng `notifications` đã mô tả ở trên.

### 11.4. Mẫu thông báo chi tiết

| Tình huống | Tiêu đề | Nội dung | Dữ liệu đính kèm |
|---|---|---|---|
| Túi tiền mặt xuống thấp | ⚠️ Cảnh báo số dư thấp | Túi Thu ngân còn 500.000đ (dưới mức an toàn 1.000.000đ) | `{ vault_id, current_balance, threshold }` |
| Kiểm kê lệch âm | 🔍 Phát hiện thiếu tiền | Kiểm kê Túi Ca sáng: thiếu 200.000đ so với sổ sách. Người kiểm kê: NV Lan | `{ reconciliation_id, difference, vault_id }` |
| Khách nợ đến hạn | 📅 Nhắc nợ hôm nay | {Tên khách} nợ {amount} đến hạn hôm nay | `{ customer_id, debt_amount, due_date }` |
| Khách quá hạn 7 ngày | 🚨 Nợ xấu cần xử lý | {Tên khách} nợ {amount} quá hạn 7 ngày | `{ customer_id, debt_amount, overdue_days }` |
| Hoàn thành nhiệm vụ tuần | 🏆 Chúc mừng! | Bạn đã hoàn thành “Thợ săn giao dịch”. Nhận 200 XP! | `{ quest_id, xp_reward, new_total_xp }` |
| Ngân sách vượt | 📊 Vượt ngân sách | Danh mục “Ăn uống” đã chi 6.000.000đ / hạn mức 5.000.000đ | `{ budget_id, spent, limit, category }` |
| Ca đã đóng | 🔒 Báo cáo ca | Ca {Tên NV} đóng lúc {giờ}. Thu: {in} | Chi: {out} | Chênh lệch: {diff} | `{ shift_id }` |
| Giao dịch lớn | 💸 Giao dịch lớn | Chủ shop vừa rút 10.000.000đ từ TK ACB vào Ví cá nhân | `{ transaction_id, amount, from_vault, to_vault }` |
| Được mời | 🏠 Lời mời | {Tên người mời} mời bạn tham gia “{Tên workspace}” với vai trò {role} | `{ invite_token, workspace_id }` |

## 12. Thiết kế giao diện người dùng chi tiết

Phần này mô tả từng màn hình với các thành phần UI, hành động, điều hướng.

### 12.0. Hướng dẫn lần đầu cho người dùng (Onboarding Flow)

#### 12.0.1. Tổng quan
Sau khi người dùng đăng ký/đăng nhập thành công và chưa có workspace nào (hoặc mới tạo workspace đầu tiên), ứng dụng sẽ hiển thị luồng hướng dẫn tương tác từng bước. Mục tiêu:

- Giúp người dùng hiểu các khái niệm cốt lõi (Túi tiền, Giao dịch, Công nợ).
- Hướng dẫn tạo túi tiền đầu tiên và thực hiện giao dịch mẫu.
- Có thể bỏ qua bất kỳ lúc nào.
- Chỉ hiển thị một lần cho mỗi workspace (có thể bật lại trong Cài đặt nếu muốn).

#### 12.0.2. Các bước hướng dẫn
Quy trình gồm 5 bước ngắn gọn, hiển thị dưới dạng overlay (popup) trên giao diện chính, kèm theo mũi tên chỉ dẫn.

**Bước 1: Chào mừng & Giới thiệu Leon (nếu bật gamification)**
- **Màn hình hiện tại:** Dashboard trống (chưa có dữ liệu).
- **Overlay:**
  - Hình ảnh Leon vui vẻ (hoặc logo app).
  - Dòng chữ: *“Chào mừng đến với Sổ Thu Chi! Mình là Leon, trợ lý tài chính của bạn.”*
  - Text phụ: *“Chúng ta sẽ cùng nhau thiết lập để bạn quản lý tiền dễ dàng hơn nhé.”*
- **Nút:** `[Bắt đầu]` / `[Bỏ qua hướng dẫn]`.

**Bước 2: Khái niệm Túi tiền (Vault)**
- **Overlay chỉ vào khu vực sẽ hiển thị Carousel Túi tiền (hiện chưa có).**
  - Dòng chính: *“Đây là Túi tiền – nơi chứa tiền thật của bạn.”*
  - Mô tả: *“Bạn có thể tạo túi cho tiền mặt, tài khoản ngân hàng, ví Momo, hoặc cả công nợ của khách hàng.”*
  - Minh họa nhỏ: 3 icon túi (cash, bank, ewallet).
- **Hành động:** Overlay biến mất, hiển thị hộp thoại nhỏ “Hãy thêm túi tiền mặt của bạn” và tự động mở modal tạo túi (nút “+ Thêm túi” trên Dashboard).

**Bước 3: Tạo túi đầu tiên (Thực hành)**
- **Màn hình:** Modal tạo túi tiền (như thiết kế ở Mục 12.5 nhưng đơn giản hóa).
  - Tên túi: tự động điền “Ví tiền mặt” (có thể sửa).
  - Loại túi: tự động chọn “Tiền mặt”.
  - Số dư ban đầu: để trống hoặc người dùng nhập.
- **Overlay nhỏ:** *“Đây là túi tiền mặt. Hãy nhập số tiền hiện có trong ví của bạn (nếu có), rồi nhấn Lưu.”*
- Sau khi lưu, túi xuất hiện trên Dashboard. Overlay tiếp tục.

**Bước 4: Thực hiện giao dịch đầu tiên**
- **Overlay chỉ vào nút `[+ Giao dịch]` hoặc FAB.**
  - Dòng chính: *“Tuyệt! Giờ hãy ghi nhận một khoản thu hoặc chi nhé.”*
  - Mô tả: *“Mỗi khi có tiền vào hay ra, bạn tạo một giao dịch. Ứng dụng sẽ tự động cập nhật số dư các túi liên quan.”*
- **Hành động:** Overlay biến mất, tự động mở modal tạo giao dịch ở tab “Thu”.
  - Túi nhận tiền: chọn túi vừa tạo.
  - Số tiền: gợi ý nhập `50.000` (có placeholder mờ).
  - Ghi chú: *“Tiền mừng khai trương”*.
- **Overlay nhỏ:** *“Hãy thử nhập số tiền và nhấn Lưu. Bạn có thể dùng giọng nói bằng cách nhấn nút Mic.”*
- Sau khi lưu, Dashboard cập nhật số dư. Overlay cuối cùng xuất hiện.

**Bước 5: Hoàn tất & Khám phá thêm**
- **Overlay:**
  - Dòng chính: *“Bạn đã sẵn sàng! 🎉”*
  - Mô tả: *“Bạn có thể mời thành viên gia đình/nhân viên, xem báo cáo, hoặc để Leon giúp bạn theo dõi thói quen tài chính.”*
  - Các nút nhỏ: `[Mời thành viên]` (điều hướng đến Cài đặt), `[Xem báo cáo]` (đến tab Báo cáo), `[Để Leon giúp]` (bật gamification nếu chưa bật).
- **Nút chính:** `[Bắt đầu sử dụng]` – tắt overlay, quay về Dashboard bình thường.

#### 12.0.3. Xử lý bỏ qua & lưu trạng thái
- Mỗi bước đều có nút “Bỏ qua” hoặc “Để sau”.
- Trạng thái hoàn thành onboarding được lưu vào `workspaces` (cột `onboarding_completed BOOLEAN DEFAULT FALSE`) hoặc local storage (SharedPreferences) cho workspace hiện tại.
- Nếu người dùng bỏ qua giữa chừng, lần sau mở app vẫn hiển thị tiếp từ bước đã dừng (nếu chưa hoàn thành). Có thể tắt hẳn bằng cách chọn “Không hiển thị lại”.
- Trong Cài đặt, có mục “Xem lại hướng dẫn” để chạy lại onboarding.

#### 12.0.4. Yếu tố UI/UX
- Overlay sử dụng nền tối mờ (70% opacity) xung quanh vùng được chỉ dẫn, vùng chỉ dẫn sáng rõ, có mũi tên.
- Animation nhẹ (fade in, slide).
- Văn bản ngắn gọn, thân thiện, dùng ngôn ngữ giống trò chuyện.
- Có thể tích hợp giọng nói của Leon (nếu bật Game theme) đọc to hướng dẫn.

#### 12.0.5. Dữ liệu mẫu cho hướng dẫn
- Không tạo dữ liệu ảo trong database thật. Chỉ dùng giao diện và lưu thật khi người dùng thao tác theo hướng dẫn.

### 12.1. Màn hình Splash & Auth
**Splash:**
- Logo Sổ Thu Chi (hình đồng xu cách điệu), tên app.
- Progress indicator.
- Tự chuyển đến Login nếu chưa có token, hoặc Workspace Picker.

**Login:**
- Logo nhỏ phía trên.
- Text field Email (có icon mail).
- Text field Password (icon lock, toggle visibility).
- Button “Đăng nhập” (full width, primary).
- “Quên mật khẩu?” -> Forgot Password.
- “Chưa có tài khoản? Đăng ký” -> Register.
- Hoặc đăng nhập với Google (icon Google).

**Register:**
- Các trường: Họ tên, Email, Password, Confirm Password.
- Nút “Đăng ký” -> gửi OTP (nếu bật verify).
- Màn hình OTP: 6 ô nhập số, nút “Gửi lại mã” (countdown 60s).
- Sau khi verify, chuyển sang Onboarding.

**Onboarding:**
- Chọn “Shop” hoặc “Gia đình” (2 card minh họa).
- Nhập tên workspace.
- (Tùy chọn) Thêm túi tiền đầu tiên: nhập số dư các tài khoản.
- Nút “Bắt đầu”.

### 12.2. Workspace Picker (nếu có nhiều workspace)
- AppBar: “Không gian làm việc”.
- Grid/List các card workspace: avatar, tên, loại, số thành viên.
- Nhấn vào card để vào Dashboard workspace đó.
- FAB “+ Tạo mới” (mở modal tạo workspace).

### 12.3. Dashboard (Tab Tổng quan) – Theme Classic
- **AppBar:** Tên workspace, bên phải icon thông báo (badge số), icon cài đặt (gear).
- **Phần Tài sản:** Card nền gradient xanh:
  - “Tổng tài sản” + số tiền lớn.
  - Biểu đồ tròn nhỏ: % tiền mặt, bank, ví, công nợ.
- **Dòng tiền hôm nay:** Row 3 cột: Thu (xanh), Chi (đỏ), Thuần (có thể đỏ/xanh).
- **Carousel Túi tiền:** cuộn ngang, mỗi item là card nhỏ hiển thị tên túi, số dư, icon tương ứng. Nhấn vào -> Vault Detail.
- **Khu vực AI/Game (nếu bật):** Leon đứng cạnh, bong bóng lời khuyên.
- **Quick actions:** Row icon: `[+ Giao dịch]` (FAB thay thế?), `[Kiểm kê]`, `[Mic]`.
- **Danh sách giao dịch gần đây:** 5 items, cuối cùng là “Xem tất cả” -> Tab Transactions.

**Trong theme Game Leon:** Dashboard sẽ khác biệt:
- Leon hoạt hình lớn ở trên cùng, bên cạnh tổng tài sản.
- Thanh XP và level ngay dưới tên shop.
- Các túi tiền biến thành “rương kho báu” với animation.
- Nút hành động nhanh như phím game console: A (xanh) Giao dịch, B (đỏ) Kiểm kê, X (vàng) Voice, Y (xanh lá) Khác.
- Hiển thị Quest panel nhỏ: “Hôm nay: 3/5 giao dịch”.

### 12.4. Tab Giao dịch (Transactions)
- AppBar: “Giao dịch”.
- Filter bar ngang: button “Hôm nay”, “Tuần”, “Tháng”, “Tùy chỉnh”; dropdown loại; dropdown vault.
- ListView dạng timeline:
  - Mỗi item: icon tròn màu (xanh lá thu, đỏ chi, vàng chuyển), dòng mô tả, dòng phụ (từ vault A → vault B), số tiền bên phải (màu tương ứng), thời gian.
  - Nhấn vào -> Transaction Detail.
- FAB “+” (góc dưới phải) mở modal tạo giao dịch.
- **Phân trang:** danh sách dùng infinite scroll, gọi `GET /transactions?...&page=1&limit=20` (mặc định `limit = 20`). Khi `ScrollController` phát hiện gần cuối danh sách, tự động gọi trang tiếp theo bằng `ListView.builder`; dừng khi `page >= pagination.total_pages` (theo cấu trúc response ở Mục 6.4). Quy tắc phân trang này áp dụng thống nhất cho mọi danh sách dài trong app: giao dịch, khách hàng (12.10), túi tiền (12.7), thông báo, lịch sử ca làm việc (12.16).

### 12.5. Modal tạo giao dịch (Bottom Sheet)
- Tab bar nhỏ: “Thu”, “Chi”, “Chuyển tiền”. (Có thể thêm tab “Công nợ” nếu muốn).
- **Tab Thu:**
  - Dropdown “Tiền vào túi” (mặc định cash đang mở).
  - “Nguồn tiền”: radio “Bán hàng”, “Thu nợ” (hiện list khách), “Khác”.
  - TextField “Số tiền” (numeric keyboard).
  - TextField “Ghi chú”.
  - Nút mic để nhập giọng nói.
- **Tab Chi:** Túi chi, danh mục (có search), số tiền, ghi chú.
- **Tab Chuyển tiền:** Túi nguồn, túi đích, số tiền, lý do.
- Nút “Lưu” (primary). Sau khi lưu, đóng modal, refresh list.

### 12.5.1. Tab “Công nợ” trong Modal tạo giao dịch

- **Tab Bán thiếu:**
  - Dropdown chọn khách hàng (có search). Dưới tên khách hiển thị số nợ hiện tại.
  - TextField số tiền.
  - TextField ghi chú mặt hàng (ví dụ: “2 cửc gà”).
  - DatePicker ngày hẹn trả (tùy chọn).
  - Nút “Lưu” → tạo `debt_increase` transaction.
- **Tab Trả nợ:**
  - Dropdown chọn khách (hiển thị số nợ còn lại lớn, màu đỏ).
  - TextField số tiền (có nút “Trả hết” điền tự động toàn bộ số nợ).
  - Dropdown túi nhận tiền (mặc định tiền mặt).
  - Nút “Lưu” → tạo `debt_decrease` transaction.
- AppBar: “Chi tiết giao dịch”.
- Card thông tin: loại, trạng thái, ngày, người tạo.
- Hiển thị 2 túi: Từ → Đến với số tiền.
- Ghi chú, ảnh hóa đơn (nếu có).
- Nút “Hủy giao dịch” (nếu có quyền).

### 12.7. Tab Túi tiền (Vaults)
- AppBar: “Túi tiền”.
- SectionList theo nhóm: Tiền mặt, Ngân hàng, Ví điện tử, Công nợ.
- Mỗi row: icon, tên, số dư, “Đã kiểm kê: ...” (ngày). Nhấn vào -> Vault Detail.
- Nút “+ Thêm túi”.

### 12.8. Màn hình Chi tiết túi (Vault Detail)
- AppBar: tên túi.
- Số dư hiện tại (lớn), bên dưới “Số dư thực tế (kiểm kê lần cuối): ...”.
- Biểu đồ line chart 7 ngày.
- Hàng nút: “Nạp tiền”, “Rút tiền”, “Kiểm kê” (button nổi bật).
- Danh sách giao dịch liên quan đến túi (phân trang).

### 12.9. Màn hình Kiểm kê
- Tiêu đề: “Kiểm kê [Tên túi]”.
- Số dư hệ thống hiển thị.
- TextField lớn: “Số tiền thực tế”.
- Chênh lệch tự động tính (xanh/đỏ).
- Dropdown lý do.
- Nút “Xác nhận kiểm kê”.

### 12.10. Tab Công nợ (Debt)
- AppBar: “Công nợ”.
- Search bar.
- Segmented control: “Tất cả”, “Đang nợ”, “Quá hạn”.
- List khách hàng: tên, số tiền nợ, hạn trả, màu đỏ nếu quá hạn.
- Nhấn vào -> Customer Detail.

### 12.10.1. Cảnh báo nợ quá hạn trên Dashboard

Ngày dưới Carousel Túi tiền, nếu có khách nợ quá hạn, hiển thị card cảnh báo:
- Nền đỏ nhạt, viền đỏ, icon ⚠️.
- Text: “{N} khách hàng quá hạn trả nợ. Tổng: {amount}. Xem ngay →”.
- Nhấn vào → điều hướng sang Tab Công nợ đã lọc sẵn “Quá hạn”.
- Card này chỉ hiển thị với Owner/Manager, ẩn với Cashier.
- Thông tin khách: tên, SĐT.
- Tổng nợ hiện tại.
- Nút: “Tạo đơn bán thiếu”, “Ghi nhận trả nợ”.
- Timeline lịch sử nợ: mỗi lần bán thiếu/trả nợ, số dư thay đổi.

### 12.12. Tab Báo cáo (Reports)
- Grid 2 cột: “Dòng tiền”, “Lợi nhuận”, “Tổng tài sản”, “Công nợ”.
- Nhấn vào “Dòng tiền” -> màn hình báo cáo:
  - Chọn kỳ (button cuộn ngang: Tuần, Tháng, Quý, Năm).
  - Biểu đồ cột: Thu (xanh), Chi (đỏ).
  - Bảng chi tiết các khoản mục.
- Xuất file: icon share trên AppBar.

### 12.13. Cài đặt (Settings)
- Truy cập từ Dashboard.
- **Thông tin workspace**: tên, ảnh, mã mời.
- **Quản lý thành viên**: danh sách, thêm, sửa vai trò.
- **Phân quyền**: màn hình sửa role với các toggle quyền.
- **Danh mục thu/chi**: thêm/sửa/xóa.
- **Tích hợp**: kết nối ngân hàng (Plaid/manual), ví điện tử.
- **Thông báo**: cài đặt kênh.
- **Giao diện**: chọn theme (Classic, Dark, Game Leon).
- **Voice**: cấu hình wake word, ngôn ngữ.
- **Sao lưu & Khôi phục**.
- **Đăng xuất**.

### 12.14. Màn hình Game Leon (đặc biệt)
- **Wardrobe**: grid các outfit, chọn để mặc.
- **Achievement Hall**: danh sách huy hiệu, mờ nếu chưa đạt.
- **Quest Log**: nhiệm vụ hàng ngày, tiến trình.

### 12.15. Màn hình Profile người dùng

Truy cập từ: Cài đặt → ảnh đại diện/tên người dùng.
- **AppBar:** “Thông tin cá nhân”.
- Ảnh đại diện (có thể đổi bằng cách nhấn vào): chọn từ thư viện ảnh hoặc chụp mới, upload lên MinIO.
- **Họ tên** (có thể chỉnh sửa).
- **Email** (chỉ xem, không đổi được).
- **Số điện thoại** (có thể chỉnh sửa).
- Nút “Đổi mật khẩu” → bottom sheet nhập: Mật khẩu hiện tại, Mật khẩu mới, Xác nhận mật khẩu mới.
- Nút “Cài PIN / Vân tay” → màn hình thiết lập khóa sinh trắc học.
- Nút “Lưu” (AppBar) gọi `PATCH /users/me`.

**Empty/Error state:** Khi upload ảnh thất bại → giữ ảnh cũ, hiển thị toast lỗi.

### 12.16. Màn hình Ca làm việc (Shift)

Truy cập từ: Cài đặt → Ca làm việc.
- **AppBar:** “Ca làm việc”.
- Banner ca đang mở (nếu có): tên thu ngân, giờ mở ca, túi tiền. Nút “Đóng ca” (màu đỏ).
- Nút “+ Mở ca mới” (chỉ hiện khi chưa có ca đang mở).
- Danh sách lịch sử ca (kèm tóm tắt):
  - Mỗi item: Tên thu ngân, Thời gian (mở – đóng), Tổng thu / chi / chênh lệch. Nhấn vào → Shift Detail.

**Shift Detail:**
- Thông tin ca: Thu ngân, Túi, Mở lúc, Đóng lúc.
- Các số liệu: Số dư đầu ca, Số dư cuối ca, Tổng thu, Tổng chi, Số giao dịch.
- Nếu có kiểm kê lệch: hiển thị cảnh báo vàng/đỏ kèm chi tiết.
- Danh sách giao dịch trong ca (phân trang).

**Loading state:** Skeleton screen khi lấy lịch sử ca.  
**Empty state:** “Chưa có ca nào. Nhấn nút bên trên để mở ca mới.”

### 12.17. Màn hình Ngân sách (Budget)

Truy cập từ: Cài đặt hoặc Dashboard (nếu loại workspace = `family`).
- **AppBar:** “Ngân sách”.
- Danh sách ngân sách hiện tại:
  - Mỗi item: Icon danh mục, Tên ngân sách, Thanh tiến trình (xanh < 80%, vàng 80-100%, đỏ > 100%), “{spent} / {limit}”.
  - Nhấn vào → chi tiết: liệt kê giao dịch thuộc danh mục trong kỳ.
- Nút “+ Thêm ngân sách” → bottom sheet:
  - Chọn danh mục (dropdown, chỉ danh mục chi).
  - Nhập tên (tùy chọn).
  - Nhập số tiền hạn mức.
  - Chọn kỳ hạn (Tuần / Tháng / Năm).
  - Nhập ngày bắt đầu (mặc định ngày đầu tháng hiện tại).
  - Nút “Tạo”.

**Empty state:** “Bạn chưa có ngân sách nào. Tạo ngay để kiểm soát chi tiêu!”

### 12.18. Màn hình Giao dịch định kỳ (Recurring)

Truy cập từ: Cài đặt.
- **AppBar:** “Giao dịch định kỳ”.
- Danh sách: Mô tả, Số tiền, Tần suất, Ngày chạy tiếp theo, Trạng thái (Toggle đang hoạt động/tạm dừng).
- Swipe để xóa (hiển thị nút xác nhận “Bạn có chắc muốn xóa không?”).
- Nút “+ Thêm” → form tạo giao dịch định kỳ (tương tự modal tạo giao dịch nhưng có thêm: Chọn tần suất, Ngày bắt đầu, Ngày kết thúc tùy chọn).

### 12.19. Màn hình Quản lý Danh mục

Truy cập từ: Cài đặt → Danh mục thu/chi.
- **AppBar:** “Danh mục”.
- SegmentedControl: “Thu nhập” / “Chi tiêu”.
- Danh sách theo nhóm đang chọn:
  - Mỗi item: Icon (hỗ trợ hiển thị emoji icon), Tên danh mục, Nút sửa (pencil), Nút xóa (trash, chỉ khi không có giao dịch nào liên quan).
- Nút “+ Thêm danh mục” → bottom sheet:
  - Icon picker: Grid 5 cột các emoji phổ biến (nhà, Ổ tô, Điện, Nước, Ăn uống, Sức khỏe, Hóa đơn, Giải trí, Du lịch, Khác...).
  - TextField Tên danh mục.
  - Nút “Tạo”.

**Lưu ý:** Không thể xóa danh mục nếu đã có giao dịch → hiển thị thông báo “Không thể xóa vì đã có {N} giao dịch sử dụng”.

### 12.20. Nén ảnh trước khi tải lên

Áp dụng cho mọi màn hình có upload ảnh (avatar ở Mục 12.15, hóa đơn giao dịch):
- **Avatar:** resize về 300x300, chất lượng JPEG 80%.
- **Ảnh hóa đơn:** resize max width 1200px, chất lượng JPEG 70%.
- Package Flutter: `flutter_image_compress` (nén ngay trên client trước khi gọi API upload, giảm dung lượng truyền và lưu trữ trên MinIO).
- Server có thể nén bổ sung qua worker riêng (dùng thư viện `sharp`) trước khi ghi vào MinIO/S3, phòng trường hợp client không nén được (web).

## 13. Chiến lược offline-first và đồng bộ

### 13.1. Local database (SQLite)
Mobile lưu toàn bộ dữ liệu cần thiết (vaults, transactions, customers...) vào SQLite (xem schema Drift ở Mục 5.6).

### 13.2. Hàng đợi giao dịch
Khi offline, mỗi transaction được lưu local với trạng thái `pending_sync` và đẩy vào `SyncQueueTable` (Mục 5.6). Ứng dụng dùng package `connectivity_plus` để lắng nghe sự kiện thay đổi kết nối mạng; khi có mạng trở lại, `SyncService` tự động đọc `SyncQueueTable` theo thứ tự FIFO và gửi từng yêu cầu đang chờ. Khi online, app gửi batch tối đa **50 transactions/lần** tới `POST /sync/transactions` (Mục 6.11) để giảm số lượng kết nối. Server xử lý tuần tự từng transaction; nếu một cái lỗi (vd: số dư không đủ), các transaction còn lại vẫn được xử lý và lỗi cụ thể được trả về theo `local_id` để client cập nhật lại trạng thái đúng dòng.

### 13.3. Đồng bộ dữ liệu tham chiếu
Định kỳ, client pull các thay đổi từ server (vaults, categories, members) qua API `GET /sync/updates?since=timestamp`. Sau khi fetch, dữ liệu được ghi đè vào SQLite local. Màn hình luôn ưu tiên hiển thị dữ liệu local ngay khi mở app (tránh màn hình trắng chờ mạng), sau đó âm thầm gọi `GET /sync/updates` để làm mới (mẫu stale-while-revalidate).

### 13.4. Xung đột
Sử dụng “last-write-wins” dựa trên `updated_at`. Với số dư, server luôn là nguồn đúng (source of truth).

### 13.5. Tối ưu realtime & giảm tải truy vấn
- **Subscribe có chọn lọc:** Client chỉ mở kênh WebSocket (Mục 6.10) cho vault/user đang xem, không subscribe toàn bộ workspace, để giảm số sự kiện phải xử lý.
- **Denormalization có kiểm soát:** Một số trường đọc thường xuyên như `vault_name`, `category_name` được lưu kèm (denormalize) trong bản ghi `transactions` phía SQLite local, tránh phải join khi hiển thị danh sách offline. Nguồn sự thật vẫn là các bảng quan hệ trên PostgreSQL; trường denormalize chỉ tồn tại ở local cache và được ghi đè mỗi lần `GET /sync/updates`.

---

## 14. Bảo mật và hiệu năng

- **Mã hóa**: bcrypt cho password, HTTPS, mã hóa dữ liệu nhạy cảm ở rest (nếu cần).
- **Audit log**: Bảng `audit_logs` ghi lại mọi thay đổi quan trọng (xem Mục 5.3).
- **Rate limit**: 100 request/phút cho API thường, 10 request/phút cho auth.
- **Cache**: Redis cache vault balances, báo cáo tổng hợp.
- **Indexing**: Đảm bảo các truy vấn thường xuyên có index.
- **Phân trang**: Tất cả danh sách có phân trang để tránh tải lớn.
- **PIN / Sinh trắc học (Biometric)**: App hỗ trợ khóa bằng PIN 4-6 số hoặc vân tay/Face ID. Khi app vào nền và mở lại sau 5 phút, yêu cầu xác thực. Implement bằng `local_auth` package. Mã PIN được lưu bằng `flutter_secure_storage` (iOS Keychain / Android Keystore), không lưu dạng plain text.
- **Certificate Pinning**: Áp dụng SSL pinning trên mobile (package `dio_certificate_pinning`) để chống tấn công MITM.
- **Input sanitization**: Toàn bộ text input được trim và validate phía server trước khi lưu. Dùng parameterized query (TypeORM/Prisma) để chống SQL injection.

---

## 15. Kế hoạch phát triển và triển khai

### 15.1. Lộ trình (Roadmap)
- **Sprint 1-4 (MVP)**: Auth, workspace, vault, transaction cơ bản, debt cơ bản, dashboard classic, mobile.
- **Sprint 5-6**: Offline mode, báo cáo, notification.
- **Sprint 7-8**: Voice input cơ bản (on-device), gamification (XP, level, theme Leon).
- **Sprint 9-10**: Voice nâng cao (cloud NLU), achievements, OCR.
- **Sprint 11+**: Web app, tích hợp ngân hàng, AI dự báo.

### 15.2. Môi trường
- Development: local Docker Compose.
- Staging: Kubernetes cluster nhỏ.
- Production: Kubernetes (AWS EKS/GCP GKE) với auto-scaling.

### 15.3. CI/CD
- GitHub Actions: build, test, deploy lên staging.
- Sau khi approve, deploy production.

---

## 16. Phụ lục

### 16.1. Các lệnh thoại mẫu
- "thu 500k tiền mặt"
- "chi 200k tiền chợ từ ví momo"
- "chị Hằng trả 1 triệu chuyển khoản"
- "bán thiếu cho anh Tùng 2 triệu tiền gà"
- "chuyển 5 triệu từ ACB sang Momo"

### 16.2. Theme màu Game Leon
- Primary: Xanh lá cây rừng #4CAF50
- Secondary: Vàng đồng #FFC107
- Background: Màu giấy cổ #F5E6CC
- Text: Nâu #3E2723
- Button: viền đen, bóng đổ, chữ to.

### 16.3. Các biểu tượng và asset
Sử dụng bộ icon game 2D miễn phí hoặc thiết kế riêng.

### 16.4. Các biểu đồ trong báo cáo

- **Dòng tiền:** Biểu đồ cột kép (thu nhập và chi phí) theo ngày/tuần/tháng. Có đường trung bình động 7 ngày. Package: `fl_chart`.
- **Lợi nhuận:** Biểu đồ thác nước (waterfall) thể hiện: Doanh thu → Giá vốn → Chi phí → Lợi nhuận ròng.
- **Tổng tài sản:** Biểu đồ tròn (pie chart) tỉ lệ các túi. Có thể chuyển sang dạng bảng chi tiết.
- **Công nợ:** Bar chart hiển thị top 10 khách nợ nhiều nhất.
- **Xuất file (Pro):** PDF dùng package `pdf`, Excel dùng `excel`. Tên file: `moneyflow_{workspace}_{period}_{timestamp}.pdf`.

### 16.5. Quy ước đặt tên trong code

- **Backend (NestJS):** `camelCase` biến, `PascalCase` class/interface/DTO. Pattern: `Controller → Service → Repository`.
- **Mobile (Flutter):** `snake_case` tên file, `PascalCase` class/Widget, `camelCase` method/biến. Feature-first folder structure.
- **Database:** `snake_case` tên bảng và cột.
- **API:** `snake_case` cho JSON field, `kebab-case` cho URL path.
- **Branch git:** `feat/`, `fix/`, `chore/`, `refactor/` prefix.

### 16.6. Xử lý múi giờ và định dạng tiền tệ

**Múi giờ:**
- Tất cả thời gian lưu dưới dạng UTC (`TIMESTAMPTZ`).
- Client hiển thị theo múi giờ thiết bị: `DateTime.now().toLocal()`.
- Trong bảng `workspaces`, thêm cột `timezone VARCHAR(50) DEFAULT 'Asia/Ho_Chi_Minh'` để cron job nhắc nợ chạy đúng giờ.

**Định dạng tiền tệ – hiển thị đầy đủ (báo cáo, chi tiết giao dịch):**
- Hiển thị: `1.500.000đ` (dấu chấm phân cách hàng nghìn, ký hiệu đ sau).
```dart
String formatVND(num amount) {
  final formatter = NumberFormat('#,###', 'vi_VN');
  return '${formatter.format(amount)}đ';
}
// Ví dụ: formatVND(1500000) → '1.500.000đ'
```
- Package: `intl: ^0.19.x`. Locale mặc định lấy theo ngôn ngữ ứng dụng (xem Mục 21).

**Định dạng tiền tệ – hiển thị rút gọn theo ngôn ngữ (Dashboard, danh sách, thẻ tóm tắt):**

| Mức giá trị | Tiếng Việt | Tiếng Anh |
|---|---|---|
| Dưới 1.000 | `500đ` | `₫500` |
| 1.000 – 999.999 | `150k` | `150k` |
| 1.000.000 – 999.999.999 | `1,5tr` | `1.5M` |
| Từ 1 tỷ trở lên | `1,5 tỷ` | `1.5B` |

- Định dạng hiển thị được chọn theo ngôn ngữ ứng dụng hiện tại (`vi` hoặc `en`, xem Mục 21). Nếu người dùng chọn tiếng Anh, giao diện hiển thị `1.5M` thay vì `1,5tr`.
- Ký hiệu tiền tệ luôn là `đ`/`₫` (cuối chuỗi cho tiếng Việt, đầu chuỗi cho tiếng Anh) để tránh nhầm với USD. MVP không hỗ trợ ngoại tệ khác.
- Dùng dạng rút gọn ở nơi cần tiết kiệm không gian (thẻ Dashboard, danh sách giao dịch); dùng `formatVND`/dạng đầy đủ ở nơi cần chính xác tuyệt đối (chi tiết giao dịch, báo cáo, hóa đơn).

```dart
String formatCurrency(num amount, {String locale = 'vi'}) {
  if (locale == 'en') {
    if (amount >= 1000000000) return '${(amount / 1000000000).toStringAsFixed(1)}B ₫';
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}M ₫';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k ₫';
    return '₫${amount.toInt()}';
  } else {
    if (amount >= 1000000000) return '${(amount / 1000000000).toStringAsFixed(1)} tỷ';
    if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}tr';
    if (amount >= 1000) return '${(amount / 1000).toStringAsFixed(1)}k';
    return '${amount.toInt()}đ';
  }
}
```

**Nhập liệu tốc ký:** Người dùng có thể nhập theo bất kỳ dạng nào ở trên, không phân biệt ngôn ngữ đang dùng — ví dụ `150k`, `1.5tr`, `1.5M`, `1,5 tỷ`, `1.5B` đều được chấp nhận và quy đổi về số nguyên (đơn vị đồng) trước khi lưu: `1.5k → 1500`, `1,5tr`/`1.5M → 1500000`, `1,5 tỷ`/`1.5B → 1500000000`. Trường nhập liệu tự động format lại khi rời khỏi field (theo ngôn ngữ hiện tại).

```dart
int parseCurrencyInput(String input) {
  input = input.trim().toLowerCase().replaceAll(',', '.');
  input = input.replaceAll(RegExp(r'[₫đ\s]'), ''); // bỏ ký hiệu tiền tệ và khoảng trắng

  double multiplier = 1;
  if (input.endsWith('k')) {
    multiplier = 1000;
    input = input.replaceAll('k', '');
  } else if (input.endsWith('tr') || input.endsWith('m')) {
    multiplier = 1000000;
    input = input.replaceAll(RegExp(r'(tr|m)'), '');
  } else if (input.contains('tỷ') || input.contains('ty') || input.endsWith('b')) {
    multiplier = 1000000000;
    input = input.replaceAll(RegExp(r'(tỷ|ty|b)'), '');
  }

  final value = double.tryParse(input) ?? 0;
  return (value * multiplier).round();
}
```

**Lưu ý:** API và database luôn lưu số tiền dưới dạng số nguyên (đồng), theo quy định ở Mục 19.3. Mọi định dạng rút gọn/tốc ký chỉ áp dụng ở lớp giao diện (presentation layer), không ảnh hưởng đến dữ liệu lưu trữ hay truyền qua API.

---

## 17. Mô hình kinh doanh: Freemium & Quảng cáo

### 17.1. Tổng quan

- **Bản Free:** Miễn phí trọn đời, giới hạn một số tính năng nâng cao và hiển thị quảng cáo.
- **Gói Pro:** Trả phí theo tháng hoặc năm, loại bỏ quảng cáo, mở khóa toàn bộ tính năng nâng cao.

| Tính năng | Free | Pro |
|---|:---:|:---:|
| Giao dịch cơ bản, công nợ, báo cáo xem trực tuyến | ✅ | ✅ |
| Nhiều workspace | ✅ | ✅ |
| Gamification (XP, Level, Quest cơ bản) | ✅ | ✅ |
| Voice input cơ bản | ✅ | ✅ |
| Offline mode | ✅ | ✅ |
| Xuất báo cáo Excel/PDF | ❌ | ✅ |
| AI dự báo dòng tiền | ❌ | ✅ |
| Giao dịch định kỳ | ❌ | ✅ |
| Ngân sách | ❌ | ✅ |
| Theme Game Leon đầy đủ (tủ đồ, hiệu ứng) | ❌ | ✅ |
| Tích hợp ngân hàng tự động | ❌ | ✅ |
| Nhắc nợ qua SMS/Zalo | ❌ | ✅ |
| Không quảng cáo | ❌ | ✅ |

### 17.2. Cơ sở dữ liệu

#### 17.2.1. Bảng subscriptions
```sql
CREATE TABLE subscriptions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    plan VARCHAR(20) NOT NULL CHECK (plan IN ('monthly','yearly')),
    status VARCHAR(20) NOT NULL DEFAULT 'active'
        CHECK (status IN ('active','expired','cancelled')),
    store_receipt TEXT,
    platform VARCHAR(10) CHECK (platform IN ('ios','android','web')),
    expires_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_subscriptions_user ON subscriptions(user_id);
CREATE INDEX idx_subscriptions_active ON subscriptions(user_id)
    WHERE status = 'active';
```

#### 17.2.2. Bảng ad_impressions
```sql
CREATE TABLE ad_impressions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    ad_type VARCHAR(30) CHECK (ad_type IN ('banner','interstitial','rewarded_video','native')),
    screen VARCHAR(50),
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### 17.3. API bổ sung

#### `GET /subscription/status`
Response: `{ "is_pro": true, "plan": "yearly", "expires_at": "2027-07-31T00:00:00Z", "days_remaining": 365 }`

#### `POST /subscription/verify`
Request: `{ "receipt": "...", "platform": "google", "plan": "yearly" }`  
Server gọi API Apple/Google xác minh, tạo/cập nhật bảng `subscriptions`.

#### `DELETE /subscription`
Hủy gia hạn tự động. Subscription vẫn hiệu lực đến `expires_at`.

#### `GET /ads/config?platform=android`
Response:
```json
{
  "banner_unit_id": "ca-app-pub-xxx/yyy",
  "interstitial_unit_id": "ca-app-pub-xxx/zzz",
  "rewarded_unit_id": "ca-app-pub-xxx/www",
  "interstitial_frequency_minutes": 15
}
```

### 17.4. Luồng nghiệp vụ & Phân quyền tính năng

1. App khởi động → gọi `GET /subscription/status` và `GET /ads/config`.
2. Lưu `is_pro` vào local (SharedPreferences), hết hạn sau 1 giờ.
3. Tính năng Pro được wrap bằng widget `ProFeatureGate`:
   - `is_pro = true`: hiển thị nội dung bình thường.
   - `is_pro = false`: hiển thị card "Tính năng Pro – Nâng cấp ngay" với nút CTA.
4. Khi nâng cấp Pro: ẩn quảng cáo ngay lập tức, không cần khởi động lại app.
5. Khi hết hạn Pro: dữ liệu được giữ nguyên, chỉ khóa tính năng.

### 17.5. Tích hợp quảng cáo (Google Mobile Ads / AdMob)

1. **Banner chân trang (Adaptive Banner):** Hiển thị ở đáy các tab chính, phía trên bottom tab bar.
2. **Quảng cáo xen kẽ (Interstitial):** Sau khi tạo giao dịch thành công (tối đa 1 lần / {interstitial_frequency_minutes} phút). Không hiển thị trong luồng khẩn cấp.
3. **Video thưởng (Rewarded Video):** Nút "Xem quảng cáo để xuất file" trong màn hình báo cáo.
4. **Native Ads (Game Leon):** Hiển thị như "bảng thông báo của làng".

### 17.6. Kế hoạch phát triển

- **Sprint 3 (MVP)**: Banner quảng cáo, màn hình nâng cấp Pro (in-app purchase).
- **Sprint 5**: Interstitial sau giao dịch, video thưởng xuất báo cáo.
- **Sprint 8**: Native ads trong theme Game Leon, cấu hình từ xa.
- **Sprint 10**: Phân tích quảng cáo, A/B testing vị trí.

---

## 18. Cấu trúc dự án Flutter

### 18.1. Packages chính

```yaml
# pubspec.yaml
dependencies:
  flutter_riverpod: ^2.5.x       # State management
  go_router: ^14.x               # Navigation + deep link
  dio: ^5.x                      # HTTP client
  drift: ^2.x                    # Local SQLite ORM
  sqlite3_flutter_libs: ^0.5.x
  flutter_secure_storage: ^9.x   # Lưu PIN, token
  google_sign_in: ^6.x
  local_auth: ^2.x               # PIN / Biometric
  firebase_messaging: ^14.x      # Push notification
  flutter_local_notifications: ^17.x
  web_socket_channel: ^3.x
  fl_chart: ^0.68.x              # Biểu đồ
  google_mobile_ads: ^5.x        # AdMob
  in_app_purchase: ^3.x          # Pro subscription
  lottie: ^3.x                   # Animation Leon
  speech_to_text: ^6.x           # On-device STT
  flutter_tts: ^4.x              # Text-to-speech
  google_mlkit_text_recognition: ^0.13.x  # OCR
  image_picker: ^1.x
  cached_network_image: ^3.x
  intl: ^0.19.x                  # Định dạng VND, ngày giờ theo locale
  uuid: ^4.x
  connectivity_plus: ^6.x
  share_plus: ^9.x
  pdf: ^3.x                      # Xuất PDF (Pro)
  excel: ^4.x                    # Xuất Excel (Pro)
  flutter_localizations:         # SDK — i18n (Mục 21)
    sdk: flutter
  diacritic: ^0.1.x              # Bỏ dấu tiếng Việt khi tìm kiếm local (Mục 5.2.9, 19.1)
  flutter_image_compress: ^2.x   # Nén ảnh avatar/hóa đơn trước khi upload (Mục 12.20)

dev_dependencies:
  riverpod_generator: ^2.4.x
  build_runner: ^2.4.x
  drift_dev: ^2.x
  mockito: ^5.x
  flutter_lints: ^4.x
```

### 18.2. Cấu trúc thư mục (Feature-first)

```
lib/
├── main.dart
├── app.dart                      # MaterialApp + GoRouter setup
├── core/
│   ├── constants/
│   │   ├── api_endpoints.dart
│   │   └── app_colors.dart
│   ├── errors/
│   │   ├── exceptions.dart
│   │   └── failure.dart
│   ├── network/
│   │   ├── dio_client.dart       # Dio instance + interceptors
│   │   └── token_interceptor.dart  # Tự động refresh token
│   ├── local/
│   │   ├── database.dart         # AppDatabase (Drift)
│   │   └── tables/
│   ├── services/
│   │   ├── sync_service.dart     # Xử lý offline queue
│   │   ├── websocket_service.dart
│   │   └── notification_service.dart
│   └── utils/
│       ├── currency_formatter.dart  # formatVND()
│       └── date_utils.dart
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   ├── auth_repository.dart
│   │   │   └── auth_remote_datasource.dart
│   │   ├── domain/
│   │   │   ├── models/user.dart
│   │   │   └── auth_state.dart
│   │   └── presentation/
│   │       ├── login_screen.dart
│   │       ├── register_screen.dart
│   │       └── auth_notifier.dart  # Riverpod Notifier
│   ├── workspace/
│   ├── vault/
│   ├── transaction/
│   ├── debt/
│   ├── report/
│   ├── gamification/
│   ├── shift/
│   ├── budget/
│   └── settings/
└── shared/
    ├── widgets/
    │   ├── pro_feature_gate.dart
    │   ├── amount_text_field.dart
    │   └── empty_state_widget.dart
    └── providers/
        ├── workspace_provider.dart
        └── subscription_provider.dart
```

### 18.3. Navigation (go_router) + Deep Link

```dart
// Các route deep link quan trọng:
// moneyflow://invite/{token}     → màn hình Accept Invitation
// moneyflow://reset-password     → màn hình Reset Password
// moneyflow://notifications/{id} → mở notification cụ thể
```

Android: `AndroidManifest.xml` – intent filter cho `moneyflow://` và `https://app.moneyflow.vn`.  
iOS: `Info.plist` – URL scheme + Associated Domains (`applinks:app.moneyflow.vn`).

---

## 19. Quy tắc Validation

### 19.1. Phía Client (Flutter)

| Field | Rule | Thông báo lỗi |
|---|---|---|
| Email | RFC 5322, không bỏ trống | "Email không hợp lệ" |
| Mật khẩu (tạo) | ≥ 8 ký tự, có chữ hoa, số, ký tự đặc biệt | "Mật khẩu ít nhất 8 ký tự, bao gồm chữ hoa, số và ký hiệu" |
| Xác nhận mật khẩu | Phải khớp | "Mật khẩu không khớp" |
| Họ tên | 2-100 ký tự, không bỏ trống | "Họ tên từ 2 đến 100 ký tự" |
| Tên workspace / vault / danh mục | 1-100 ký tự | "Tên từ 1 đến 100 ký tự" |
| Số tiền giao dịch | > 0, ≤ 999.999.999.999đ, chỉ số nguyên | "Số tiền phải lớn hơn 0" |
| Số tiền ngân sách | > 0, ≤ 999.999.999.999đ | "Hạn mức không hợp lệ" |
| Ghi chú | Tối đa 500 ký tự | "Ghi chú không vượt 500 ký tự" |
| Số điện thoại | 9-11 chữ số, bắt đầu bằng 0 | "Số điện thoại không hợp lệ" |
| Ngày | Hợp lệ, không được trong tương lai quá 1 năm | "Ngày không hợp lệ" |
| PIN | 4-6 chữ số | "PIN từ 4-6 số" |
| OTP | 6 chữ số | Tự validate khi nhập đủ 6 số |

**Ô tìm kiếm (khách hàng, danh mục):** không giới hạn phải gõ có dấu — input được gửi nguyên văn lên server, server tự chuẩn hóa (bỏ dấu, lowercase) và so khớp với `search_text` (xem Mục 5.2.9).

### 19.1.1. Tự động định dạng số tiền khi nhập (Auto-format Currency Input)

Áp dụng cho **tất cả các trường nhập số tiền** trong app: modal tạo giao dịch (Thu/Chi/Chuyển tiền), bán thiếu/trả nợ, tạo ngân sách, số dư ban đầu khi tạo túi, số tiền kiểm kê, giao dịch định kỳ.

**Hành vi:**
- Người dùng luôn thấy số có dấu chấm phân cách hàng nghìn trong lúc gõ (giống máy tính bỏ túi), không phân biệt focus/unfocus. Gõ `1000000` → hiển thị `1.000.000`.
- Khi xóa ký tự cuối, dấu chấm tự tính lại theo số chữ số còn lại: `15.000.009` → xóa `9` → `1.500.000`.
- Dán (paste) một chuỗi có hoặc không có dấu chấm đều được xử lý như nhau: chỉ giữ lại chữ số, rồi format lại.
- Ký tự không phải số bị bỏ qua khi gõ, không chặn nhập và không hiện lỗi chặn form.
- MVP chỉ nhập số nguyên (đồng), không hỗ trợ thập phân.

```dart
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    if (newValue.text.isEmpty) return newValue;

    final digitsOnly = newValue.text.replaceAll(RegExp(r'[^\d]'), '');
    if (digitsOnly.isEmpty) return const TextEditingValue(text: '');

    final formatted = NumberFormat('#,###').format(int.parse(digitsOnly));
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
```

```dart
TextFormField(
  keyboardType: TextInputType.number,
  inputFormatters: [CurrencyInputFormatter()],
  decoration: InputDecoration(labelText: 'Số tiền'),
)
```

**Voice input:** Khi người dùng dùng giọng nói (Mục 10), trường số tiền được điền tự động và hiển thị đã format theo formatter trên; nếu người dùng sửa lại bằng tay, formatter vẫn áp dụng bình thường.

### 19.2. Phía Server (NestJS – class-validator)

```typescript
// create-transaction.dto.ts
export class CreateTransactionDto {
  @IsEnum(['income','expense','transfer','debt_increase','debt_decrease'])
  type: string;

  @IsUUID()
  workspace_id: string;

  @IsPositive()
  @Max(999_999_999_999)
  @IsInt()
  amount: number;           // lưu dạng integer (đồng), không có thập phân

  @IsOptional()
  @MaxLength(500)
  note?: string;

  @IsOptional()
  @IsUUID()
  category_id?: string;

  @IsOptional()
  @IsUUID()
  from_vault_id?: string;

  @IsOptional()
  @IsUUID()
  to_vault_id?: string;
}
```

### 19.3. Quy tắc bảo mật đặc biệt

- `vault_id` trong request: luôn kiểm tra thuộc `workspace_id` của user (chống IDOR).
- `customer_id`: luôn kiểm tra thuộc `workspace_id` (chống cross-tenant).
- `amount`: lưu dạng `INTEGER` (đồng) hoặc `DECIMAL(15,0)` để tránh lỗi làm tròn floating point.
- Server luôn validate lại dù client đã validate. Không tin tưởng dữ liệu từ client.

---

## 20. Chiến lược Test

### 20.1. Backend (NestJS – Jest)

- **Unit test**: Test từng Service độc lập, mock Repository.
  - `TransactionService.createIncome()`: kiểm tra double-entry đúng, vault balance cập nhật.
  - `AuthService.login()`: thông tin sai trả lỗi `INVALID_CREDENTIALS`.
- **Integration test**: Controller + Service + PostgreSQL test container.
  - Kiểm tra API endpoint đầu cuối, bao gồm validation và auth middleware.
- **Coverage mục tiêu**: ≥ 80% line coverage cho Service layer.

### 20.2. Mobile Flutter

- **Unit test**: Test Notifier/Provider với mock Repository (dùng `mockito`).
- **Widget test**: Kiểm tra từng widget hiển thị đúng format VND, form validate đúng.
- **Integration test**: `integration_test` package – luồng đăng nhập → tạo giao dịch → kiểm tra Dashboard cập nhật số dư.

### 20.3. CI Pipeline

```yaml
# .github/workflows/ci.yml
jobs:
  backend-test:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
    steps:
      - uses: actions/checkout@v4
      - run: npm ci && npm test -- --coverage

  flutter-test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: subosito/flutter-action@v2
      - run: flutter pub get && flutter test --coverage
      - run: flutter analyze
```

---

## 21. Đa ngôn ngữ (i18n)

- Ứng dụng hỗ trợ **tiếng Việt** (mặc định) và **tiếng Anh**.
- Sử dụng package `flutter_localizations` (kèm `intl`) và các file `.arb` (`app_vi.arb`, `app_en.arb`) để quản lý chuỗi văn bản; build tự sinh code qua `flutter gen-l10n`.
- Người dùng đổi ngôn ngữ trong Cài đặt (Mục 12.13). Nếu chưa từng chọn, app tự nhận diện theo ngôn ngữ thiết bị (`Platform.localeName`) và mặc định về tiếng Việt nếu không khớp `vi`/`en`.
- Toàn bộ văn bản hiển thị trong app đều có bản dịch, bao gồm cả nội dung push/in-app notification (Mục 11) — server lưu `title`/`body` theo key i18n hoặc render sẵn theo ngôn ngữ đã lưu của user (`users.locale`).
- Ngôn ngữ ứng dụng cũng quyết định định dạng tiền tệ rút gọn (Mục 16.6) và định dạng ngày/giờ (`intl` locale-aware).

---

**Tài liệu phiên bản 4.1 đã hoàn chỉnh toàn diện. Mọi lập trình viên có thể bắt đầu build app dựa trên tài liệu này mà không cần hỏi thêm.**
