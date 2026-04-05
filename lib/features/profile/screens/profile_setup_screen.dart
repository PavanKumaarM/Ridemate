import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/user_model.dart';

class ProfileSetupScreen extends StatefulWidget {
  final bool isEditing;
  final UserModel? existingUser;

  const ProfileSetupScreen({
    super.key,
    this.isEditing = false,
    this.existingUser,
  });

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();

  File? _profileImage;
  File? _identityDocument;
  String? _identityDocumentType;
  String? _existingProfilePhotoUrl;
  String? _existingIdentityDocUrl;

  bool _isLoading = false;
  bool _isUploadingProfile = false;
  bool _isUploadingDocument = false;

  final List<String> _documentTypes = [
    'Aadhaar Card',
    'PAN Card',
    'Driving License',
    'Passport',
    'Voter ID',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.isEditing && widget.existingUser != null) {
      _nameController.text = widget.existingUser!.name;
      _phoneController.text = widget.existingUser!.phone;
      _emailController.text = widget.existingUser!.email ?? '';
      _addressController.text = widget.existingUser!.address ?? '';
      _existingProfilePhotoUrl = widget.existingUser!.profilePhotoUrl;
      _existingIdentityDocUrl = widget.existingUser!.identityDocumentUrl;
      _identityDocumentType = widget.existingUser!.identityDocumentType;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _profileImage = File(picked.path));
    }
  }

  Future<void> _pickIdentityDocument() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200,
      maxHeight: 1200,
      imageQuality: 90,
    );
    if (picked != null) {
      setState(() => _identityDocument = File(picked.path));
    }
  }

  Future<String?> _uploadFile(File file, String bucket, String path) async {
    try {
      await Supabase.instance.client.storage
          .from(bucket)
          .upload(path, file);
      
      return Supabase.instance.client.storage
          .from(bucket)
          .getPublicUrl(path);
    } catch (e) {
      debugPrint('Upload error: $e');
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_identityDocumentType == null && _existingIdentityDocUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select identity document type')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('User not logged in');

      String? profilePhotoUrl = _existingProfilePhotoUrl;
      String? identityDocUrl = _existingIdentityDocUrl;

      // Upload profile photo if selected
      if (_profileImage != null) {
        setState(() => _isUploadingProfile = true);
        final ext = _profileImage!.path.split('.').last;
        final path = 'profile_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        profilePhotoUrl = await _uploadFile(_profileImage!, 'profile-photos', path);
        setState(() => _isUploadingProfile = false);
      }

      // Upload identity document if selected
      if (_identityDocument != null) {
        setState(() => _isUploadingDocument = true);
        final ext = _identityDocument!.path.split('.').last;
        final path = 'identity_${user.id}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        identityDocUrl = await _uploadFile(_identityDocument!, 'identity-documents', path);
        setState(() => _isUploadingDocument = false);
      }

      final userData = {
        'id': user.id,
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim(),
        'profile_photo_url': profilePhotoUrl,
        'identity_document_url': identityDocUrl,
        'identity_document_type': _identityDocumentType,
        'is_profile_complete': true,
        'rating': 0.0,
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Upsert to users table
      await Supabase.instance.client
          .from('users')
          .upsert(userData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved successfully!')),
        );
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildImagePicker({
    required String label,
    required File? selectedFile,
    required String? existingUrl,
    required VoidCallback onTap,
    required bool isUploading,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 150,
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: isUploading
            ? const Center(child: CircularProgressIndicator())
            : selectedFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(selectedFile, fit: BoxFit.cover, width: double.infinity),
                  )
                : existingUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(existingUrl, fit: BoxFit.cover, width: double.infinity),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 40, color: Colors.grey.shade600),
                          const SizedBox(height: 8),
                          Text(label, style: TextStyle(color: Colors.grey.shade600)),
                        ],
                      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          onPressed: () => context.pop(),
          color: const Color(0xFF1A1A2E),
        ),
        title: Text(
          widget.isEditing ? 'Edit Profile' : 'Complete Your Profile',
          style: const TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Profile Photo
              const Text(
                'Profile Photo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 8),
              _buildImagePicker(
                label: 'Tap to add photo',
                selectedFile: _profileImage,
                existingUrl: _existingProfilePhotoUrl,
                onTap: _pickProfileImage,
                isUploading: _isUploadingProfile,
              ),
              const SizedBox(height: 20),

              // Personal Information
              const Text(
                'Personal Information',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  hintText: 'Enter your full name',
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                validator: (v) => v?.isEmpty ?? true ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _phoneController,
                decoration: InputDecoration(
                  labelText: 'Phone Number *',
                  hintText: 'Enter your phone number',
                  prefixIcon: const Icon(Icons.phone_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.phone,
                validator: (v) {
                  if (v?.isEmpty ?? true) return 'Phone is required';
                  if (v!.length < 10) return 'Enter valid phone number';
                  return null;
                },
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  hintText: 'Enter your email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),

              TextFormField(
                controller: _addressController,
                decoration: InputDecoration(
                  labelText: 'Address',
                  hintText: 'Enter your address',
                  prefixIcon: const Icon(Icons.location_on_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Identity Verification
              const Text(
                'Identity Verification',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),

              DropdownButtonFormField<String>(
                value: _identityDocumentType,
                decoration: InputDecoration(
                  labelText: 'Identity Document Type *',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: _documentTypes.map((type) {
                  return DropdownMenuItem(value: type, child: Text(type));
                }).toList(),
                onChanged: (v) => setState(() => _identityDocumentType = v),
                validator: (v) => v == null && _existingIdentityDocUrl == null
                    ? 'Select document type'
                    : null,
              ),
              const SizedBox(height: 12),

              _buildImagePicker(
                label: 'Tap to upload ID document',
                selectedFile: _identityDocument,
                existingUrl: _existingIdentityDocUrl,
                onTap: _pickIdentityDocument,
                isUploading: _isUploadingDocument,
              ),
              const SizedBox(height: 8),
              Text(
                'Upload a clear photo of your ${_identityDocumentType ?? 'ID document'}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 30),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  onPressed: _isLoading ? null : _saveProfile,
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          widget.isEditing ? 'Save Changes' : 'Complete Setup',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
