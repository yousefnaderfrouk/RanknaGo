import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'dart:math';
import 'dart:async';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Auth state stream
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Sign up with email and password
  Future<UserCredential?> signUpWithEmail({
    required String email,
    required String password,
    required String name,
  }) async {
    try {
      // Create user account
      UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Update display name
      await userCredential.user?.updateDisplayName(name);
      await userCredential.user?.reload();

      // Generate verification token for SMTP email
      final random = Random();
      final verificationToken = List.generate(
        32,
        (_) => random.nextInt(16).toRadixString(16),
      ).join();

      // Save verification token to Firestore
      await _firestore
          .collection('email_verifications')
          .doc(userCredential.user?.uid)
          .set({
            'token': verificationToken,
            'email': email,
            'createdAt': FieldValue.serverTimestamp(),
            'expiresAt': FieldValue.serverTimestamp(),
            'verified': false,
          });

      // Create verification link
      final verificationLink =
          'https://raknago-pro.firebaseapp.com/verify-email?token=$verificationToken&uid=${userCredential.user?.uid}';

      // Send verification email via SMTP
      await _sendVerificationEmailViaSMTP(email, verificationLink, name);

      // Create user document in Firestore
      // Normalize email to lowercase for consistent searching
      await _firestore.collection('users').doc(userCredential.user?.uid).set({
        'email': email.trim().toLowerCase(),
        'name': name,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'phoneNumber': null,
        'photoURL': null,
        'isEmailVerified': false,
        'profileCompleted': false,
        'role': 'user', // Default role
        'status': 'active', // Default status
      });

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An error occurred: $e';
    }
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      // Sign in with email and password
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Check if email is verified from Firestore (not Firebase Auth)
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user!.uid)
          .get();

      final userData = userDoc.data();
      final isEmailVerified = userData?['isEmailVerified'] ?? false;

      if (!isEmailVerified) {
        await _auth.signOut();
        throw 'Please verify your email before signing in. Check your inbox for the verification link.';
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  // Sign in with Google
  Future<UserCredential?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      UserCredential userCredential = await _auth.signInWithCredential(
        credential,
      );

      // Check if user document exists, if not create it
      final userDoc = await _firestore
          .collection('users')
          .doc(userCredential.user?.uid)
          .get();

      if (!userDoc.exists) {
        await _firestore.collection('users').doc(userCredential.user?.uid).set({
          'email': userCredential.user?.email,
          'name': userCredential.user?.displayName ?? '',
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
          'phoneNumber': userCredential.user?.phoneNumber,
          'photoURL': userCredential.user?.photoURL,
          'isEmailVerified': userCredential.user?.emailVerified ?? false,
        });
      } else {
        // Update existing user document
        await _firestore
            .collection('users')
            .doc(userCredential.user?.uid)
            .update({
              'updatedAt': FieldValue.serverTimestamp(),
              'photoURL': userCredential.user?.photoURL,
              'isEmailVerified': userCredential.user?.emailVerified ?? false,
            });
      }

      return userCredential;
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An error occurred: $e';
    }
  }

  // Sign out
  Future<void> signOut() async {
    await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
  }

  // Send password reset email using Firebase Auth's built-in method (FREE)
  // This generates an oobCode that can be used to reset password directly in Firebase Auth
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      // Normalize email (lowercase, trim)
      final normalizedEmail = email.trim().toLowerCase();
      print('Sending password reset email to: $normalizedEmail');

      // Use Firebase Auth's built-in sendPasswordResetEmail
      // This is FREE and generates an oobCode automatically
      await _auth.sendPasswordResetEmail(
        email: normalizedEmail,
        // Customize the action code settings to use our custom domain
        actionCodeSettings: ActionCodeSettings(
          url: 'https://raknago-pro.firebaseapp.com/reset-password',
          handleCodeInApp: false, // Open in browser, not app
          androidPackageName: null,
          iOSBundleId: null,
        ),
      );

      print('Password reset email sent via Firebase Auth to $normalizedEmail');
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw e.toString();
    }
  }

  // Send password reset email via SMTP
  Future<void> _sendPasswordResetEmailViaSMTP(
    String email,
    String resetLink,
  ) async {
    // SMTP Configuration - Using Gmail (free)
    // IMPORTANT: Make sure you have:
    // 1. Enabled 2-Step Verification on your Gmail account
    // 2. Generated an App Password from: https://myaccount.google.com/apppasswords
    // 3. Use the App Password (16 characters) instead of your regular password
    const String smtpUsername = 'keroyousf8@gmail.com';
    const String smtpPassword =
        'vpshkbealjzhqfsm'; // Gmail App Password (without spaces)

    try {
      print('Attempting to send password reset email to $email via SMTP...');

      // Create SMTP server for Gmail
      final smtpServer = gmail(smtpUsername, smtpPassword);

      // Create email message
      final message = Message()
        ..from = Address(smtpUsername, 'RaknaGo')
        ..recipients.add(email)
        ..subject = 'Reset Your Password - RaknaGo'
        ..headers = {
          'X-Priority': '1',
          'X-MSMail-Priority': 'High',
          'Importance': 'high',
        }
        ..html =
            '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Password Reset</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #1E88E5 0%, #1976D2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
    <h1 style="color: white; margin: 0;">RaknaGo</h1>
  </div>
  <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
    <h2 style="color: #1E88E5; margin-top: 0;">Reset Your Password</h2>
    <p>Hello,</p>
    <p>We received a request to reset your password for your RaknaGo account. Click the button below to reset your password:</p>
    <div style="text-align: center; margin: 30px 0;">
      <a href="$resetLink" style="background: #1E88E5; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: bold;">Reset Password</a>
    </div>
    <p style="color: #666; font-size: 14px;">Or copy and paste this link into your browser:</p>
    <p style="color: #1E88E5; font-size: 12px; word-break: break-all; background: white; padding: 10px; border-radius: 4px;">$resetLink</p>
    <p style="color: #666; font-size: 14px;">This link will expire in 1 hour.</p>
    <p style="color: #666; font-size: 14px;">If you didn't request a password reset, please ignore this email. Your password will remain unchanged.</p>
    <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
    <p style="color: #999; font-size: 12px; text-align: center;">© ${DateTime.now().year} RaknaGo. All rights reserved.</p>
  </div>
</body>
</html>
        '''
        ..text =
            'Reset Your Password\n\nClick this link to reset your password: $resetLink\n\nThis link will expire in 1 hour.\n\nIf you didn\'t request a password reset, please ignore this email. Your password will remain unchanged.';

      // Send email with retry logic
      int retryCount = 0;
      const maxRetries = 3;
      bool sent = false;

      while (retryCount < maxRetries && !sent) {
        try {
          print('Sending email (attempt ${retryCount + 1}/$maxRetries)...');
          final sendReport = await send(message, smtpServer).timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw TimeoutException('SMTP connection timeout');
            },
          );

          print('Password reset email sent successfully via SMTP to $email');
          print('Send report: ${sendReport.toString()}');
          sent = true;
        } catch (e) {
          retryCount++;
          print('Error sending email (attempt $retryCount/$maxRetries): $e');

          if (retryCount < maxRetries) {
            // Wait before retry (exponential backoff)
            await Future.delayed(Duration(seconds: retryCount * 2));
          } else {
            // All retries failed
            throw Exception(
              'Failed to send password reset email after $maxRetries attempts: $e',
            );
          }
        }
      }
    } catch (e) {
      print('Error sending password reset email via SMTP: $e');

      // Provide helpful error messages
      String errorMessage = 'Failed to send password reset email. ';
      if (e.toString().contains('authentication') ||
          e.toString().contains('535')) {
        errorMessage += 'Please check your Gmail App Password settings.';
      } else if (e.toString().contains('timeout') ||
          e.toString().contains('connection')) {
        errorMessage +=
            'Network connection issue. Please check your internet connection.';
      } else if (e.toString().contains('550') ||
          e.toString().contains('rejected')) {
        errorMessage +=
            'Email address may be invalid or rejected by the server.';
      } else {
        errorMessage += 'Error: $e';
      }

      throw Exception(errorMessage);
    }
  }

  // Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw _handleAuthException(e);
    } catch (e) {
      throw 'An error occurred: $e';
    }
  }

  // Send verification email via SMTP
  Future<void> _sendVerificationEmailViaSMTP(
    String email,
    String verificationLink,
    String name,
  ) async {
    // SMTP Configuration
    const String smtpUsername = 'keroyousf8@gmail.com';
    const String smtpPassword =
        'vpshkbealjzhqfsm'; // Gmail App Password (without spaces)

    try {
      // Create SMTP server for Gmail
      final smtpServer = gmail(smtpUsername, smtpPassword);

      // Create email message
      final message = Message()
        ..from = Address(smtpUsername, 'RaknaGo')
        ..recipients.add(email)
        ..subject = 'Verify your email address - RaknaGo'
        ..html =
            '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Email Verification</title>
</head>
<body style="font-family: Arial, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
  <div style="background: linear-gradient(135deg, #1E88E5 0%, #1976D2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
    <h1 style="color: white; margin: 0;">RaknaGo</h1>
  </div>
  <div style="background: #f9f9f9; padding: 30px; border-radius: 0 0 10px 10px;">
    <h2 style="color: #1E88E5; margin-top: 0;">Welcome, $name!</h2>
    <p>Thank you for signing up for RaknaGo! Please verify your email address by clicking the button below:</p>
    <div style="text-align: center; margin: 30px 0;">
      <a href="$verificationLink" style="background: #1E88E5; color: white; padding: 14px 28px; text-decoration: none; border-radius: 8px; display: inline-block; font-weight: bold;">Verify Email Address</a>
    </div>
    <p style="color: #666; font-size: 14px;">Or copy and paste this link into your browser:</p>
    <p style="color: #1E88E5; font-size: 12px; word-break: break-all; background: white; padding: 10px; border-radius: 4px;">$verificationLink</p>
    <p style="color: #666; font-size: 14px;">This link will expire in 24 hours.</p>
    <p style="color: #666; font-size: 14px;">If you didn't create an account, please ignore this email.</p>
    <hr style="border: none; border-top: 1px solid #ddd; margin: 30px 0;">
    <p style="color: #999; font-size: 12px; text-align: center;">© ${DateTime.now().year} RaknaGo. All rights reserved.</p>
  </div>
</body>
</html>
        '''
        ..text =
            'Welcome, $name!\n\nVerify your email address by clicking this link: $verificationLink\n\nThis link will expire in 24 hours.\n\nIf you didn\'t create an account, please ignore this email.';

      // Send email
      await send(message, smtpServer);

      print('Verification email sent successfully via SMTP to $email');
    } catch (e) {
      print('Error sending verification email via SMTP: $e');
      // Fallback to Firebase Auth's built-in email verification
      try {
        await _auth.currentUser?.sendEmailVerification();
        print('Fallback: Using Firebase Auth email verification');
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
      }
    }
  }

  // Update email verification status in Firestore
  Future<void> updateEmailVerificationStatus(
    String userId,
    bool isVerified,
  ) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'isEmailVerified': isVerified,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw 'An error occurred: $e';
    }
  }

  // Handle Firebase Auth exceptions
  String _handleAuthException(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'The password provided is too weak.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Wrong password provided.';
      case 'invalid-email':
        return 'The email address is invalid.';
      case 'user-disabled':
        return 'This user account has been disabled.';
      case 'too-many-requests':
        return 'Too many requests. Please try again later.';
      case 'operation-not-allowed':
        return 'This operation is not allowed.';
      default:
        return e.message ?? 'An unknown error occurred.';
    }
  }
}
