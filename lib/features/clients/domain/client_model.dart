class ClientModel {
  final String id;
  final String name;
  final String? phone;
  final String? email;
  final String? source;
  final String? notes;
  final String? createdBy;
  final DateTime createdAt;
  final int? ordersCount;
  final double? totalRevenue;

  const ClientModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.source,
    this.notes,
    this.createdBy,
    required this.createdAt,
    this.ordersCount,
    this.totalRevenue,
  });

  factory ClientModel.fromJson(Map<String, dynamic> json) {
    return ClientModel(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      source: json['source'] as String?,
      notes: json['notes'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      ordersCount: json['orders_count'] as int?,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble(),
    );
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}
