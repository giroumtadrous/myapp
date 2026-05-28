import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/egyptian_universities.dart';
import '../../services/auth_service.dart';
import '../../services/user_service.dart';
import '../../widgets/pressable_scale.dart';

class CompleteProfileScreen extends StatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _authService = AuthService();
  final _userService = UserService();
  String? _selectedInstitution;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillFromCurrentUser();
  }

  Future<void> _prefillFromCurrentUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      _usernameController.text = displayName
          .replaceAll(RegExp(r'\s+'), '')
          .toLowerCase();
    }

    try {
      final appUser = await _userService.getUser(user.uid);
      if (!mounted || appUser == null) return;

      final institution = appUser.universityOrHighSchool.trim().isNotEmpty
          ? appUser.universityOrHighSchool.trim()
          : appUser.institution.trim();
      if (egyptianUniversities.contains(institution)) {
        setState(() => _selectedInstitution = institution);
      }
    } catch (_) {
      // Keep default empty selection if prefill fails.
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final username = (value ?? '').trim();
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.contains(' ')) return 'Username cannot contain spaces';
    if (!RegExp(r'^[a-zA-Z0-9._]+$').hasMatch(username)) {
      return 'Username can only use letters, numbers, dot, and underscore';
    }
    return null;
  }

  String? _validateInstitution(String? value) {
    final institution = (value ?? '').trim();
    if (institution.isEmpty) return 'Please select your university';
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please sign in again.')));
      return;
    }

    setState(() => _saving = true);
    try {
      final provider = _authService.detectSocialProvider(user);
      final normalizedUsername = _authService.normalizeUsername(
        _usernameController.text,
      );

      final usernameAvailable = await _authService.isUsernameAvailable(
        normalizedUsername,
        excludeUid: user.uid,
      );
      if (!usernameAvailable) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('That username is already taken.')),
        );
        return;
      }

      await _authService.saveUserProfileWithUsernameClaim(
        uid: user.uid,
        username: normalizedUsername,
        name: user.displayName ?? normalizedUsername,
        institution: _selectedInstitution!.trim(),
        email: user.email ?? '',
        role: 'student',
        authProvider: provider,
        displayName: user.displayName,
        photoUrl: user.photoURL,
      );
      await _userService.syncFcmToken(user.uid);

      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save profile: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return WillPopScope(
      onWillPop: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
          return Future.value(true);
        }
        return FirebaseAuth.instance.signOut().then((_) => false);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Complete Your Profile'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                FirebaseAuth.instance.signOut();
              }
            },
            tooltip: 'Back',
          ),
        ),
        body: SafeArea(
          child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Complete Your Profile',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Just a few more details to get started',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 22),
                    TextFormField(
                      controller: _usernameController,
                      validator: _validateUsername,
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        hintText: 'username123',
                        prefixIcon: Icon(Icons.alternate_email),
                      ),
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedInstitution,
                      validator: _validateInstitution,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'University',
                        hintText: 'Select your university',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: egyptianUniversities
                          .map(
                            (university) => DropdownMenuItem<String>(
                              value: university,
                              child: Text(university),
                            ),
                          )
                          .toList(),
                      onChanged: _saving
                          ? null
                          : (value) =>
                                setState(() => _selectedInstitution = value),
                    ),
                    const SizedBox(height: 10),
                    if ((user?.email ?? '').isNotEmpty)
                      Text(
                        'Signed in as ${user!.email}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: const Color(0xFF64748B),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    const SizedBox(height: 20),
                    PressableScale(
                      child: ElevatedButton(
                        onPressed: _saving ? null : _saveProfile,
                        child: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Continue'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
