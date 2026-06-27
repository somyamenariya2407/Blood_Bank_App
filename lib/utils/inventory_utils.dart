import 'package:flutter/material.dart';

String getStatus(int units) {
  if (units <= 5) return "critical";
  if (units <= 20) return "low";
  return "adequate";
}

Color getStatusColor(String status) {
  switch (status) {
    case "critical":
      return Colors.red;
    case "low":
      return Colors.orange;
    default:
      return Colors.green;
  }
}