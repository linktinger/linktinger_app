import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:linktinger_app/widgets/settings/editable_profile_field.dart';
import 'package:linktinger_app/widgets/settings/profile_image_picker.dart';
import 'package:linktinger_app/services/upload_service.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _bioController = TextEditingController();
  final _specialtyController = TextEditingController(); // إضافة حقل التخصص

  String profileImage = '';
  int userId = 0;
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  Future<void> loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      userId = prefs.getInt('user_id') ?? 0;
      _fullNameController.text = prefs.getString('screenName') ?? '';
      _usernameController.text = prefs.getString('username') ?? '';
      _emailController.text = prefs.getString('email') ?? '';
      _phoneController.text = prefs.getString('phone') ?? '';
      _bioController.text = prefs.getString('bio') ?? '';
      _specialtyController.text =
          prefs.getString('specialty') ?? ''; // تحميل التخصص
      profileImage = prefs.getString('profileImage') ?? '';
    });
  }

  Future<void> saveChanges() async {
    setState(() => isSaving = true);

    final url = Uri.parse(
      'https://linktinger.xyz/linktinger-api/update_profile.php',
    );
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'screenName': _fullNameController.text.trim(),
        'username': _usernameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio': _bioController.text.trim(),
        'specialty': _specialtyController.text
            .trim(), // إرسال التخصص مع البيانات
      }),
    );

    final result = jsonDecode(response.body);
    if (result['status'] == 'success') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('screenName', _fullNameController.text.trim());
      await prefs.setString('username', _usernameController.text.trim());
      await prefs.setString('email', _emailController.text.trim());
      await prefs.setString('phone', _phoneController.text.trim());
      await prefs.setString('bio', _bioController.text.trim());
      await prefs.setString(
        'specialty',
        _specialtyController.text.trim(),
      ); // حفظ التخصص

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Changes saved successfully')),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: ${result['message']}')));
    }

    setState(() => isSaving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Account'),
        backgroundColor: Colors.white,
        elevation: 1,
        foregroundColor: Colors.black87,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            ProfileImagePicker(
              imageUrl: profileImage,
              onImageSelected: (File imageFile) async {
                final uploadedUrl = await UploadService.uploadUserImage(
                  imageFile: imageFile,
                  userId: userId,
                  type: 'profile',
                );

                if (uploadedUrl != null) {
                  setState(() => profileImage = uploadedUrl);
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.setString('profileImage', uploadedUrl);
                }

                return uploadedUrl ?? profileImage;
              },
            ),
            const SizedBox(height: 24),
            EditableProfileField(
              label: 'Full Name',
              controller: _fullNameController,
              prefixIcon: Icons.person,
            ),
            EditableProfileField(
              label: 'Username',
              controller: _usernameController,
              prefixIcon: Icons.alternate_email,
            ),
            EditableProfileField(
              label: 'Email',
              controller: _emailController,
              prefixIcon: Icons.email,
            ),
            EditableProfileField(
              label: 'Phone Number',
              controller: _phoneController,
              prefixIcon: Icons.phone,
            ),
            EditableProfileField(
              label: 'Bio',
              controller: _bioController,
              maxLines: 3,
              prefixIcon: Icons.info_outline,
            ),
            EditableProfileField(
              label: 'Specialty', // حقل التخصص الجديد
              controller: _specialtyController,
              prefixIcon: Icons.work_outline,
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: isSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Save Changes'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: isSaving ? null : saveChanges,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
