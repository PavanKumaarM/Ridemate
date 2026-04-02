import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../data/models/trip_model.dart';

class TripMatchCard extends StatelessWidget {

  final TripModel trip;

  const TripMatchCard({
    super.key,
    required this.trip
  });

  @override
  Widget build(BuildContext context) {

    return Card(

      margin: const EdgeInsets.only(bottom: 12),

      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(
              children: [

                const Icon(Icons.location_on,color: Colors.blue),

                const SizedBox(width:8),

                Expanded(
                  child: Text(trip.startAddress),
                )

              ],
            ),

            const SizedBox(height:6),

            Row(
              children: [

                const Icon(Icons.flag,color: Colors.green),

                const SizedBox(width:8),

                Expanded(
                  child: Text(trip.destAddress),
                )

              ],
            ),

            const SizedBox(height:10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [

                Text("Seats: ${trip.availableSeats}"),

                Text("₹${trip.basePrice}")

              ],
            ),

            const SizedBox(height:10),

            SizedBox(
              width: double.infinity,

              child: ElevatedButton(

                onPressed: (){

                  context.push(
                    "/tripDetails",
                    extra: trip
                  );

                },

                child: const Text("View Trip"),
              ),
            )

          ],
        ),
      ),
    );
  }
}