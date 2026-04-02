import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/available_trips_provider.dart';
import '../../../data/models/trip_model.dart';

import '../widgets/trip_match_card.dart';

class AvailableTripsScreen extends ConsumerWidget {

  final String destination;

  const AvailableTripsScreen({
    super.key,
    required this.destination
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {

    final tripsAsync = ref.watch(availableTripsProvider);

    return tripsAsync.when(

      data: (trips){

        final filteredTrips = trips.where((trip){

          return trip.destAddress
              .toLowerCase()
              .contains(destination.toLowerCase());

        }).toList();

        if(filteredTrips.isEmpty){

          return const Center(
            child: Text("No trips available"),
          );
        }

        return ListView.builder(
          itemCount: filteredTrips.length,
          itemBuilder: (context,index){

            final TripModel trip = filteredTrips[index];

            return TripMatchCard(trip: trip);
          },
        );
      },

      loading: ()=> const Center(
        child: CircularProgressIndicator(),
      ),

      error: (e,_)=> Center(
        child: Text(e.toString()),
      ),
    );
  }
}