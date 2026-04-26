import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/booking_model.dart';

class BookingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'bookings';

  // Create a new booking
  Future<String> createBooking(BookingModel booking) async {
    try {
      // Generate a new document ID
      final docRef = _firestore.collection(_collection).doc();

      // Update booking with the generated ID
      final bookingWithId = booking.copyWith(id: docRef.id);

      // Save to Firestore
      await docRef.set(bookingWithId.toMap());

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  // Get all bookings for a specific user
  Future<List<BookingModel>> getUserBookings(String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('userId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BookingModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  // Get all bookings for a specific hostel (for admin)
  Future<List<BookingModel>> getHostelBookings(String hostelId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('hostelId', isEqualTo: hostelId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs
          .map((doc) => BookingModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch hostel bookings: $e');
    }
  }

  // Get a single booking by ID
  Future<BookingModel?> getBookingById(String bookingId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(bookingId).get();

      if (doc.exists) {
        return BookingModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch booking: $e');
    }
  }

  // Update booking status (admin function)
  Future<void> updateBookingStatus(String bookingId, String status) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).update({
        'status': status,
        'confirmedAt': status == 'Confirmed'
            ? DateTime.now().toIso8601String()
            : null,
      });
    } catch (e) {
      throw Exception('Failed to update booking status: $e');
    }
  }

  // Cancel booking (student function)
  Future<void> cancelBooking(String bookingId) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).update({
        'status': 'Cancelled',
      });
    } catch (e) {
      throw Exception('Failed to cancel booking: $e');
    }
  }

  // Delete booking
  Future<void> deleteBooking(String bookingId) async {
    try {
      await _firestore.collection(_collection).doc(bookingId).delete();
    } catch (e) {
      throw Exception('Failed to delete booking: $e');
    }
  }

  // Stream of user bookings (real-time updates)
  Stream<List<BookingModel>> streamUserBookings(String userId) {
    return _firestore
        .collection(_collection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BookingModel.fromMap(doc.data()))
        .toList());
  }

  // Stream of hostel bookings (real-time updates for admin)
  Stream<List<BookingModel>> streamHostelBookings(String hostelId) {
    return _firestore
        .collection(_collection)
        .where('hostelId', isEqualTo: hostelId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => BookingModel.fromMap(doc.data()))
        .toList());
  }

  // Get booking count by status
  Future<Map<String, int>> getBookingStatsByHostel(String hostelId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('hostelId', isEqualTo: hostelId)
          .get();

      Map<String, int> stats = {
        'Pending': 0,
        'Confirmed': 0,
        'Rejected': 0,
        'Cancelled': 0,
      };

      for (var doc in snapshot.docs) {
        final status = doc.data()['status'] as String;
        stats[status] = (stats[status] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      throw Exception('Failed to fetch booking stats: $e');
    }
  }
}