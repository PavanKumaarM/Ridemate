import 'package:ridemate_app/core/services/ml_matching_service.dart';

import '../models/trip_model.dart';

class MatchingRepository {

  List<TripModel> matchTrips(
      List<TripModel> trips,
      String destination){

    return trips.where(
      (trip)=>trip.destAddress
      .toLowerCase()
      .contains(destination.toLowerCase())
    ).toList();

  }
  Future<List> fetchBestTrips(
    List trips,
    String destination,
    int time,
) async {

  final request = {

    "passenger_destination": destination,
    "passenger_time": time,
    "trips": trips

  };

  return await MLMatchingService.getMatches(request);
}

}