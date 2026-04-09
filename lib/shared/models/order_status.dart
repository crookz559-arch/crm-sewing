import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

enum OrderStatus {
  newOrder,
  accepted,
  sewing,
  quality,
  ready,
  delivery,
  closed,
  rework;

  Color get color {
    switch (this) {
      case OrderStatus.newOrder:
        return AppColors.statusNew;
      case OrderStatus.accepted:
        return AppColors.statusAccepted;
      case OrderStatus.sewing:
        return AppColors.statusSewing;
      case OrderStatus.quality:
        return AppColors.statusQuality;
      case OrderStatus.ready:
        return AppColors.statusReady;
      case OrderStatus.delivery:
        return AppColors.statusDelivery;
      case OrderStatus.closed:
        return AppColors.statusClosed;
      case OrderStatus.rework:
        return AppColors.statusRework;
    }
  }

  IconData get icon {
    switch (this) {
      case OrderStatus.newOrder:
        return Icons.fiber_new_outlined;
      case OrderStatus.accepted:
        return Icons.assignment_outlined;
      case OrderStatus.sewing:
        return Icons.content_cut;
      case OrderStatus.quality:
        return Icons.search;
      case OrderStatus.ready:
        return Icons.check_circle_outline;
      case OrderStatus.delivery:
        return Icons.local_shipping_outlined;
      case OrderStatus.closed:
        return Icons.lock_outline;
      case OrderStatus.rework:
        return Icons.replay;
    }
  }

  static OrderStatus fromString(String value) {
    switch (value) {
      case 'new':
        return OrderStatus.newOrder;
      case 'accepted':
        return OrderStatus.accepted;
      case 'sewing':
        return OrderStatus.sewing;
      case 'quality':
        return OrderStatus.quality;
      case 'ready':
        return OrderStatus.ready;
      case 'delivery':
        return OrderStatus.delivery;
      case 'closed':
        return OrderStatus.closed;
      case 'rework':
        return OrderStatus.rework;
      default:
        return OrderStatus.newOrder;
    }
  }

  String toJson() {
    switch (this) {
      case OrderStatus.newOrder:
        return 'new';
      case OrderStatus.accepted:
        return 'accepted';
      case OrderStatus.sewing:
        return 'sewing';
      case OrderStatus.quality:
        return 'quality';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.delivery:
        return 'delivery';
      case OrderStatus.closed:
        return 'closed';
      case OrderStatus.rework:
        return 'rework';
    }
  }
}
