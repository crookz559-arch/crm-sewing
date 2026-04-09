import '../../../shared/models/order_status.dart';

class OrderModel {
  final String id;
  final String title;
  final String? description;
  final String? clientId;
  final String? clientName;
  final String? source;
  final OrderStatus status;
  final DateTime? deadline;
  final double? price;
  final String? assignedTo;
  final String? assigneeName;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  const OrderModel({
    required this.id,
    required this.title,
    this.description,
    this.clientId,
    this.clientName,
    this.source,
    required this.status,
    this.deadline,
    this.price,
    this.assignedTo,
    this.assigneeName,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrderModel.fromJson(Map<String, dynamic> json) {
    final clientData = json['clients'] as Map<String, dynamic>?;
    final assigneeData = json['assignee'] as Map<String, dynamic>?;

    return OrderModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      clientId: json['client_id'] as String?,
      clientName: clientData?['name'] as String?,
      source: json['source'] as String?,
      status: OrderStatus.fromString(json['status'] as String? ?? 'new'),
      deadline: json['deadline'] != null
          ? DateTime.parse(json['deadline'] as String)
          : null,
      price: (json['price'] as num?)?.toDouble(),
      assignedTo: json['assigned_to'] as String?,
      assigneeName: assigneeData?['name'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  // Дни до дедлайна (отрицательное = просрочено)
  int? get daysUntilDeadline {
    if (deadline == null) return null;
    return deadline!.difference(DateTime.now()).inDays;
  }

  DeadlineState get deadlineState {
    final days = daysUntilDeadline;
    if (days == null) return DeadlineState.none;
    if (days < 0) return DeadlineState.overdue;
    if (days == 0) return DeadlineState.today;
    if (days <= 2) return DeadlineState.critical;
    if (days <= 5) return DeadlineState.warning;
    return DeadlineState.ok;
  }

  bool get isActive =>
      status != OrderStatus.closed && status != OrderStatus.rework;
}

enum DeadlineState { none, ok, warning, critical, today, overdue }
