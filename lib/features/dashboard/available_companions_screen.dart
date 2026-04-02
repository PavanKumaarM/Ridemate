import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ridemate_app/features/matching/widgets/trip_match_card.dart';

import '../../../providers/available_trips_provider.dart';
class AvailableCompanionsScreen extends ConsumerWidget {

  const AvailableCompanionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final tripsAsync = ref.watch(availableTripsProvider);

    return Scaffold(

      appBar: AppBar(
        title: const Text("Available Companions"),
      ),

      body: tripsAsync.when(

        data: (trips){

          if(trips.isEmpty){
            return const Center(
              child: Text("No companions available"),
            );
          }

          return ListView.builder(

            padding: const EdgeInsets.all(16),

            itemCount: trips.length,

            itemBuilder: (context,index){

              final trip = trips[index];

              return TripMatchCard(trip: trip);

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

    );
  }
}