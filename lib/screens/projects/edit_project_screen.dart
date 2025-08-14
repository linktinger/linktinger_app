import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/project.dart';
import '../../services/project_service.dart';

class EditProjectScreen extends StatefulWidget {
  final Project project;

  const EditProjectScreen({super.key, required this.project});

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late TextEditingController _skillsController;

  File? _newImageFile;
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.project.title);
    _descriptionController = TextEditingController(
      text: widget.project.description,
    );
    _skillsController = TextEditingController(
      text: widget.project.skills.join(', '),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _skillsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _newImageFile = File(picked.path);
      });
    }
  }

  Future<void> _updateProject() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    final updatedProject = widget.project.copyWith(
      title: _titleController.text.trim(),
      description: _descriptionController.text.trim(),
      skills: _skillsController.text
          .trim()
          .split(',')
          .map((e) => e.trim())
          .toList(),
    );

    final result = await ProjectService.updateProject(
      projectId: int.parse(widget.project.id),
      title: updatedProject.title,
      description: updatedProject.description,
      skills: updatedProject.skills.join(','),
      newImageFile: _newImageFile,
    );

    setState(() => isSubmitting = false);

    if (result['status'] == 'success') {
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('An error occurred while updating the project'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Text(
          'Edit Project',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField('Project Title', _titleController),
              const SizedBox(height: 16),
              _buildTextField(
                'Description',
                _descriptionController,
                maxLines: 4,
              ),
              const SizedBox(height: 16),
              _buildTextField('Skills (comma separated)', _skillsController),
              const SizedBox(height: 16),
              const Text(
                'Cover Image',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 180,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                    image: DecorationImage(
                      image: _newImageFile != null
                          ? FileImage(_newImageFile!)
                          : NetworkImage(widget.project.coverImage)
                                as ImageProvider,
                      fit: BoxFit.cover,
                    ),
                  ),
                  child: _newImageFile == null
                      ? const Center(
                          child: Icon(
                            Icons.camera_alt,
                            color: Colors.white70,
                            size: 40,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF142B63),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: isSubmitting ? null : _updateProject,
                child: isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Save Changes',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1E293B),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      ),
      validator: (value) =>
          value == null || value.isEmpty ? 'This field is required' : null,
    );
  }
}
