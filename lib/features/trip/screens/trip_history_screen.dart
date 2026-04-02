import 'package:flutter/material.dart';

class TripHistoryScreen extends StatelessWidget {

  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Trip History"),
      ),

      body: ListView.builder(

        itemCount: 5,

        itemBuilder: (context,index){

          return ListTile(

            leading: const Icon(Icons.directions_car),

            title: Text("Trip ${index + 1}"),

            subtitle: const Text("Completed"),

            trailing: const Text("₹120"),

          );

        },
      ),
    );
  }
}