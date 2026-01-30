import 'package:hive/hive.dart';
import 'package:flutter/material.dart';
import '../models/alert_schedule.dart';

/// ===========================================================
/// ALERT SCHEDULE HIVE ADAPTER
/// Handles serialization/deserialization for Hive storage
/// ===========================================================
class AlertScheduleAdapter extends TypeAdapter<AlertSchedule> {
  @override
  final int typeId = 100; // Unique type ID for AlertSchedule

  @override
  AlertSchedule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };

    return AlertSchedule(
      start: TimeOfDay(
        hour: fields[0] as int,
        minute: fields[1] as int,
      ),
      end: TimeOfDay(
        hour: fields[2] as int,
        minute: fields[3] as int,
      ),
      activeDays: (fields[4] as List).cast<int>(),
    );
  }

  @override
  void write(BinaryWriter writer, AlertSchedule obj) {
    writer
      ..writeByte(5) // Number of fields
      ..writeByte(0)
      ..write(obj.start.hour)
      ..writeByte(1)
      ..write(obj.start.minute)
      ..writeByte(2)
      ..write(obj.end.hour)
      ..writeByte(3)
      ..write(obj.end.minute)
      ..writeByte(4)
      ..write(obj.activeDays);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertScheduleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
