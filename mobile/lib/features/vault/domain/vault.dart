/// Vault (money holder) type. Virtual/debt vaults exist server-side but are
/// excluded from `GET /workspaces/:id/vaults`, so the client never needs to
/// represent them here.
enum VaultType { cash, bank, ewallet }

VaultType vaultTypeFromString(String value) {
  switch (value) {
    case 'bank':
      return VaultType.bank;
    case 'ewallet':
      return VaultType.ewallet;
    default:
      return VaultType.cash;
  }
}

String vaultTypeToString(VaultType type) {
  switch (type) {
    case VaultType.bank:
      return 'bank';
    case VaultType.ewallet:
      return 'ewallet';
    case VaultType.cash:
      return 'cash';
  }
}

String vaultTypeLabel(VaultType type) {
  switch (type) {
    case VaultType.bank:
      return 'Ngân hàng';
    case VaultType.ewallet:
      return 'Ví điện tử';
    case VaultType.cash:
      return 'Tiền mặt';
  }
}

class Vault {
  final String id;
  final String name;
  final VaultType type;
  final num currentBalance;

  const Vault({
    required this.id,
    required this.name,
    required this.type,
    required this.currentBalance,
  });

  factory Vault.fromJson(Map<String, dynamic> json) {
    return Vault(
      id: json['id'] as String,
      name: json['name'] as String,
      type: vaultTypeFromString(json['type'] as String? ?? 'cash'),
      currentBalance: (json['current_balance'] as num?) ?? 0,
    );
  }
}
