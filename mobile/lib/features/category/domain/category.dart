/// Income/expense category, e.g. "Bán hàng", "Tiền chợ".
class Category {
  final String id;
  final String name;
  final String groupName;
  final String? icon;

  const Category({
    required this.id,
    required this.name,
    required this.groupName,
    this.icon,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as String,
      name: json['name'] as String,
      groupName: json['group_name'] as String? ?? '',
      icon: json['icon'] as String?,
    );
  }
}
