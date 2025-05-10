/// User types in the application
enum UserType {
  /// Regular registered user
  regular,

  /// Guest user (limited functionality)
  guest,

  /// Verified expert user (can verify mushroom identifications)
  expert,

  /// Admin user (full system access)
  admin,
}

/// Represents a user profile in the application
class UserProfile {
  /// Unique identifier
  final String id;

  /// User's email address
  final String email;

  /// Display name
  final String name;

  /// User type/role
  final UserType userType;

  /// User's bio/description
  final String? bio;

  /// URL to user's profile photo
  final String? photoUrl;

  /// Badges earned by the user
  final List<String>? badges;

  /// User's experience points
  final int experiencePoints;

  /// User's rank or level (based on experience)
  final int level;

  /// When the user joined
  final DateTime? joinedAt;

  /// Is the user's email verified
  final bool isEmailVerified;

  /// Is the user's expert status verified (for expert users only)
  final bool isExpertVerified;

  /// User's preferred regions for mushroom hunting
  final List<String>? preferredRegions;

  /// Constructor
  UserProfile({
    required this.id,
    required this.email,
    required this.name,
    required this.userType,
    this.bio,
    this.photoUrl,
    this.badges,
    this.experiencePoints = 0,
    this.level = 1,
    this.joinedAt,
    this.isEmailVerified = false,
    this.isExpertVerified = false,
    this.preferredRegions,
  });

  /// Create a copy of this profile with modified fields
  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    UserType? userType,
    String? bio,
    String? photoUrl,
    List<String>? badges,
    int? experiencePoints,
    int? level,
    DateTime? joinedAt,
    bool? isEmailVerified,
    bool? isExpertVerified,
    List<String>? preferredRegions,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      userType: userType ?? this.userType,
      bio: bio ?? this.bio,
      photoUrl: photoUrl ?? this.photoUrl,
      badges: badges ?? this.badges,
      experiencePoints: experiencePoints ?? this.experiencePoints,
      level: level ?? this.level,
      joinedAt: joinedAt ?? this.joinedAt,
      isEmailVerified: isEmailVerified ?? this.isEmailVerified,
      isExpertVerified: isExpertVerified ?? this.isExpertVerified,
      preferredRegions: preferredRegions ?? this.preferredRegions,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'userType': userType.index,
      'bio': bio,
      'photoUrl': photoUrl,
      'badges': badges ?? [],
      'experiencePoints': experiencePoints,
      'level': level,
      'joinedAt': joinedAt?.toIso8601String(),
      'isEmailVerified': isEmailVerified,
      'isExpertVerified': isExpertVerified,
      'preferredRegions': preferredRegions ?? [],
    };
  }

  /// Create from JSON data
  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'],
      email: json['email'] ?? '',
      name: json['name'] ?? 'User',
      userType: UserType.values[json['userType'] ?? 0],
      bio: json['bio'],
      photoUrl: json['photoUrl'],
      badges: json['badges'] != null ? List<String>.from(json['badges']) : [],
      experiencePoints: json['experiencePoints'] ?? 0,
      level: json['level'] ?? 1,
      joinedAt:
          json['joinedAt'] != null ? DateTime.parse(json['joinedAt']) : null,
      isEmailVerified: json['isEmailVerified'] ?? false,
      isExpertVerified: json['isExpertVerified'] ?? false,
      preferredRegions: json['preferredRegions'] != null
          ? List<String>.from(json['preferredRegions'])
          : [],
    );
  }

  /// Check if the user has a specific badge
  bool hasBadge(String badgeId) {
    return badges?.contains(badgeId) ?? false;
  }

  /// Check if user is an expert or admin
  bool get isExpert =>
      userType == UserType.expert || userType == UserType.admin;

  /// Check if user is an admin
  bool get isAdmin => userType == UserType.admin;

  /// Check if user is a guest
  bool get isGuest => userType == UserType.guest;

  /// Check if user can verify identifications
  bool get canVerifyIdentifications => isExpert && isExpertVerified;

  /// Get display initials (e.g., "JS" from "John Smith")
  String get initials {
    if (name.isEmpty) return '';
    final nameParts = name.split(' ');
    if (nameParts.length > 1) {
      return '${nameParts[0][0]}${nameParts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '';
  }
}
