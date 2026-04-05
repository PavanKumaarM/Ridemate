import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../providers/user_provider.dart';
import '../../../data/models/user_model.dart';
import '../widgets/rating_display.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  UserModel? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    final providerUser = ref.read(userProvider);
    if (providerUser != null) {
      setState(() {
        _user = providerUser;
        _isLoading = false;
      });
      return;
    }

    try {
      final authUser = Supabase.instance.client.auth.currentUser;
      if (authUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await Supabase.instance.client
          .from('users')
          .select()
          .eq('id', authUser.id)
          .single();

      final user = UserModel.fromJson(response);
      ref.read(userProvider.notifier).setUser(user);
      
      setState(() {
        _user = user;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading user: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_user == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text("User not found"),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadUser,
                child: const Text("Retry"),
              ),
            ],
          ),
        ),
      );
    }

    final user = _user!;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          "Profile",
          style: TextStyle(
            color: Color(0xFF1A1A2E),
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Color(0xFF1A1A2E)),
            onPressed: () => context.push('/profileSetup'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Profile Photo
            _ProfileAvatar(
              photoUrl: user.profilePhotoUrl,
              name: user.name,
            ),
            const SizedBox(height: 16),
            
            // Name
            Text(
              user.name,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1A1A2E),
              ),
            ),
            const SizedBox(height: 4),
            
            // Rating
            RatingDisplay(rating: user.rating),
            const SizedBox(height: 24),
            
            // Info Cards
            _InfoCard(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: user.phone,
            ),
            const SizedBox(height: 12),
            
            _InfoCard(
              icon: Icons.email_outlined,
              label: 'Email',
              value: user.email ?? 'Not provided',
              isPlaceholder: user.email == null,
            ),
            const SizedBox(height: 12),
            
            _InfoCard(
              icon: Icons.location_on_outlined,
              label: 'Address',
              value: user.address ?? 'Not provided',
              isPlaceholder: user.address == null,
            ),
            const SizedBox(height: 12),
            
            _InfoCard(
              icon: Icons.badge_outlined,
              label: 'ID Verification',
              value: user.identityDocumentType ?? 'Not verified',
              isPlaceholder: user.identityDocumentType == null,
              trailing: user.identityDocumentUrl != null 
                ? const Icon(Icons.verified, color: Colors.green, size: 20)
                : null,
            ),
            const SizedBox(height: 30),
            
            // Menu Items
            _MenuItem(
              icon: Icons.history,
              title: 'Trip History',
              onTap: () => context.push('/tripHistory'),
            ),
            const SizedBox(height: 12),
            
            _MenuItem(
              icon: Icons.logout,
              title: 'Logout',
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/login');
              },
              isDestructive: true,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  
  const _ProfileAvatar({this.photoUrl, required this.name});
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF2563EB), width: 3),
        image: photoUrl != null
            ? DecorationImage(
                image: NetworkImage(photoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: photoUrl == null
          ? Center(
              child: Text(
                name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2563EB),
                ),
              ),
            )
          : null,
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isPlaceholder;
  final Widget? trailing;
  
  const _InfoCard({
    required this.icon,
    required this.label,
    required this.value,
    this.isPlaceholder = false,
    this.trailing,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF2563EB), size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isPlaceholder ? Colors.grey.shade400 : const Color(0xFF1A1A2E),
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isDestructive;
  
  const _MenuItem({
    required this.icon,
    required this.title,
    required this.onTap,
    this.isDestructive = false,
  });
  
  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: isDestructive ? Colors.red : const Color(0xFF2563EB),
      ),
      title: Text(
        title,
        style: TextStyle(
          color: isDestructive ? Colors.red : const Color(0xFF1A1A2E),
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      onTap: onTap,
    );
  }
}