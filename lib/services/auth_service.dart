import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show SocketException;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_model.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Stream d'utilisateur transformé en AppUser
  Stream<AppUser?> get userStream {
    return _auth.authStateChanges().map((User? user) {
      if (user == null) return null;
      return AppUser.fromFirebase(user);
    });
  }

  AppUser? get currentUser {
    final user = _auth.currentUser;
    return user != null ? AppUser.fromFirebase(user) : null;
  }

  User? get currentFirebaseUser => _auth.currentUser;

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await _auth.signOut();
  }

  Future<void> sendEmailVerification() async {
    try {
      final user = _auth.currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } on FirebaseAuthException catch (e) {
      throw _authErrorMapper(e);
    } catch (e) {
      throw 'Erreur lors de l\'envoi de l\'email de vérification';
    }
  }

  Future<void> reloadCurrentUser() async {
    try {
      await _auth.currentUser?.reload();
    } catch (e) {
      if (kDebugMode) print('Error reloading user: $e');
    }
  }

  // Connexion avec Google
  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      return userCredential.user;
    } on FirebaseAuthException catch (e) {
      throw _authErrorMapper(e);
    } on SocketException {
      throw 'Vérifiez votre connexion internet';
    } catch (e) {
      if (kDebugMode) print('Google sign in error: $e');
      throw 'Une erreur est survenue lors de la connexion avec Google';
    }
  }

  // Connexion avec email/mot de passe
  Future<User?> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (result.user != null && !result.user!.emailVerified) {
        throw 'Veuillez vérifier votre email avant de vous connecter';
      }

      return result.user;
    } on FirebaseAuthException catch (e) {
      throw _authErrorMapper(e);
    } on SocketException {
      throw 'Vérifiez votre connexion internet';
    } catch (e) {
      if (e.toString().contains('Veuillez vérifier votre email')) rethrow;
      if (kDebugMode) print('Unexpected error: $e');
      throw 'Une erreur inattendue est survenue. Réessayez.';
    }
  }

  // Inscription avec email/mot de passe
  Future<User?> createUserWithEmailAndPassword({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (displayName != null && result.user != null) {
        await result.user!.updateDisplayName(displayName);
        await result.user!.reload();
      }

      if (result.user != null) {
        await result.user!.sendEmailVerification();
      }

      return _auth.currentUser;
    } on FirebaseAuthException catch (e) {
      throw _authErrorMapper(e);
    } on SocketException {
      throw 'Vérifiez votre connexion internet';
    } catch (e) {
      if (kDebugMode) print('Unexpected error: $e');
      throw 'Une erreur inattendue est survenue. Réessayez.';
    }
  }

  // Réinitialisation du mot de passe
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw _authErrorMapper(e);
    } on SocketException {
      throw 'Vérifiez votre connexion internet';
    } catch (e) {
      throw 'Une erreur inattendue est survenue. Réessayez.';
    }
  }

  Future<void> updateUserProfile({String? displayName, String? photoURL}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) throw 'Aucun utilisateur connecté';
      if (displayName != null) await user.updateDisplayName(displayName);
      if (photoURL != null) await user.updatePhotoURL(photoURL);
      await user.reload();
    } on FirebaseAuthException catch (e) {
      throw _authErrorMapper(e);
    } catch (e) {
      throw 'Erreur lors de la mise à jour du profil';
    }
  }

  String _authErrorMapper(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Email invalide';
      case 'user-disabled':
        return 'Utilisateur désactivé';
      case 'user-not-found':
        return 'Utilisateur non trouvé';
      case 'wrong-password':
        return 'Mot de passe incorrect';
      case 'email-already-in-use':
        return 'Cet email est déjà utilisé';
      case 'weak-password':
        return 'Le mot de passe est trop faible (min. 6 caractères)';
      case 'network-request-failed':
        return 'Vérifiez votre connexion internet';
      case 'too-many-requests':
        return 'Trop de tentatives. Réessayez plus tard';
      case 'invalid-credential':
        return 'Email ou mot de passe incorrect';
      default:
        if (kDebugMode) print('FirebaseAuthException: ${e.code} - ${e.message}');
        return 'Une erreur est survenue. Réessayez.';
    }
  }
}
