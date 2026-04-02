import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/user_provider.dart';
import '../widgets/profile_header.dart';
import '../widgets/rating_display.dart';

class ProfileScreen extends ConsumerWidget {

  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final user = ref.watch(userProvider);

    if(user == null){
      return const Scaffold(
        body: Center(child: Text("User not found")),
      );
    }

    return Scaffold(

      appBar: AppBar(
        title: const Text("Profile"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            ProfileHeader(user: user),

            const SizedBox(height: 20),

            RatingDisplay(rating: user.rating),

            const SizedBox(height: 30),

            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text("Edit Profile"),
              onTap: (){
                context.push("/editProfile");
              },
            ),

            ListTile(
              leading: const Icon(Icons.history),
              title: const Text("Trip History"),
              onTap: (){
                context.push("/tripHistory");
              },
            ),

            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Logout"),
              onTap: (){
                context.go("/login");
              },
            )

          ],
        ),
      ),
    );
  }
}