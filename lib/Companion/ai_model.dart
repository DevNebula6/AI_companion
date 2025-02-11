class AICompanion {
  final String id;
  final String name;
  final String avatarUrl;
  final String description;
  final PhysicalAttributes physical;
  final PersonalityTraits personality;
  final List<String> background;
  final List<String> skills;
  final List<String> voice;
  final Map<String, dynamic> metadata;

  AICompanion({
    required this.id,
    required this.name,
    required this.avatarUrl,
    required this.description,
    required this.physical,
    required this.personality,
    required this.background,
    required this.skills,
    required this.voice,
    this.metadata = const {},
  });

  factory AICompanion.fromJson(Map<String, dynamic> json) => AICompanion(
    id: json['id'],
    name: json['name'],
    avatarUrl: json['avatar_url'],
    description: json['description'],
    physical: PhysicalAttributes.fromJson(json['physical']),
    personality: PersonalityTraits.fromJson(json['personality']),
    background: List<String>.from(json['background']),
    skills: List<String>.from(json['skills']),
    voice: List<String>.from(json['voice']),
    metadata: json['metadata'] ?? {},
  );
}

class PhysicalAttributes {
  final int age;
  final String height;
  final String bodyType;
  final String hairColor;
  final String eyeColor;
  final String style;
  final List<String> distinguishingFeatures;

  PhysicalAttributes({
    required this.age,
    required this.height,
    required this.bodyType,
    required this.hairColor,
    required this.eyeColor,
    required this.style,
    required this.distinguishingFeatures,
  });
  
  factory PhysicalAttributes.fromJson(Map<String, dynamic> json) {
    return PhysicalAttributes(
      age: json['age'],
      height: json['height'],
      bodyType: json['body_type'],
      hairColor: json['hair_color'],
      eyeColor: json['eye_color'],
      style: json['style'],
      distinguishingFeatures: List<String>.from(json['distinguishing_features']),
    );
  }
}

class PersonalityTraits {
  final List<String> primaryTraits;
  final List<String> secondaryTraits;
  final Map<String, double> traitIntensities;
  final List<String> interests;
  final List<String> values;

  PersonalityTraits({
    required this.primaryTraits,
    required this.secondaryTraits,
    required this.traitIntensities,
    required this.interests,
    required this.values,
  });

  factory PersonalityTraits.fromJson(Map<String, dynamic> json) {
    return PersonalityTraits(
      primaryTraits: List<String>.from(json['primary_traits']),
      secondaryTraits: List<String>.from(json['secondary_traits']),
      traitIntensities: Map<String, double>.from(json['trait_intensities']),
      interests: List<String>.from(json['interests']),
      values: List<String>.from(json['values']),
    );
  }
}