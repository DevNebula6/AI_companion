import 'package:ai_companion/Companion/ai_model.dart';
import 'package:hive/hive.dart' show BinaryReader, BinaryWriter, TypeAdapter;

class AICompanionAdapter extends TypeAdapter<AICompanion> {
  @override
  final int typeId = 0;

  @override
  AICompanion read(BinaryReader reader) {
    return AICompanion(
      id: reader.read(),
      name: reader.read(),
      gender: _readEnum(reader, CompanionGender.values) ?? CompanionGender.other,
      artStyle: _readEnum(reader, CompanionArtStyle.values) ?? CompanionArtStyle.realistic,
      avatarUrl: reader.read(),
      description: reader.read(),
      physical: reader.read(),
      personality: reader.read(),
      background: List<String>.from(reader.read()),
      skills: List<String>.from(reader.read()),
      voice: List<String>.from(reader.read()),
      metadata: Map<String, dynamic>.from(reader.read()),
    );
  }

  @override
  void write(BinaryWriter writer, AICompanion obj) {
    writer.write(obj.id);
    writer.write(obj.name);
    writer.write(obj.gender.toString());
    writer.write(obj.artStyle.toString());
    writer.write(obj.avatarUrl);
    writer.write(obj.description);
    writer.write(obj.physical);
    writer.write(obj.personality);
    writer.write(obj.background);
    writer.write(obj.skills);
    writer.write(obj.voice);
    writer.write(obj.metadata);
  }
  // Helper method to read enums
  T? _readEnum<T>(BinaryReader reader, List<T> values) {
    final String? value = reader.read();
    if (value == null) return null;
    return values.firstWhere(
      (e) => e.toString() == value,
      orElse: () => values.first
    );
  }
}

class PhysicalAttributesAdapter extends TypeAdapter<PhysicalAttributes> {
  @override
  final int typeId = 1;

  @override
  PhysicalAttributes read(BinaryReader reader) {
    return PhysicalAttributes(
      age: reader.read(),
      height: reader.read(),
      bodyType: reader.read(),
      hairColor: reader.read(),
      eyeColor: reader.read(),
      style: reader.read(),
      distinguishingFeatures: List<String>.from(reader.read()),
    );
  }

  @override
  void write(BinaryWriter writer, PhysicalAttributes obj) {
    writer.write(obj.age);
    writer.write(obj.height);
    writer.write(obj.bodyType);
    writer.write(obj.hairColor);
    writer.write(obj.eyeColor);
    writer.write(obj.style);
    writer.write(obj.distinguishingFeatures);
  }
}

class PersonalityTraitsAdapter extends TypeAdapter<PersonalityTraits> {
  @override
  final int typeId = 2;

  @override
  PersonalityTraits read(BinaryReader reader) {
    return PersonalityTraits(
      primaryTraits: List<String>.from(reader.read()),
      secondaryTraits: List<String>.from(reader.read()),
      interests: List<String>.from(reader.read()),
      values: List<String>.from(reader.read()),
    );
  }

  @override
  void write(BinaryWriter writer, PersonalityTraits obj) {
    writer.write(obj.primaryTraits);
    writer.write(obj.secondaryTraits);
    writer.write(obj.interests);
    writer.write(obj.values);
  }
}

class CompanionGenderAdapter extends TypeAdapter<CompanionGender> {
  @override
  final int typeId = 3;

  @override
  CompanionGender read(BinaryReader reader) {
    return CompanionGender.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, CompanionGender obj) {
    writer.writeByte(obj.index);
  }
}

class CompanionArtStyleAdapter extends TypeAdapter<CompanionArtStyle> {
  @override
  final int typeId = 4;

  @override
  CompanionArtStyle read(BinaryReader reader) {
    return CompanionArtStyle.values[reader.readByte()];
  }

  @override
  void write(BinaryWriter writer, CompanionArtStyle obj) {
    writer.writeByte(obj.index);
  }
}