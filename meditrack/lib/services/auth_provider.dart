import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:meditrack/models/models.dart';
import 'package:meditrack/services/api_service.dart';

class AuthProvider extends ChangeNotifier {
  AppUser? _user;
  bool _isLoading = false;
  String? _error;
  Map<String, String> _fieldErrors = {};

  AppUser? get user => _user;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _user != null;
  String? get error => _error;
  /// Per-field validation errors from the last failed register call.
  /// Key is the lowercased field name (e.g. 'phone', 'email').
  Map<String, String> get fieldErrors => _fieldErrors;
  UserRole get role => _user != null ? userRoleFromString(_user!.role) : UserRole.patient;

  static const _roleUri = 'http://schemas.microsoft.com/ws/2008/06/identity/claims/role';

  String _decodeRole(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return 'Patient';
      final payload = jsonDecode(utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))));
      dynamic val = payload[_roleUri] ?? payload['role'];
      if (val == null) {
        final roleKey = (payload as Map).keys.firstWhere((k) => k.toLowerCase().contains('role'), orElse: () => '');
        if (roleKey.isNotEmpty) val = payload[roleKey];
      }
      if (val == null) return 'Patient';
      return val is List ? val[0].toString() : val.toString();
    } catch (_) { return 'Patient'; }
  }

  AppUser _buildUser(AuthResponse r) {
    final role = _decodeRole(r.token);
    return AppUser(
      id: r.id,
      name: r.fullName.isNotEmpty ? r.fullName : r.email,
      email: r.email,
      role: role,
      token: r.token,
      refreshToken: r.refreshToken,
      profilePictureUrl: r.profilePictureUrl,
    );
  }

  Future<bool> login(String email, String password) async {
    _isLoading = true; _error = null; _fieldErrors = {}; notifyListeners();
    final res = await apiService.login(email, password);
    _isLoading = false;
    if (res.ok && res.data != null) {
      _user = _buildUser(res.data!);
      apiService.setToken(_user!.token);
      await _persist(); notifyListeners(); return true;
    } else {
      // Always show a friendly message for login — never expose raw server errors
      _error = 'Wrong email or password.';
      notifyListeners(); return false;
    }
  }

  Future<bool> register(UserRole role, Map<String, dynamic> body) async {
    _isLoading = true; _error = null; _fieldErrors = {}; notifyListeners();
    ApiResult<AuthResponse> res;
    switch (role) {
      case UserRole.patient:   res = await apiService.registerPatient(body); break;
      case UserRole.doctor:    res = await apiService.registerDoctor(body); break;
      case UserRole.lab:       res = await apiService.registerLab(body); break;
      case UserRole.relative:  res = await apiService.registerRelative(body); break;
      case UserRole.ambulance: res = await apiService.registerAmbulance(body); break;
      default: _error = 'Unknown role.'; _isLoading = false; notifyListeners(); return false;
    }
    _isLoading = false;
    if (res.ok && res.data != null) {
      _user = _buildUser(res.data!);
      apiService.setToken(_user!.token);
      await _persist(); notifyListeners(); return true;
    } else {
      _fieldErrors = res.fieldErrors;
      // Only show the top-level banner if there are no field-level errors to show inline
      if (_fieldErrors.isEmpty) {
        _error = res.error ?? 'Registration failed.';
      }
      notifyListeners(); return false;
    }
  }

  Future<void> _persist() async {
    if (_user == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('mt_token',   _user!.token);
      await prefs.setString('mt_refresh', _user!.refreshToken);
      await prefs.setString('mt_id',      _user!.id);
      await prefs.setString('mt_name',    _user!.name);
      await prefs.setString('mt_email',   _user!.email);
      await prefs.setString('mt_role',    _user!.role);
      if (_user!.profilePictureUrl != null) {
        await prefs.setString('mt_pic', _user!.profilePictureUrl!);
      } else {
        await prefs.remove('mt_pic');
      }
    } catch (_) {}
  }

  Future<bool> tryRestoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('mt_token');
      if (token == null) return false;
      apiService.setToken(token);
      final check = await apiService.getDoctors();
      if (!check.ok && check.statusCode == 401) {
        final refresh = prefs.getString('mt_refresh');
        if (refresh != null) {
          final refreshRes = await apiService.refreshToken(refresh);
          if (refreshRes.ok && refreshRes.data != null) {
            _user = _buildUser(refreshRes.data!);
            apiService.setToken(_user!.token);
            await _persist(); notifyListeners(); return true;
          }
        }
        await _clearPersisted(prefs); return false;
      }
      _user = AppUser(
        id: prefs.getString('mt_id') ?? '', name: prefs.getString('mt_name') ?? '',
        email: prefs.getString('mt_email') ?? '', role: prefs.getString('mt_role') ?? 'Patient',
        token: token, refreshToken: prefs.getString('mt_refresh') ?? '',
        profilePictureUrl: prefs.getString('mt_pic'),
      );
      notifyListeners(); return true;
    } catch (_) { return false; }
  }

  /// Updates the in-memory user name and persists it after a successful API call.
  Future<void> refreshName(String newName) async {
    if (_user == null) return;
    _user = AppUser(
      id: _user!.id, name: newName, email: _user!.email,
      role: _user!.role, token: _user!.token, refreshToken: _user!.refreshToken,
      profilePictureUrl: _user!.profilePictureUrl,
    );
    await _persist();
    notifyListeners();
  }

  /// Updates the in-memory profile picture URL and persists it.
  /// Pass null to remove the picture.
  Future<void> refreshProfilePic(String? url) async {
    if (_user == null) return;
    _user = AppUser(
      id: _user!.id, name: _user!.name, email: _user!.email,
      role: _user!.role, token: _user!.token, refreshToken: _user!.refreshToken,
      profilePictureUrl: (url == null || url.isEmpty) ? null : url,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> logout() async {
    _user = null; apiService.setToken(null); _error = null;
    try { final prefs = await SharedPreferences.getInstance(); await _clearPersisted(prefs); } catch (_) {}
    notifyListeners();
  }

  Future<void> _clearPersisted(SharedPreferences prefs) async {
    await prefs.remove('mt_token'); await prefs.remove('mt_refresh');
    await prefs.remove('mt_id'); await prefs.remove('mt_name');
    await prefs.remove('mt_email'); await prefs.remove('mt_role');
    await prefs.remove('mt_pic');
  }

  void clearError() { _error = null; _fieldErrors = {}; notifyListeners(); }
}
