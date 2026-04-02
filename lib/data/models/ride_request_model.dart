class RideRequestModel {

  final String id;
  final String tripId;
  final String passengerId;
  final String status;

  RideRequestModel({
    required this.id,
    required this.tripId,
    required this.passengerId,
    required this.status,
  });

  factory RideRequestModel.fromJson(Map<String,dynamic> json){

    return RideRequestModel(
      id: json['id'],
      tripId: json['trip_id'],
      passengerId: json['passenger_id'],
      status: json['status'],
    );
  }

}