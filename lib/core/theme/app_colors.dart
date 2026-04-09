import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Primary — индиго (профессионально, нейтрально)
  static const primary = Color(0xFF3F51B5);
  static const primaryLight = Color(0xFF757DE8);
  static const primaryDark = Color(0xFF002984);

  // Accent
  static const accent = Color(0xFF00BCD4);

  // Status colors (заказы/дедлайны)
  static const statusNew = Color(0xFF9E9E9E);
  static const statusAccepted = Color(0xFF2196F3);
  static const statusSewing = Color(0xFF9C27B0);
  static const statusQuality = Color(0xFFFF9800);
  static const statusReady = Color(0xFF4CAF50);
  static const statusDelivery = Color(0xFF00BCD4);
  static const statusClosed = Color(0xFF607D8B);
  static const statusRework = Color(0xFFF44336);

  // Deadline colors
  static const deadlineOk = Color(0xFF4CAF50);      // > 3 дней
  static const deadlineWarn = Color(0xFFFF9800);     // 1-3 дня
  static const deadlineCritical = Color(0xFFF44336); // < 1 дня / просрочено

  // Plan colors
  static const planAhead = Color(0xFF4CAF50);
  static const planBehind = Color(0xFFF44336);
  static const planOnTrack = Color(0xFF2196F3);

  // Neutral
  static const white = Color(0xFFFFFFFF);
  static const black = Color(0xFF000000);
  static const grey100 = Color(0xFFF5F5F5);
  static const grey200 = Color(0xFFEEEEEE);
  static const grey400 = Color(0xFFBDBDBD);
  static const grey600 = Color(0xFF757575);
  static const grey800 = Color(0xFF424242);

  // Role badge colors
  static const roleDirector = Color(0xFF3F51B5);
  static const roleHeadManager = Color(0xFF673AB7);
  static const roleManager = Color(0xFF009688);
  static const roleSeamstress = Color(0xFFE91E63);
}
