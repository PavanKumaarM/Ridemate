import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../data/models/user_model.dart';
import '../../../providers/user_provider.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
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
    _loadUserData();
  }

  void _loadUserData() {
    final user = ref.read(userProvider);
    if (user != null) {
      _nameController.text = user.name;
      _phoneController.text = user.phone;
      _emailController.text = user.email ?? '';
      _addressController.text = user.address ?? '';
      _existingProfilePhotoUrl = user.profilePhotoUrl;
      _existingIdentityDocUrl = user.identityDocumentUrl;
      _identityDocumentType = user.identityDocumentType;
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

    setState(() => _isLoading = true);

    try {
      // Get current user from Supabase auth instead of provider
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) throw Exception('Not logged in');

      // Get existing user data from provider if available
      final providerUser = ref.read(userProvider);

      String? profilePhotoUrl = _existingProfilePhotoUrl;
      String? identityDocUrl = _existingIdentityDocUrl;

      if (_profileImage != null) {
        setState(() => _isUploadingProfile = true);
        final ext = _profileImage!.path.split('.').last;
        final path = '${authUser.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        profilePhotoUrl = await _uploadFile(_profileImage!, 'profile-photos', path);
        setState(() => _isUploadingProfile = false);
      }

      if (_identityDocument != null) {
        setState(() => _isUploadingDocument = true);
        final ext = _identityDocument!.path.split('.').last;
        final path = '${authUser.id}/${DateTime.now().millisecondsSinceEpoch}.$ext';
        identityDocUrl = await _uploadFile(_identityDocument!, 'identity-documents', path);
        setState(() => _isUploadingDocument = false);
      }

      final updatedUser = UserModel(
        id: authUser.id,
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
        email: _emailController.text.trim().isEmpty 
            ? null 
            : _emailController.text.trim(),
        address: _addressController.text.trim().isEmpty 
            ? null 
            : _addressController.text.trim(),
        profilePhotoUrl: profilePhotoUrl,
        identityDocumentUrl: identityDocUrl,
        identityDocumentType: _identityDocumentType,
        isProfileComplete: true,
        rating: providerUser?.rating ?? 0.0,
        status: 'pending',
        updatedAt: DateTime.now(),
      );

      await Supabase.instance.client
          .from('users')
          .upsert(updatedUser.toJson());

      ref.read(userProvider.notifier).setUser(updatedUser);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        context.push('/verificationPending');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: BackButton(
          color: const Color(0xFF1A1A2E),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildProfilePhotoSection(),
              const SizedBox(height: 24),
              _buildSectionCard(
                title: 'Personal Information',
                icon: Icons.person_outline,
                children: [
                  _buildTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: Icons.person,
                    validator: (v) => v?.isEmpty ?? true ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _phoneController,
                    label: 'Phone Number',
                    hint: 'Enter your phone number',
                    icon: Icons.phone,
                    keyboardType: TextInputType.phone,
                    validator: (v) {
                      if (v?.isEmpty ?? true) return 'Phone is required';
                      if (v!.length < 10) return 'Enter valid phone number';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email Address',
                    hint: 'Enter your email',
                    icon: Icons.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Address Details',
                icon: Icons.location_on_outlined,
                children: [
                  _buildTextField(
                    controller: _addressController,
                    label: 'Full Address',
                    hint: 'Enter your complete address',
                    icon: Icons.home,
                    maxLines: 3,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSectionCard(
                title: 'Identity Verification',
                icon: Icons.verified_user_outlined,
                children: [
                  _buildDocumentTypeDropdown(),
                  const SizedBox(height: 16),
                  _buildDocumentUploadSection(),
                ],
              ),
              const SizedBox(height: 30),
              _buildVerifyButton(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePhotoSection() {
    return Stack(
      alignment: Alignment.bottomRight,
      children: [
        Container(
          width: 140,
          height: 140,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF2563EB), width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF2563EB).withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: ClipOval(
            child: _isUploadingProfile
                ? const Center(child: CircularProgressIndicator())
                : _profileImage != null
                    ? Image.file(_profileImage!, fit: BoxFit.cover)
                    : _existingProfilePhotoUrl != null
                        ? Image.network(_existingProfilePhotoUrl!, fit: BoxFit.cover)
                        : Container(
                            color: const Color(0xFF2563EB).withOpacity(0.1),
                            child: const Icon(
                              Icons.person,
                              size: 60,
                              color: Color(0xFF2563EB),
                            ),
                          ),
          ),
        ),
        GestureDetector(
          onTap: _pickProfileImage,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB),
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: const Color(0xFF2563EB)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildDocumentTypeDropdown() {
    return DropdownButtonFormField<String>(
      value: _identityDocumentType,
      decoration: InputDecoration(
        labelText: 'Identity Document Type',
        prefixIcon: const Icon(Icons.badge, color: Color(0xFF2563EB)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF2563EB), width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
      ),
      items: _documentTypes.map((type) {
        return DropdownMenuItem(value: type, child: Text(type));
      }).toList(),
      onChanged: (value) => setState(() => _identityDocumentType = value),
    );
  }

  Widget _buildDocumentUploadSection() {
    return GestureDetector(
      onTap: _pickIdentityDocument,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _identityDocument != null || _existingIdentityDocUrl != null
                ? const Color(0xFF2563EB)
                : Colors.grey.shade300,
            width: _identityDocument != null || _existingIdentityDocUrl != null ? 2 : 1,
          ),
          color: Colors.grey.shade50,
        ),
        child: _isUploadingDocument
            ? const Center(child: CircularProgressIndicator())
            : _identityDocument != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_identityDocument!, fit: BoxFit.cover, width: double.infinity),
                  )
                : _existingIdentityDocUrl != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(
                          _existingIdentityDocUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.cloud_upload_outlined,
                              size: 40,
                              color: Color(0xFF2563EB),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Tap to upload ID document',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'JPG, PNG supported',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
      ),
    );
  }

  Widget _buildVerifyButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2563EB).withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProfile,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Verifying...',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ],
              )
            : const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Verify & Save Profile',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
      ),
    );
  }
}