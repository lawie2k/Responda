import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/account_profile.dart';

abstract interface class AccountStore {
  Future<AccountProfile?> read();

  Future<void> write(AccountProfile profile);

  Future<void> clear();
}

class SharedPreferencesAccountStore implements AccountStore {
  SharedPreferencesAccountStore({SharedPreferencesAsync? client})
    : _preferences = client;

  static const _accountKey = 'responda_account_profile_v1';

  final SharedPreferencesAsync? _preferences;

  SharedPreferencesAsync get _client =>
      _preferences ?? SharedPreferencesAsync();

  @override
  Future<AccountProfile?> read() async {
    final encoded = await _client.getString(_accountKey);
    if (encoded == null || encoded.isEmpty) {
      return null;
    }
    try {
      return AccountProfile.fromJson(
        Map<String, Object?>.from(jsonDecode(encoded) as Map),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(AccountProfile profile) {
    return _client.setString(_accountKey, jsonEncode(profile.toJson()));
  }

  @override
  Future<void> clear() => _client.remove(_accountKey);
}

class AccountController extends ChangeNotifier {
  AccountController({AccountStore? store})
    : _store = store ?? SharedPreferencesAccountStore();

  final AccountStore _store;

  AccountProfile? _profile;
  bool _isLoaded = false;

  AccountProfile? get profile => _profile;
  bool get hasAccount => _profile != null;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) {
      return;
    }
    try {
      _profile = await _store.read();
    } catch (_) {
      _profile = null;
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<void> submitIdentity({required String phoneNumber}) async {
    final profile = AccountProfile(
      phoneNumber: phoneNumber,
      status: AccountVerificationStatus.pending,
      submittedAt: DateTime.now(),
      idSubmitted: true,
      faceCaptured: true,
    );
    _profile = profile;
    _isLoaded = true;
    notifyListeners();
    await _store.write(profile);
  }

  Future<void> clearLocalSession() async {
    _profile = null;
    _isLoaded = true;
    notifyListeners();
    await _store.clear();
  }
}
