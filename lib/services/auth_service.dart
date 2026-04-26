import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🟢 Sign Up - FIXED: Now awaits Firestore write
  Future<User?> signUp({
    required String name,
    required String email,
    required String password,
    required bool isAdmin,
  }) async {
    try {
      // Create Firebase Auth user
      UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      User? user = result.user;

      if (user != null) {
        // ✅ FIXED: Now AWAITS the Firestore write
        await _firestore.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'name': name,
          'email': email,
          'isAdmin': isAdmin,
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('✅ User document created in Firestore with isAdmin: $isAdmin');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Signup failed');
    } catch (e) {
      throw Exception('Error creating user: $e');
    }
  }

  // 🟡 Login
  Future<User?> signIn({
    required String email,
    required String password,
  }) async {
    try {
      UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return result.user;
    } on FirebaseAuthException catch (e) {
      throw Exception(e.message ?? 'Login failed');
    }
  }

  // 🔴 Logout
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // 👤 Current User
  User? get currentUser => _auth.currentUser;

  // 📄 Get User Data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      print('Error fetching user data: $e');
      return null;
    }
  }

  // ✅ Check if user is admin
  Future<bool> isAdmin(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (!doc.exists) {
        print('⚠️ User document does not exist for uid: $uid');
        return false;
      }
      Map<String, dynamic>? data = doc.data() as Map<String, dynamic>?;
      bool adminStatus = data?['isAdmin'] ?? false;
      print('👤 Admin status for $uid: $adminStatus');
      return adminStatus;
    } catch (e) {
      print('Error checking admin status: $e');
      return false;
    }
  }
}