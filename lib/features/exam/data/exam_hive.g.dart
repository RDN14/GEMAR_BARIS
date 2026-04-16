// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_hive.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ExamSessionHiveAdapter extends TypeAdapter<ExamSessionHive> {
  @override
  final int typeId = 1;

  @override
  ExamSessionHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ExamSessionHive(
      id: fields[0] as String,
      patientName: fields[1] as String,
      age: fields[2] as int?,
      gender: fields[3] as String?,
      date: fields[4] as DateTime,
      items: (fields[5] as List).cast<AnalysisItemHive>(),
      suggestion: fields[6] as String?,
      createdAt: fields[7] as DateTime,
      updatedAt: fields[8] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ExamSessionHive obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.patientName)
      ..writeByte(2)
      ..write(obj.age)
      ..writeByte(3)
      ..write(obj.gender)
      ..writeByte(4)
      ..write(obj.date)
      ..writeByte(5)
      ..write(obj.items)
      ..writeByte(6)
      ..write(obj.suggestion)
      ..writeByte(7)
      ..write(obj.createdAt)
      ..writeByte(8)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ExamSessionHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AnalysisItemHiveAdapter extends TypeAdapter<AnalysisItemHive> {
  @override
  final int typeId = 2;

  @override
  AnalysisItemHive read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AnalysisItemHive(
      id: fields[0] as String,
      toothLabel: fields[1] as String?,
      inputPath: fields[2] as String?,
      resultPath: fields[3] as String?,
      score: fields[4] as int?,
      note: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AnalysisItemHive obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.toothLabel)
      ..writeByte(2)
      ..write(obj.inputPath)
      ..writeByte(3)
      ..write(obj.resultPath)
      ..writeByte(4)
      ..write(obj.score)
      ..writeByte(5)
      ..write(obj.note);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AnalysisItemHiveAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
