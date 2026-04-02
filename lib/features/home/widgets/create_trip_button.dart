import 'package:flutter/material.dart';
import '../../trip/screens/create_trip_screen.dart';

class CreateTripButton extends StatelessWidget {

  const CreateTripButton({super.key});

  @override
  Widget build(BuildContext context) {

    return SizedBox(
      width: double.infinity,

      child: ElevatedButton(

        onPressed: (){

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const CreateTripScreen()
            )
          );

        },

        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14)
        ),

        child: const Text(
          "Create Trip",
          style: TextStyle(fontSize: 16),
        ),
      ),
    );
  }
}