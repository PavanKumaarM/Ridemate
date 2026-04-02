import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ridemate_app/features/home/widgets/stats_widget.dart';
import 'package:ridemate_app/features/home/widgets/trip_card.dart';

import '../../../providers/trip_provider.dart';


class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final tripsAsync = ref.watch(tripProvider);

    return Scaffold(

      appBar: AppBar(
        title: const Text("Ride Companion"),
        centerTitle: true,
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const StatsWidget(),

            const SizedBox(height: 20),

            /// CREATE TRIP CARD
            Card(
              child: ListTile(

                leading: const Icon(Icons.add_circle,
                    color: Colors.blue),

                title: const Text("Create a Trip"),

                subtitle: const Text(
                    "Going somewhere? Earn by sharing ride"),

                trailing: const Icon(Icons.arrow_forward),

                onTap: (){
                  context.push("/createTrip");
                },

              ),
            ),

            const SizedBox(height: 10),

            /// JOIN TRIP CARD
            Card(
              child: ListTile(

                leading: const Icon(Icons.group,
                    color: Colors.green),

                title: const Text("Available Companions"),

                subtitle: const Text(
                    "Find people going your way"),

                trailing: const Icon(Icons.arrow_forward),

                onTap: (){
                  context.push("/availableTrips");
                },

              ),
            ),

            const SizedBox(height: 20),

            const Text(
              "Upcoming Trips",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: tripsAsync.when(

                data: (trips){

                  if(trips.isEmpty){
                    return const Center(
                      child: Text("No trips yet"),
                    );
                  }

                  return ListView.builder(

                    itemCount: trips.length,

                    itemBuilder: (context,index){

                      final trip = trips[index];

                      return TripCard(trip: trip);

                    },

                  );
                },

                loading: () => const Center(
                    child: CircularProgressIndicator()),

                error: (e,_) => Center(
                    child: Text(e.toString())),

              ),
            )

          ],
        ),
      ),
    );
  }
}