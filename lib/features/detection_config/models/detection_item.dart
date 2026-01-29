import '../../../data/models/alert_config_model.dart' as model;
import 'package:flutter/material.dart';

class DetectionItem {
  final model.DetectionType type;
  final String title;
  final String description;
  final IconData icon;

  DetectionItem({
    required this.type,
    required this.title,
    required this.description,
    required this.icon,
  });
}
