// lib/services/auth_service.dart
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:async';

class AuthService extends ChangeNotifier {
  static const _kUserKey = 'logged_user';
  static const _kDisplayNameKeyPrefix = 'display_name_';
  static const _kPhotoUrlKeyPrefix = 'photo_url_';

  String? _username;
  String? _displayName;
  String? _photoUrl;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profileSub;
  bool get isLoggedIn => _username != null;
  String? get username => _username;
  String? get displayName => _displayName ?? _friendlyDisplayName(_username);
  String? get photoUrl => _photoUrl;

  // Hard-coded users (only David and Luisa allowed)
  static const Map<String, String> _allowed = {
    'david1720': '1006198954',
    'maria1720': '1192738184',
  };

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _username = prefs.getString(_kUserKey);
    if (_username != null) {
      _displayName = prefs.getString('$_kDisplayNameKeyPrefix$_username');
      _photoUrl = prefs.getString('$_kPhotoUrlKeyPrefix$_username');
    } else {
      _displayName = null;
      _photoUrl = null;
    }
    notifyListeners();
  }

  /// Login "local" de tu app (username + password). Además de guardar en prefs,
  /// aquí garantizamos que exista un documento /users/{username} y /profiles/{username}
  /// con ownerUid = FirebaseAuth.currentUser?.uid para que otros clientes puedan
  /// resolver username -> uid y ser incluidos como colaboradores.
  Future<bool> login(String user, String password) async {
    final key = user.trim().toLowerCase();
    final expected = _allowed[key];
    final pass = password.trim();
    bool ok = expected != null && expected == pass;
    if (ok) {
      _username = key;
      // If we don't already have a display name saved for this user,
      // set a friendly default. Photo URL is also loaded per-user.
      final prefs = await SharedPreferences.getInstance();
      final displayKey = '$_kDisplayNameKeyPrefix$key';
      final photoKey = '$_kPhotoUrlKeyPrefix$key';
      final existingName = prefs.getString(displayKey);
      if (existingName == null || existingName.trim().isEmpty) {
        _displayName = _friendlyDisplayName(key);
        await prefs.setString(displayKey, _displayName!);
      } else {
        _displayName = existingName;
      }
      // Load stored photoUrl for this user (do not overwrite it on login)
      _photoUrl = prefs.getString(photoKey);
      await prefs.setString(_kUserKey, key);

      // Guardar/actualizar en Firestore un mapping username -> ownerUid para que
      // _defaultCollaborators lo pueda resolver más tarde (y así david/maria se incluyan).
      // Esto funciona con auth anónima porque request.auth.uid == ownerUid en el cliente.
      try {
        final ownerUid = FirebaseAuth.instance.currentUser?.uid;
        if (ownerUid != null && ownerUid.isNotEmpty) {
          final now = FieldValue.serverTimestamp();
          final docData = <String, dynamic>{
            'ownerUid': ownerUid,
            if (_displayName != null) 'displayName': _displayName,
            if (_photoUrl != null) 'photoUrl': _photoUrl,
            'updatedAt': now,
          };
          // write to both collections used by OrdersService._resolveUidFromUsername
          await FirebaseFirestore.instance
              .collection('users')
              .doc(key)
              .set(docData, SetOptions(merge: true));
          await FirebaseFirestore.instance
              .collection('profiles')
              .doc(key)
              .set(docData, SetOptions(merge: true));
          debugPrint(
              'AuthService.login: wrote profile/users doc for $key -> $ownerUid');
        } else {
          debugPrint(
              'AuthService.login: no firebase user uid available to write profile doc');
        }
      } catch (e) {
        debugPrint('AuthService: failed writing initial profile/users doc: $e');
      }

      // Try to sync profile from Firestore so the profile is available on other devices.
      try {
        await _syncProfileFromFirestore(key);
      } catch (e) {
        debugPrint('AuthService: error syncing profile from Firestore: $e');
      }
      // Subscribe to realtime updates for this user's profile so changes made
      // on other devices are received immediately.
      _profileSub?.cancel();
      _profileSub = FirebaseFirestore.instance
          .collection('profiles')
          .doc(key)
          .snapshots()
          .listen((snap) async {
        if (!snap.exists) return;
        final data = snap.data();
        if (data == null) return;
        final prefs = await SharedPreferences.getInstance();
        if (data['displayName'] != null) {
          _displayName = data['displayName'] as String;
          await prefs.setString('$_kDisplayNameKeyPrefix$key', _displayName!);
        }
        if (data['photoUrl'] != null) {
          _photoUrl = data['photoUrl'] as String;
          await prefs.setString('$_kPhotoUrlKeyPrefix$key', _photoUrl!);
        }
        notifyListeners();
      }, onError: (e) => debugPrint('profile snapshot error: $e'));
      notifyListeners();
      debugPrint('AuthService: login success for $key');
      return true;
    }
    debugPrint('AuthService: login failed for $key');
    return false;
  }

  Future<void> logout() async {
    _username = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserKey);
    // Keep per-user displayName/photoUrl in prefs so they persist across
    // logouts. Clear in-memory values so UI shows login state.
    _displayName = null;
    _photoUrl = null;
    // Cancel profile subscription
    await _profileSub?.cancel();
    _profileSub = null;
    notifyListeners();
  }

  Future<void> setDisplayName(String name) async {
    _displayName = name;
    final prefs = await SharedPreferences.getInstance();
    if (_username != null) {
      await prefs.setString('$_kDisplayNameKeyPrefix$_username', name);
      try {
        final ownerUid = FirebaseAuth.instance.currentUser?.uid ??
            FirebaseFirestore.instance.app.options.projectId;
        // Save display name with metadata and ownerUid when possible
        await _saveProfileToFirestore(_username!, {
          'displayName': name,
          'updatedAt': FieldValue.serverTimestamp(),
          'ownerUid': ownerUid,
        });
        // Also save to profiles collection for compatibility
        await _saveProfileToProfilesCollection(_username!, {
          'displayName': name,
          'updatedAt': FieldValue.serverTimestamp(),
          'ownerUid': ownerUid,
        });
      } catch (e) {
        debugPrint('AuthService: failed saving displayName to Firestore: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setPhotoUrl(String? url) async {
    _photoUrl = url;
    final prefs = await SharedPreferences.getInstance();
    if (_username != null) {
      final key = '$_kPhotoUrlKeyPrefix$_username';
      if (url == null) {
        await prefs.remove(key);
      } else {
        await prefs.setString(key, url);
      }
      try {
        final ownerUid = FirebaseAuth.instance.currentUser?.uid ??
            FirebaseFirestore.instance.app.options.projectId;
        await _saveProfileToFirestore(_username!, {
          'photoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
          'ownerUid': ownerUid,
        });
        await _saveProfileToProfilesCollection(_username!, {
          'photoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
          'ownerUid': ownerUid,
        });
      } catch (e) {
        debugPrint('AuthService: failed saving photoUrl to Firestore: $e');
      }
    }
    notifyListeners();
  }

  Future<void> setFcmToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    if (_username != null) {
      final key = 'fcm_token_$_username';
      await prefs.setString(key, token);
      try {
        await _saveProfileToFirestore(_username!, {'fcmToken': token});
        await _saveProfileToProfilesCollection(_username!, {'fcmToken': token});
      } catch (e) {
        debugPrint('AuthService: failed saving fcmToken to Firestore: $e');
      }
    }
  }

  Future<void> _syncProfileFromFirestore(String username) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Fetch both 'users' and 'profiles' documents and merge fields.
      final docUsers = await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .get();
      final docProfiles = await FirebaseFirestore.instance
          .collection('profiles')
          .doc(username)
          .get();

      final Map<String, dynamic> merged = {};
      if (docUsers.exists && docUsers.data() != null) {
        merged.addAll(docUsers.data()!);
      }
      if (docProfiles.exists && docProfiles.data() != null) {
        // Only fill missing keys from profiles
        docProfiles.data()!.forEach((k, v) {
          if (!merged.containsKey(k) || merged[k] == null) merged[k] = v;
        });
      }

      if (merged.isEmpty) return;
      if (merged['displayName'] != null) {
        _displayName = merged['displayName'] as String;
        await prefs.setString(
            '$_kDisplayNameKeyPrefix$username', _displayName!);
      }
      if (merged['photoUrl'] != null) {
        _photoUrl = merged['photoUrl'] as String;
        await prefs.setString('$_kPhotoUrlKeyPrefix$username', _photoUrl!);
      }
    } catch (e) {
      debugPrint('AuthService._syncProfileFromFirestore error: $e');
    }
  }

  Future<void> _saveProfileToFirestore(
      String username, Map<String, dynamic> updates) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(username)
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('AuthService._saveProfileToFirestore error: $e');
      rethrow;
    }
  }

  Future<void> _saveProfileToProfilesCollection(
      String username, Map<String, dynamic> updates) async {
    try {
      await FirebaseFirestore.instance
          .collection('profiles')
          .doc(username)
          .set(updates, SetOptions(merge: true));
    } catch (e) {
      debugPrint('AuthService._saveProfileToFirestore error: $e');
      rethrow;
    }
  }

  // Friendly display names used by the app UI.
  static String? _friendlyDisplayName(String? key) {
    if (key == null) return null;
    switch (key) {
      case 'david1720':
        return 'Esteban';
      case 'maria1720':
        return 'Luisa';
      default:
        return key;
    }
  }
}
