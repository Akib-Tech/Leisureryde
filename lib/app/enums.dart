enum UserRole {
  user,
  driver,
  admin;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'driver':
        return UserRole.driver;
      case 'admin':
        return UserRole.admin;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  String toString() {
    return name; // 'user', 'driver', or 'admin'
  }
}