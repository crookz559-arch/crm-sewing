import 'package:flutter/material.dart';

enum TaskStatus {
  pending,
  inProgress,
  done;

  String toJson() {
    switch (this) {
      case TaskStatus.pending:
        return 'pending';
      case TaskStatus.inProgress:
        return 'in_progress';
      case TaskStatus.done:
        return 'done';
    }
  }

  static TaskStatus fromString(String v) {
    switch (v) {
      case 'in_progress':
        return TaskStatus.inProgress;
      case 'done':
        return TaskStatus.done;
      default:
        return TaskStatus.pending;
    }
  }

  Color get color {
    switch (this) {
      case TaskStatus.pending:
        return const Color(0xFF9E9E9E);
      case TaskStatus.inProgress:
        return const Color(0xFF1976D2);
      case TaskStatus.done:
        return const Color(0xFF43A047);
    }
  }

  IconData get icon {
    switch (this) {
      case TaskStatus.pending:
        return Icons.radio_button_unchecked;
      case TaskStatus.inProgress:
        return Icons.pending_outlined;
      case TaskStatus.done:
        return Icons.check_circle_outline;
    }
  }
}

class TaskModel {
  final String id;
  final String title;
  final String? description;
  final String? orderId;
  final TaskStatus status;
  final DateTime? deadline;
  final String? assignedToId;
  final String? assignedToName;
  final String? createdBy;
  final DateTime createdAt;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    this.orderId,
    required this.status,
    this.deadline,
    this.assignedToId,
    this.assignedToName,
    this.createdBy,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    final assignee = json['assignee'] as Map<String, dynamic>?;
    return TaskModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      orderId: json['order_id'] as String?,
      status: TaskStatus.fromString(json['status'] as String? ?? 'pending'),
      deadline: json['deadline'] != null
          ? DateTime.tryParse(json['deadline'] as String)
          : null,
      assignedToId: json['assigned_to'] as String?,
      assignedToName: assignee?['name'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  bool get isOverdue =>
      deadline != null &&
      status != TaskStatus.done &&
      deadline!.isBefore(DateTime.now());
}
