import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/firebase_service.dart';
import 'crop_photo_screen.dart';

class ProfileScreen extends StatefulWidget {
  final bool popOnSave;

  const ProfileScreen({super.key, this.popOnSave = true});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _profileService = ProfileService();
  final _nameController = TextEditingController();
  bool _isSaving = false;
  Uint8List? _photoBytes;
  String? _photoName;
  String? _localPhotoPath;

  User? get _user => FirebaseAuth.instance.currentUser;

  @override
  void initState() {
    super.initState();
    _nameController.text = _user?.displayName ?? '';
    _loadLocalPhotoPath();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadLocalPhotoPath() async {
    final user = _user;
    if (user == null) return;
    final path = await _LocalProfilePhotoStorage.loadPhotoPath(uid: user.uid);
    if (!mounted) return;
    setState(() => _localPhotoPath = path);
  }

  Future<void> _pickPhoto() async {
    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1200,
      );

      if (file == null) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      final cropped = await Navigator.of(context).push<Uint8List?>(
        MaterialPageRoute(
          builder: (_) => CropPhotoScreen(imageBytes: bytes),
        ),
      );

      if (cropped == null) return;

      if (!mounted) return;
      setState(() {
        _photoBytes = cropped;
        _photoName = 'profile_${DateTime.now().millisecondsSinceEpoch}.png';
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal memilih foto: $e')),
      );
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = _user;
    if (user == null) return;

    setState(() => _isSaving = true);

    final name = _nameController.text.trim();
    try {
      if (_photoBytes != null && _photoName != null && user.uid.isNotEmpty) {
        _localPhotoPath = await _LocalProfilePhotoStorage.savePhoto(
          uid: user.uid,
          fileName: _photoName!,
          bytes: _photoBytes!,
        );
      }

      await _profileService.updateProfile(
        user: user,
        name: name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profil berhasil disimpan')));
      if (widget.popOnSave) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan profil: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final colors = Theme.of(context).colorScheme;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('Belum login')));
    }

    final email = user.email ?? '-';
    final photoUrl = user.photoURL;

    return Scaffold(
      appBar: AppBar(title: const Text('Profil Pengguna')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        gradient: LinearGradient(
                          colors: [colors.primary, colors.tertiary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Stack(
                                alignment: Alignment.bottomRight,
                                children: [
                                  CircleAvatar(
                                    radius: 46,
                                    backgroundColor: colors.onPrimary.withValues(
                                      alpha: 0.18,
                                    ),
                                    foregroundColor: colors.onPrimary,
                                    backgroundImage: _photoBytes != null
                                        ? MemoryImage(_photoBytes!)
                                        : (_localPhotoPath != null
                                            ? FileImage(File(_localPhotoPath!))
                                            : (photoUrl != null &&
                                                    photoUrl.isNotEmpty
                                                ? NetworkImage(photoUrl)
                                                : null)) as ImageProvider<Object>?,
                                    child: (_photoBytes == null &&
                                            (photoUrl == null ||
                                                photoUrl.isEmpty))
                                        ? Text(
                                            email.characters.first.toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 32,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          )
                                        : null,
                                  ),
                                  IconButton.filledTonal(
                                    tooltip: 'Ganti foto',
                                    onPressed: _pickPhoto,
                                    icon: const Icon(Icons.camera_alt_outlined),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 18),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName?.trim().isNotEmpty == true
                                          ? user.displayName!
                                          : 'Pengguna MoneyFlow',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: colors.onPrimary,
                                            fontWeight: FontWeight.w900,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      email,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: colors.onPrimary.withValues(
                                          alpha: 0.82,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'Informasi Akun',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _nameController,
                              textInputAction: TextInputAction.done,
                              decoration: const InputDecoration(
                                labelText: 'Nama',
                                prefixIcon: Icon(Icons.person_outline),
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Nama wajib diisi';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              child: Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_photoName != null) ...[
                              const SizedBox(height: 14),
                              _ProfileInfoRow(
                                icon: Icons.image_outlined,
                                label: 'Foto baru',
                                value: _photoName!,
                              ),
                            ],
                            const SizedBox(height: 24),
                            FilledButton.icon(
                              onPressed: _isSaving ? null : _saveProfile,
                              icon: _isSaving
                                  ? const SizedBox.square(
                                      dimension: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.save_outlined),
                              label: const Text('Simpan Profil'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                textStyle: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
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

class _LocalProfilePhotoStorage {
  static const _photoKey = 'local_profile_photo_path';

  static Future<String?> loadPhotoPath({required String uid}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_photoKey:$uid');
  }

  static Future<String> savePhoto({
    required String uid,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final userDir = Directory('${directory.path}/profile_photos/$uid');
    if (!await userDir.exists()) {
      await userDir.create(recursive: true);
    }

    final file = File('${userDir.path}/$fileName');
    await file.writeAsBytes(bytes);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_photoKey:$uid', file.path);
    return file.path;
  }
}

class _ProfileInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(icon, color: colors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: colors.onSurfaceVariant)),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
