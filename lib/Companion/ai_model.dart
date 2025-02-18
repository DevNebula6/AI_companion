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
  final Map<String, dynamic>? metadata;

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
    this.metadata,
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
    metadata: json['metadata'] as Map<String, dynamic>?,
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'avatar_url': avatarUrl,
    'description': description,
    'physical': physical.toJson(),
    'personality': personality.toJson(),
    'background': background,
    'skills': skills,
    'voice': voice,
    'metadata': metadata,
  };
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
      age: json['age'] ?? 13,
      height: json['height'] ?? '',
      bodyType: json['bodyType'] ?? '',
      hairColor: json['hairColor'] ?? '',
      eyeColor: json['eyeColor'] ?? '',
      style: json['style'] ?? '',
      distinguishingFeatures: List<String>.from(json['distinguishingFeatures'] ?? []),
    );
  }

  Map<String, dynamic> toJson() => {
    'age': age,
    'height': height,
    'body_type': bodyType,
    'hair_color': hairColor,
    'eye_color': eyeColor,
    'style': style,
    'distinguishing_features': distinguishingFeatures,
  };
  
}

class PersonalityTraits {
  final List<String> primaryTraits;
  final List<String> secondaryTraits;
  final List<String> interests;
  final List<String> values;

  PersonalityTraits({
    required this.primaryTraits,
    required this.secondaryTraits,
    required this.interests,
    required this.values,
  });

  factory PersonalityTraits.fromJson(Map<String, dynamic> json) {
    return PersonalityTraits(
      primaryTraits: List<String>.from(json['primaryTraits'] ?? []),
      secondaryTraits: List<String>.from(json['secondaryTraits'] ?? []),
      interests: List<String>.from(json['interests'] ?? []),
      values: List<String>.from(json['values'] ?? []),
    );
  }
  Map<String, dynamic> toJson() => {
    'primary_traits': primaryTraits,
    'secondary_traits': secondaryTraits,
    'interests': interests,
    'values': values,
  };
}