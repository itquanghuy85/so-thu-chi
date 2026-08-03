/// Authenticated user profile, as returned by `/auth/login`, `/auth/register`
/// (nested `user`) and `/auth/me` (flat, with extra fields).
class User {
  final String id;
  final String email;
  final String fullName;
  final String? phone;
  final String? locale;
  final String? avatarUrl;

  const User({
    required this.id,
    required this.email,
    required this.fullName,
    this.phone,
    this.locale,
    this.avatarUrl,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: (json['full_name'] ?? json['fullName'] ?? '') as String,
      phone: json['phone'] as String?,
      locale: json['locale'] as String?,
      avatarUrl: json['avatar_url'] as String?,
    );
  }
}
