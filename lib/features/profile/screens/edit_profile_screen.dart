import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/user_provider.dart';
import '../../../data/models/user_model.dart';

class EditProfileScreen extends ConsumerStatefulWidget {

  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState()
      => _EditProfileScreenState();
}

class _EditProfileScreenState
    extends ConsumerState<EditProfileScreen> {

  final nameController = TextEditingController();
  final phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();

    final user = ref.read(userProvider);

    if(user != null){
      nameController.text = user.name;
      phoneController.text = user.phone;
    }
  }

  void saveProfile(){

    final user = ref.read(userProvider);

    if(user == null) return;

    final updatedUser = UserModel(
      id: user.id,
      name: nameController.text,
      phone: phoneController.text,
      rating: user.rating,
    );

    ref.read(userProvider.notifier).setUser(updatedUser);

    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Edit Profile"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          children: [

            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: "Name",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: "Phone",
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(
                onPressed: saveProfile,
                child: const Text("Save"),
              ),
            )

          ],
        ),
      ),
    );
  }
}