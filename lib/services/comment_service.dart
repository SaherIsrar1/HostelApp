import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/comment_model.dart';

class CommentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'comments';

  // Add a new comment/review
  Future<String> addComment(CommentModel comment) async {
    try {
      final docRef = _firestore.collection(_collection).doc();

      final commentWithId = comment.copyWith(id: docRef.id);

      await docRef.set(commentWithId.toMap());

      // Update hostel average rating
      await _updateHostelRating(comment.hostelId);

      return docRef.id;
    } catch (e) {
      throw Exception('Failed to add comment: $e');
    }
  }

  // Get all comments for a hostel
  Future<List<CommentModel>> getHostelComments(String hostelId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('hostelId', isEqualTo: hostelId)
          .get();

      final comments = snapshot.docs
          .map((doc) => CommentModel.fromMap(doc.data()))
          .toList();

      // Sort by date (newest first)
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));

      return comments;
    } catch (e) {
      throw Exception('Failed to fetch comments: $e');
    }
  }

  // Stream of comments for real-time updates
  Stream<List<CommentModel>> streamHostelComments(String hostelId) {
    return _firestore
        .collection(_collection)
        .where('hostelId', isEqualTo: hostelId)
        .snapshots()
        .map((snapshot) {
      final comments = snapshot.docs
          .map((doc) => CommentModel.fromMap(doc.data()))
          .toList();
      comments.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return comments;
    });
  }

  // Check if user already reviewed this hostel
  Future<bool> hasUserReviewed(String hostelId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('hostelId', isEqualTo: hostelId)
          .where('userId', isEqualTo: userId)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // Get user's review for a hostel
  Future<CommentModel?> getUserReview(String hostelId, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('hostelId', isEqualTo: hostelId)
          .where('userId', isEqualTo: userId)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return CommentModel.fromMap(snapshot.docs.first.data());
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update existing comment
  Future<void> updateComment(String commentId, double rating, String comment) async {
    try {
      await _firestore.collection(_collection).doc(commentId).update({
        'rating': rating,
        'comment': comment,
      });

      // Get hostel ID from comment
      final doc = await _firestore.collection(_collection).doc(commentId).get();
      final hostelId = doc.data()?['hostelId'];

      if (hostelId != null) {
        await _updateHostelRating(hostelId);
      }
    } catch (e) {
      throw Exception('Failed to update comment: $e');
    }
  }

  // Delete comment
  Future<void> deleteComment(String commentId) async {
    try {
      // Get hostel ID before deleting
      final doc = await _firestore.collection(_collection).doc(commentId).get();
      final hostelId = doc.data()?['hostelId'];

      await _firestore.collection(_collection).doc(commentId).delete();

      if (hostelId != null) {
        await _updateHostelRating(hostelId);
      }
    } catch (e) {
      throw Exception('Failed to delete comment: $e');
    }
  }

  // Update hostel's average rating
  Future<void> _updateHostelRating(String hostelId) async {
    try {
      final comments = await getHostelComments(hostelId);

      if (comments.isEmpty) {
        // No reviews, set rating to 0
        await _firestore.collection('hostels').doc(hostelId).update({
          'rating': 0.0,
          'reviewCount': 0,
        });
        return;
      }

      // Calculate average rating
      double totalRating = 0;
      for (var comment in comments) {
        totalRating += comment.rating;
      }
      double averageRating = totalRating / comments.length;

      // Update hostel rating
      await _firestore.collection('hostels').doc(hostelId).update({
        'rating': double.parse(averageRating.toStringAsFixed(1)),
        'reviewCount': comments.length,
      });
    } catch (e) {
      debugPrint('Error updating hostel rating: $e');
    }
  }

  // Get rating statistics
  Future<Map<String, int>> getRatingStats(String hostelId) async {
    try {
      final comments = await getHostelComments(hostelId);

      Map<String, int> stats = {
        '5': 0,
        '4': 0,
        '3': 0,
        '2': 0,
        '1': 0,
      };

      for (var comment in comments) {
        String starKey = comment.rating.floor().toString();
        stats[starKey] = (stats[starKey] ?? 0) + 1;
      }

      return stats;
    } catch (e) {
      return {'5': 0, '4': 0, '3': 0, '2': 0, '1': 0};
    }
  }
}