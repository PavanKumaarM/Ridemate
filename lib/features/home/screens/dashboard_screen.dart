import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/trip_provider.dart';
import '../widgets/create_trip_button.dart';
import '../widgets/stats_widget.dart';
import '../widgets/trip_card.dart';

class DashboardScreen extends ConsumerWidget {

  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final tripsAsync = ref.watch(tripProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride Companion"),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            const StatsWidget(),

            const SizedBox(height: 20),

            const CreateTripButton(),

            const SizedBox(height: 20),

            const Text(
              "Upcoming Trips",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold
              ),
            ),

            const SizedBox(height: 10),

            Expanded(
              child: tripsAsync.when(

                data: (trips) {

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
                  child: CircularProgressIndicator(),
                ),

                error: (e,_) => Center(
                  child: Text(e.toString()),
                ),
              ),
            )

          ],
        ),
      ),
    );
  }
}