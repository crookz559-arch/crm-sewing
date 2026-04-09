class CourierModel {
  final String id;
  final String direction; // 'in' | 'out'
  final String? clientId;
  final String? clientName;
  final String? fromWho;
  final String? toWho;
  final String description;
  final DateTime deliveryDate;
  final String? orderId;
  final String? createdBy;
  final DateTime createdAt;

  const CourierModel({
    required this.id,
    required this.direction,
    this.clientId,
    this.clientName,
    this.fromWho,
    this.toWho,
    required this.description,
    required this.deliveryDate,
    this.orderId,
    this.createdBy,
    required this.createdAt,
  });

  factory CourierModel.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>?;
    return CourierModel(
      id: json['id'] as String,
      direction: json['direction'] as String,
      clientId: json['client_id'] as String?,
      clientName: client?['name'] as String?,
      fromWho: json['from_who'] as String?,
      toWho: json['to_who'] as String?,
      description: json['description'] as String,
      deliveryDate: DateTime.parse(json['delivery_date'] as String),
      orderId: json['order_id'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isInbound => direction == 'in';
}
