import 'dart:developer';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> createUserWithEmailAndPassword(
      String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
          email: email, password: password);
      return cred.user;
    } catch (e) {
      log("Something went wrong in createUser: $e");
    }
    return null;
  }

  // Modified to support login with username or email
  Future<User?> loginUser(String usernameOrEmail, String password) async {
    try {
      // Check if input is an email
      bool isEmail = usernameOrEmail.contains('@');

      if (isEmail) {
        // If it's an email, use Firebase Auth directly
        final cred = await _auth.signInWithEmailAndPassword(
            email: usernameOrEmail, password: password);
        return cred.user;
      } else {
        // If it's a username, find the corresponding email in Firestore
        final querySnapshot = await _firestore
            .collection('user-data')
            .where('username', isEqualTo: usernameOrEmail)
            .limit(1)
            .get();

        if (querySnapshot.docs.isEmpty) {
          log("No user found with this username");
          return null;
        }

        // Get the email associated with this username
        final userDoc = querySnapshot.docs.first;
        final email = userDoc.data()['email'] as String;

        // Now login with the email
        final cred = await _auth.signInWithEmailAndPassword(
            email: email, password: password);
        return cred.user;
      }
    } catch (e) {
      log("Something went wrong in loginUser: $e");
      return null;
    }
  }

  // Keep this for backward compatibility
  Future<User?> loginUserWithEmailAndPassword(
      String email, String password) async {
    return loginUser(email, password);
  }

  Future<void> signout() async {
    try {
      await _googleSignIn.signOut(); // Sign out from Google
      await _auth.signOut();         // Sign out from Firebase
    } catch (e) {
      log("Something went wrong in signout: $e");
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();

      if (googleUser == null) return null;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      log("Sign-in error: $e");
      return null;
    }
  }

  // Helper method to check if a user exists with the given username or email
  Future<bool> checkUserExists(String usernameOrEmail) async {
    try {
      // Check if input is an email
      bool isEmail = usernameOrEmail.contains('@');

      if (isEmail) {
        // Check if email exists in Firebase Auth
        final methods = await _auth.fetchSignInMethodsForEmail(usernameOrEmail);
        return methods.isNotEmpty;
      } else {
        // Check if username exists in Firestore
        final querySnapshot = await _firestore
            .collection('user-data')
            .where('username', isEqualTo: usernameOrEmail)
            .limit(1)
            .get();

        return querySnapshot.docs.isNotEmpty;
      }
    } catch (e) {
      log("Error checking if user exists: $e");
      return false;
    }
  }
}
