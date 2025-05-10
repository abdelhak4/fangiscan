import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fungiscan/domain/models/user_profile.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Service responsible for handling authentication and user management
/// Supports offline authentication when Firebase is unavailable
class AuthenticationService {
  final _logger = Logger('AuthenticationService');

  // Firebase instances
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Local storage
  late SharedPreferences _prefs;

  // Authentication state
  bool _isOfflineMode = false;
  UserProfile? _currentUser;

  // Stream controllers
  final _userController = StreamController<UserProfile?>.broadcast();

  // Getters
  Stream<UserProfile?> get userStream => _userController.stream;
  UserProfile? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isOfflineMode => _isOfflineMode;

  // Local storage keys
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _userTypeKey = 'user_type';
  static const String _offlineModeKey = 'offline_mode';

  /// Initialize the authentication service
  Future<void> initialize() async {
    _logger.info('Initializing authentication service');

    // Initialize SharedPreferences
    _prefs = await SharedPreferences.getInstance();

    // Check if offline mode was previously enabled
    _isOfflineMode = _prefs.getBool(_offlineModeKey) ?? false;

    // Setup auth state listener
    _firebaseAuth.authStateChanges().listen(_handleAuthStateChange);

    // Check connectivity
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      _logger.info('No internet connection, entering offline mode');
      await enableOfflineMode(true);
    } else if (_isOfflineMode) {
      // User previously chose offline mode
      _logger.info('Starting in offline mode by user preference');
      _loadOfflineUser();
    } else {
      // Online mode - get current Firebase user
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        await _loadUserProfile(firebaseUser.uid);
      }
    }
  }

  /// Handle Firebase auth state changes
  Future<void> _handleAuthStateChange(User? firebaseUser) async {
    if (_isOfflineMode) return;

    if (firebaseUser != null) {
      await _loadUserProfile(firebaseUser.uid);
    } else {
      _currentUser = null;
      _userController.add(null);
    }
  }

  /// Load user profile from Firestore
  Future<void> _loadUserProfile(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (userDoc.exists) {
        _currentUser = UserProfile.fromJson({
          'id': userId,
          ...userDoc.data() ?? {},
        });
      } else {
        _currentUser = UserProfile(
          id: userId,
          email: _firebaseAuth.currentUser?.email ?? '',
          name: _firebaseAuth.currentUser?.displayName ?? 'User',
          userType: UserType.regular,
        );

        // Create user document
        await _firestore
            .collection('users')
            .doc(userId)
            .set(_currentUser!.toJson());
      }

      // Save to local storage for offline access
      _saveUserToLocal(_currentUser!);

      // Notify listeners
      _userController.add(_currentUser);
      _logger.info('User loaded: ${_currentUser?.name}');
    } catch (e) {
      _logger.severe('Error loading user profile: $e');

      // Fallback to local data if available
      _loadOfflineUser();
    }
  }

  /// Save user data to local storage
  Future<void> _saveUserToLocal(UserProfile user) async {
    await _prefs.setString(_userIdKey, user.id);
    await _prefs.setString(_userEmailKey, user.email);
    await _prefs.setString(_userNameKey, user.name);
    await _prefs.setInt(_userTypeKey, user.userType.index);
  }

  /// Load user data from local storage
  void _loadOfflineUser() {
    final userId = _prefs.getString(_userIdKey);
    final email = _prefs.getString(_userEmailKey);
    final name = _prefs.getString(_userNameKey);
    final userTypeIndex = _prefs.getInt(_userTypeKey);

    if (userId != null &&
        email != null &&
        name != null &&
        userTypeIndex != null) {
      _currentUser = UserProfile(
        id: userId,
        email: email,
        name: name,
        userType: UserType.values[userTypeIndex],
      );
      _userController.add(_currentUser);
      _logger.info('Offline user loaded: ${_currentUser?.name}');
    } else {
      _currentUser = null;
      _userController.add(null);
      _logger.info('No offline user available');
    }
  }

  /// Enable or disable offline mode
  Future<void> enableOfflineMode(bool enable) async {
    _isOfflineMode = enable;
    await _prefs.setBool(_offlineModeKey, enable);

    if (enable) {
      _loadOfflineUser();
      _logger.info('Offline mode enabled');
    } else {
      // Re-fetch online user if available
      final firebaseUser = _firebaseAuth.currentUser;
      if (firebaseUser != null) {
        await _loadUserProfile(firebaseUser.uid);
      } else {
        _currentUser = null;
        _userController.add(null);
      }
      _logger.info('Online mode enabled');
    }
  }

  /// Sign in with email and password
  Future<UserProfile?> signInWithEmail(String email, String password) async {
    if (_isOfflineMode) {
      _logger.info('Cannot sign in with email in offline mode');
      return null;
    }

    try {
      final userCredential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        await _loadUserProfile(userCredential.user!.uid);
        return _currentUser;
      }

      return null;
    } catch (e) {
      _logger.severe('Error signing in with email: $e');
      return null;
    }
  }

  /// Register with email and password
  Future<UserProfile?> registerWithEmail(
      String name, String email, String password) async {
    if (_isOfflineMode) {
      _logger.info('Cannot register with email in offline mode');
      return null;
    }

    try {
      final userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (userCredential.user != null) {
        // Update display name
        await userCredential.user!.updateDisplayName(name);

        // Create user profile
        final newUser = UserProfile(
          id: userCredential.user!.uid,
          email: email,
          name: name,
          userType: UserType.regular,
        );

        // Save to Firestore
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(newUser.toJson());

        // Save locally
        _currentUser = newUser;
        _saveUserToLocal(newUser);
        _userController.add(newUser);

        return newUser;
      }

      return null;
    } catch (e) {
      _logger.severe('Error registering with email: $e');
      return null;
    }
  }

  /// Sign in with Google account
  Future<UserProfile?> signInWithGoogle() async {
    if (_isOfflineMode) {
      _logger.info('Cannot sign in with Google in offline mode');
      return null;
    }

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential =
          await _firebaseAuth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Check if user exists in Firestore
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();

        if (!userDoc.exists) {
          // Create new user profile
          final newUser = UserProfile(
            id: userCredential.user!.uid,
            email: userCredential.user!.email ?? '',
            name: userCredential.user!.displayName ?? 'User',
            userType: UserType.regular,
            photoUrl: userCredential.user!.photoURL,
          );

          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(newUser.toJson());
        }

        await _loadUserProfile(userCredential.user!.uid);
        return _currentUser;
      }

      return null;
    } catch (e) {
      _logger.severe('Error signing in with Google: $e');
      return null;
    }
  }

  /// Sign in anonymously (for guest mode)
  Future<UserProfile?> signInAnonymously() async {
    if (_isOfflineMode) {
      // Create offline guest user
      final guestUser = UserProfile(
        id: 'guest-${DateTime.now().millisecondsSinceEpoch}',
        email: '',
        name: 'Guest User',
        userType: UserType.guest,
      );

      _currentUser = guestUser;
      _saveUserToLocal(guestUser);
      _userController.add(guestUser);

      return guestUser;
    }

    try {
      final userCredential = await _firebaseAuth.signInAnonymously();

      if (userCredential.user != null) {
        // Create guest profile
        final guestUser = UserProfile(
          id: userCredential.user!.uid,
          email: '',
          name: 'Guest User',
          userType: UserType.guest,
        );

        // Save to Firestore
        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(guestUser.toJson());

        // Save locally
        _currentUser = guestUser;
        _saveUserToLocal(guestUser);
        _userController.add(guestUser);

        return guestUser;
      }

      return null;
    } catch (e) {
      _logger.severe('Error signing in anonymously: $e');
      return null;
    }
  }

  /// Update user profile
  Future<bool> updateUserProfile({
    String? name,
    String? bio,
    String? photoUrl,
  }) async {
    if (_currentUser == null) return false;

    try {
      final updates = <String, dynamic>{};

      if (name != null) updates['name'] = name;
      if (bio != null) updates['bio'] = bio;
      if (photoUrl != null) updates['photoUrl'] = photoUrl;

      if (_isOfflineMode) {
        // Update local user only
        _currentUser = _currentUser!.copyWith(
          name: name ?? _currentUser!.name,
          bio: bio ?? _currentUser!.bio,
          photoUrl: photoUrl ?? _currentUser!.photoUrl,
        );
        _saveUserToLocal(_currentUser!);
        _userController.add(_currentUser);
        return true;
      } else {
        // Update Firestore
        await _firestore
            .collection('users')
            .doc(_currentUser!.id)
            .update(updates);

        // Update Firebase Auth display name if provided
        if (name != null && _firebaseAuth.currentUser != null) {
          await _firebaseAuth.currentUser!.updateDisplayName(name);
        }

        // Reload user profile
        await _loadUserProfile(_currentUser!.id);
        return true;
      }
    } catch (e) {
      _logger.severe('Error updating user profile: $e');
      return false;
    }
  }

  /// Sign out current user
  Future<void> signOut() async {
    _logger.info('Signing out');

    if (!_isOfflineMode) {
      await _firebaseAuth.signOut();
      await _googleSignIn.signOut();
    }

    _currentUser = null;
    _userController.add(null);

    // Clear local user data
    await _prefs.remove(_userIdKey);
    await _prefs.remove(_userEmailKey);
    await _prefs.remove(_userNameKey);
    await _prefs.remove(_userTypeKey);
  }

  /// Upgrade guest account to permanent account
  Future<bool> upgradeGuestAccount(
      String email, String password, String name) async {
    if (_isOfflineMode) {
      _logger.info('Cannot upgrade guest account in offline mode');
      return false;
    }

    if (_currentUser?.userType != UserType.guest ||
        _firebaseAuth.currentUser == null) {
      return false;
    }

    try {
      // Link anonymous account with email/password
      final credential =
          EmailAuthProvider.credential(email: email, password: password);
      await _firebaseAuth.currentUser!.linkWithCredential(credential);

      // Update user profile
      await _firebaseAuth.currentUser!.updateDisplayName(name);

      // Update in Firestore
      await _firestore.collection('users').doc(_currentUser!.id).update({
        'email': email,
        'name': name,
        'userType': UserType.regular.index,
      });

      // Reload user profile
      await _loadUserProfile(_currentUser!.id);
      return true;
    } catch (e) {
      _logger.severe('Error upgrading guest account: $e');
      return false;
    }
  }

  /// Check if email is available
  Future<bool> isEmailAvailable(String email) async {
    if (_isOfflineMode) return true;

    try {
      final methods = await _firebaseAuth.fetchSignInMethodsForEmail(email);
      return methods.isEmpty;
    } catch (e) {
      _logger.warning('Error checking email availability: $e');
      return false;
    }
  }

  /// Send password reset email
  Future<bool> sendPasswordResetEmail(String email) async {
    if (_isOfflineMode) {
      _logger.info('Cannot send password reset email in offline mode');
      return false;
    }

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email);
      return true;
    } catch (e) {
      _logger.severe('Error sending password reset email: $e');
      return false;
    }
  }

  /// Get user badges and achievements
  Future<List<String>> getUserBadges(String userId) async {
    try {
      if (_isOfflineMode) {
        return [];
      }

      final userDoc = await _firestore.collection('users').doc(userId).get();
      final badges = userDoc.data()?['badges'] as List? ?? [];
      return badges.cast<String>();
    } catch (e) {
      _logger.warning('Error getting user badges: $e');
      return [];
    }
  }

  /// Award a badge to the user
  Future<bool> awardBadge(String badgeId, {String? userId}) async {
    if (_currentUser == null && userId == null) return false;

    final targetUserId = userId ?? _currentUser!.id;

    try {
      if (_isOfflineMode) {
        _logger.info('Cannot award badges in offline mode');
        return false;
      }

      await _firestore.collection('users').doc(targetUserId).update({
        'badges': FieldValue.arrayUnion([badgeId]),
      });

      return true;
    } catch (e) {
      _logger.severe('Error awarding badge: $e');
      return false;
    }
  }

  /// Clean up resources
  void dispose() {
    _userController.close();
  }
}
