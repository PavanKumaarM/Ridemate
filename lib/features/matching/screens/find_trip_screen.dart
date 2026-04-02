import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/filter_widget.dart';
import 'available_trips_screen.dart';

class FindTripScreen extends StatefulWidget {
  const FindTripScreen({super.key});

  @override
  State<FindTripScreen> createState() => _FindTripScreenState();
}

class _FindTripScreenState extends State<FindTripScreen> {

  final TextEditingController destinationController =
      TextEditingController();

  void searchTrip() {

    final destination = destinationController.text;

    if(destination.isEmpty){
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Enter destination"))
      );
      return;
    }

    context.push(
      "/findTripResults",
      extra: destination
    );
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text("Find Ride"),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          children: [

            TextField(
              controller: destinationController,

              decoration: const InputDecoration(
                labelText: "Destination",
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on)
              ),
            ),

            const SizedBox(height: 20),

            const FilterWidget(),

            const SizedBox(height: 30),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: searchTrip,
                child: const Text("Search Ride"),
              ),
            ),

            const SizedBox(height: 20),

            Expanded(
              child: AvailableTripsScreen(
                destination: destinationController.text,
              ),
            )

          ],
        ),
      ),
    );
  }
}