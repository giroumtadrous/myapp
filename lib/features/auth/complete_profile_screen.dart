import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
  final _institutionController = TextEditingController();
  final _authService = AuthService();
  final _userService = UserService();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _prefillFromCurrentUser();
  }

  void _prefillFromCurrentUser() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final displayName = (user.displayName ?? '').trim();
    if (displayName.isNotEmpty) {
      _usernameController.text = displayName.replaceAll(RegExp(r'\s+'), '').toLowerCase();
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _institutionController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    final username = (value ?? '').trim();
    if (username.isEmpty) return 'Username is required';
    if (username.length < 3) return 'Username must be at least 3 characters';
    if (username.contains(' ')) return 'Username cannot contain spaces';
    return null;
  }

  String? _validateInstitution(String? value) {
    final institution = (value ?? '').trim();
    if (institution.isEmpty) return 'Institution is required';
    return null;
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final existingDoc = await userRef.get();
      final provider = _authService.detectSocialProvider(user);

      final payload = <String, dynamic>{
        'uid': user.uid,
        'username': _usernameController.text.trim(),
        'name': _usernameController.text.trim(),
        'institution': _institutionController.text.trim(),
        'universityOrHighSchool': _institutionController.text.trim(),
        'email': user.email,
        'displayName': user.displayName,
        'photoUrl': user.photoURL,
        'role': 'student',
        'authProvider': provider,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!existingDoc.exists) {
        payload['createdAt'] = FieldValue.serverTimestamp();
      }

      await userRef.set(payload, SetOptions(merge: true));
      await _userService.syncFcmToken(user.uid);

      if (!mounted) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to save profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Complete Your Profile')),
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
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
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
                    TextFormField(
                      controller: _institutionController,
                      validator: _validateInstitution,
                      decoration: const InputDecoration(
                        labelText: 'Institution',
                        hintText: 'University or School',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
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
                                child: CircularProgressIndicator(strokeWidth: 2),
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
    );
  }
}
