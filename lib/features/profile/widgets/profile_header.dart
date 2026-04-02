import 'package:flutter/material.dart';
import '../../../data/models/user_model.dart';

class ProfileHeader extends StatelessWidget {

  final UserModel user;

  const ProfileHeader({
    super.key,
    required this.user
  });

  @override
  Widget build(BuildContext context) {

    return Row(

      children: [

        const CircleAvatar(
          radius: 35,
          child: Icon(Icons.person,size:35),
        ),

        const SizedBox(width: 16),

        Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Text(
              user.name,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 4),

            Text(user.phone),

          ],
        )

      ],
    );
  }
}