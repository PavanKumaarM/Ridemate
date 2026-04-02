import '../datasources/trip_datasource.dart';
import '../models/trip_model.dart';

class TripRepository {

  final TripDatasource datasource = TripDatasource();

  Future<List<TripModel>> fetchTrips(){

    return datasource.getTrips();

  }

  Future<void> createTrip(Map<String,dynamic> data){

    return datasource.createTrip(data);

  }

}