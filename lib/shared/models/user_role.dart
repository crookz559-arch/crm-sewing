enum UserRole {
  director,
  headManager,
  manager,
  seamstress;

  bool get canViewPrice => this == director || this == headManager;
  bool get canViewAnalytics => this == director || this == headManager;
  bool get canSetSalary => this == director || this == headManager;
  bool get canExport => this == director || this == headManager;
  bool get canViewAllDiary => this != seamstress;
  bool get canCreateOrders => this != seamstress;
  bool get canAssign => this != seamstress;

  static UserRole fromString(String value) {
    switch (value) {
      case 'director':
        return UserRole.director;
      case 'head_manager':
        return UserRole.headManager;
      case 'manager':
        return UserRole.manager;
      case 'seamstress':
        return UserRole.seamstress;
      default:
        return UserRole.seamstress;
    }
  }

  String toJson() {
    switch (this) {
      case UserRole.director:
        return 'director';
      case UserRole.headManager:
        return 'head_manager';
      case UserRole.manager:
        return 'manager';
      case UserRole.seamstress:
        return 'seamstress';
    }
  }
}
