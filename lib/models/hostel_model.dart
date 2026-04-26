class HostelModel {
  final String? id;
  final String name;
  final String city;
  final String gender;
  final double rating;
  final int price;
  final double latitude;
  final double longitude;
  final String? adminId;
  final bool? isActive;

  HostelModel({
    this.id,
    required this.name,
    required this.city,
    required this.gender,
    required this.rating,
    required this.price,
    required this.latitude,
    required this.longitude,
    this.adminId,
    this.isActive,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'city': city,
      'gender': gender,
      'rating': rating,
      'price': price,
      'latitude': latitude,
      'longitude': longitude,
      'adminId': adminId,
      'isActive': isActive ?? true,
    };
  }

  // Create from Firestore Map
  factory HostelModel.fromMap(Map<String, dynamic> map) {
    return HostelModel(
      id: map['id'],
      name: map['name'] ?? '',
      city: map['city'] ?? '',
      gender: map['gender'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      price: map['price'] ?? 0,
      latitude: (map['latitude'] ?? 0.0).toDouble(),
      longitude: (map['longitude'] ?? 0.0).toDouble(),
      adminId: map['adminId'],
      isActive: map['isActive'] ?? true,
    );
  }

  // Copy with method
  HostelModel copyWith({
    String? id,
    String? name,
    String? city,
    String? gender,
    double? rating,
    int? price,
    double? latitude,
    double? longitude,
    String? adminId,
    bool? isActive,
  }) {
    return HostelModel(
      id: id ?? this.id,
      name: name ?? this.name,
      city: city ?? this.city,
      gender: gender ?? this.gender,
      rating: rating ?? this.rating,
      price: price ?? this.price,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      adminId: adminId ?? this.adminId,
      isActive: isActive ?? this.isActive,
    );
  }
}