import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // Added for debugPrint in deleteHostel
import '../models/hostel_model.dart'; // Assuming this path is correct

class HostelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'hostels';

  // Add a new hostel with images
  Future<String> addHostelWithImages(
      HostelModel hostel,
      String adminId,
      List<String> imageUrls,
      String address,
      String contact,
      String description,
      String facilities,
      ) async {
    try {
      final docRef = _firestore.collection(_collection).doc();

      final hostelData = {
        'id': docRef.id,
        'name': hostel.name,
        'city': hostel.city,
        'gender': hostel.gender,
        'rating': hostel.rating,
        'price': hostel.price,
        'latitude': hostel.latitude,
        'longitude': hostel.longitude,
        'adminId': adminId,
        'images': imageUrls,
        'address': address,
        'contact': contact,
        'description': description,
        'facilities': facilities,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await docRef.set(hostelData);
      return docRef.id;
    } catch (e) {
      // Re-throw the exception with a more detailed message
      throw Exception('Failed to add hostel with images: $e');
    }
  }

  // Add a new hostel (legacy method)
  Future<String> addHostel(HostelModel hostel, String adminId) async {
    try {
      final docRef = _firestore.collection(_collection).doc();

      // Create hostel data with admin ID
      final hostelData = {
        'id': docRef.id,
        'name': hostel.name,
        'city': hostel.city,
        'gender': hostel.gender,
        'rating': hostel.rating,
        'price': hostel.price,
        'latitude': hostel.latitude,
        'longitude': hostel.longitude,
        'adminId': adminId,
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
      };

      await docRef.set(hostelData);
      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add hostel: $e');
    }
  }

  // Get all hostels
  Future<List<HostelModel>> getAllHostels() async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => HostelModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch hostels: $e');
    }
  }

  // Get hostels by city
  Future<List<HostelModel>> getHostelsByCity(String city) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('city', isEqualTo: city)
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => HostelModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch hostels by city: $e');
    }
  }

  // Get hostels by admin
  Future<List<HostelModel>> getAdminHostels(String adminId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('adminId', isEqualTo: adminId)
          .get();

      return snapshot.docs
          .map((doc) => HostelModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch admin hostels: $e');
    }
  }

  // Get single hostel by ID
  Future<HostelModel?> getHostelById(String hostelId) async {
    try {
      final doc = await _firestore.collection(_collection).doc(hostelId).get();

      if (doc.exists) {
        return HostelModel.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      throw Exception('Failed to fetch hostel by ID: $e');
    }
  }

  // Update hostel
  Future<void> updateHostel(String hostelId, Map<String, dynamic> updates) async {
    try {
      await _firestore.collection(_collection).doc(hostelId).update(updates);
    } catch (e) {
      throw Exception('Failed to update hostel: $e');
    }
  }

  // Delete hostel from Firestore
  Future<void> deleteHostel(String hostelId) async {
    try {
      debugPrint('🗑️ Attempting to delete hostel: $hostelId');

      // Delete the hostel document
      await _firestore
          .collection(_collection)
          .doc(hostelId)
          .delete();

      debugPrint('✅ Hostel deleted successfully: $hostelId');
    } catch (e) {
      debugPrint('❌ Error deleting hostel: $e');
      throw Exception('Failed to delete hostel: $e');
    }
  }

  // Update hostel rating
  Future<void> updateHostelRating(String hostelId, double newRating) async {
    try {
      await _firestore.collection(_collection).doc(hostelId).update({
        'rating': newRating,
      });
    } catch (e) {
      throw Exception('Failed to update rating: $e');
    }
  }

  // Search hostels
  Future<List<HostelModel>> searchHostels(String query) async {
    try {
      // Note: This implementation fetches all active hostels and filters locally
      // because Firestore does not support case-insensitive text search.
      final snapshot = await _firestore
          .collection(_collection)
          .where('isActive', isEqualTo: true)
          .get();

      // Filter results by name (Firestore doesn't support text search)
      return snapshot.docs
          .map((doc) => HostelModel.fromMap(doc.data()))
          .where((hostel) =>
          hostel.name.toLowerCase().contains(query.toLowerCase()))
          .toList();
    } catch (e) {
      throw Exception('Failed to search hostels: $e');
    }
  }

  // Stream of all hostels (real-time updates)
  Stream<List<HostelModel>> streamHostels() {
    return _firestore
        .collection(_collection)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => HostelModel.fromMap(doc.data()))
        .toList());
  }

  // Stream of hostels by city
  Stream<List<HostelModel>> streamHostelsByCity(String city) {
    return _firestore
        .collection(_collection)
        .where('city', isEqualTo: city)
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
        .map((doc) => HostelModel.fromMap(doc.data()))
        .toList());
  }
}