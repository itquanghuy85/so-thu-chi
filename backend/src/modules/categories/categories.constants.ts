import type { CategoryGroup } from './entities/category.entity';

/// Default categories seeded into every new workspace (Mục 12.19 groundwork
/// — the spec's emoji icon picker). `icon` is a short stable key, not an
/// emoji/asset path, so each client can render its own icon set from it.
export const DEFAULT_CATEGORIES: { name: string; groupName: CategoryGroup; icon: string }[] = [
  { name: 'Bán hàng', groupName: 'income', icon: 'sales' },
  { name: 'Lương', groupName: 'income', icon: 'salary' },
  { name: 'Quà tặng', groupName: 'income', icon: 'gift' },
  { name: 'Hoàn tiền', groupName: 'income', icon: 'refund' },
  { name: 'Đầu tư', groupName: 'income', icon: 'investment' },
  { name: 'Thu hồi nợ', groupName: 'income', icon: 'debt_collect' },
  { name: 'Thu khác', groupName: 'income', icon: 'other' },

  { name: 'Nhập hàng', groupName: 'expense', icon: 'stock' },
  { name: 'Tiền điện', groupName: 'expense', icon: 'electricity' },
  { name: 'Tiền nước', groupName: 'expense', icon: 'water' },
  { name: 'Ăn uống', groupName: 'expense', icon: 'food' },
  { name: 'Vận chuyển', groupName: 'expense', icon: 'transport' },
  { name: 'Thuê mặt bằng', groupName: 'expense', icon: 'rent' },
  { name: 'Chi khác', groupName: 'expense', icon: 'other' },
];
