class BookingModel {
  final String id;
  final String userId;
  final String hostelId;
  final String hostelName;
  final String studentName;
  final String studentPhone;
  final String studentCnic;
  final String studentAddress;
  final String emergencyContact;
  final DateTime checkInDate;
  final int duration; // in months
  final String roomType; // Single, Double, Triple, Quad
  final String mealPlan; // No Meal, Breakfast Only, Half Board, Full Board
  final double totalPrice;
  final String status; // Pending, Confirmed, Rejected, Cancelled
  final DateTime createdAt;
  final DateTime? confirmedAt;

  BookingModel({
    required this.id,
    required this.userId,
    required this.hostelId,
    required this.hostelName,
    required this.studentName,
    required this.studentPhone,
    required this.studentCnic,
    required this.studentAddress,
    required this.emergencyContact,
    required this.checkInDate,
    required this.duration,
    required this.roomType,
    required this.mealPlan,
    required this.totalPrice,
    required this.status,
    required this.createdAt,
    this.confirmedAt,
  });

  // Convert to Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'hostelId': hostelId,
      'hostelName': hostelName,
      'studentName': studentName,
      'studentPhone': studentPhone,
      'studentCnic': studentCnic,
      'studentAddress': studentAddress,
      'emergencyContact': emergencyContact,
      'checkInDate': checkInDate.toIso8601String(),
      'duration': duration,
      'roomType': roomType,
      'mealPlan': mealPlan,
      'totalPrice': totalPrice,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'confirmedAt': confirmedAt?.toIso8601String(),
    };
  }

  // Create from Firestore Map
  factory BookingModel.fromMap(Map<String, dynamic> map) {
    return BookingModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      hostelId: map['hostelId'] ?? '',
      hostelName: map['hostelName'] ?? '',
      studentName: map['studentName'] ?? '',
      studentPhone: map['studentPhone'] ?? '',
      studentCnic: map['studentCnic'] ?? '',
      studentAddress: map['studentAddress'] ?? '',
      emergencyContact: map['emergencyContact'] ?? '',
      checkInDate: DateTime.parse(map['checkInDate']),
      duration: map['duration'] ?? 1,
      roomType: map['roomType'] ?? 'Single',
      mealPlan: map['mealPlan'] ?? 'No Meal',
      totalPrice: (map['totalPrice'] ?? 0).toDouble(),
      status: map['status'] ?? 'Pending',
      createdAt: DateTime.parse(map['createdAt']),
      confirmedAt: map['confirmedAt'] != null
          ? DateTime.parse(map['confirmedAt'])
          : null,
    );
  }

  // Copy with method for updating
  BookingModel copyWith({
    String? id,
    String? userId,
    String? hostelId,
    String? hostelName,
    String? studentName,
    String? studentPhone,
    String? studentCnic,
    String? studentAddress,
    String? emergencyContact,
    DateTime? checkInDate,
    int? duration,
    String? roomType,
    String? mealPlan,
    double? totalPrice,
    String? status,
    DateTime? createdAt,
    DateTime? confirmedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      hostelId: hostelId ?? this.hostelId,
      hostelName: hostelName ?? this.hostelName,
      studentName: studentName ?? this.studentName,
      studentPhone: studentPhone ?? this.studentPhone,
      studentCnic: studentCnic ?? this.studentCnic,
      studentAddress: studentAddress ?? this.studentAddress,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      checkInDate: checkInDate ?? this.checkInDate,
      duration: duration ?? this.duration,
      roomType: roomType ?? this.roomType,
      mealPlan: mealPlan ?? this.mealPlan,
      totalPrice: totalPrice ?? this.totalPrice,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      confirmedAt: confirmedAt ?? this.confirmedAt,
    );
  }
}