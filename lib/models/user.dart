class User {
  final int id;
  final String username;
  final String email;
  final String createdAt;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final u = json['user'];
    return User(
      id: u['id'],
      username: u['username'],
      email: u['email'],
      createdAt: u['created_at'],
    );
  }
}