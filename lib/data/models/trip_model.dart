class TripModel {

  final String id;
  final String agentId;

  final double startLat;
  final double startLng;

  final double destLat;
  final double destLng;

  final String startAddress;
  final String destAddress;

  final DateTime departureTime;

  final int availableSeats;

  final double basePrice;

  final String status;

  final DateTime createdAt;

  TripModel({
    required this.id,
    required this.agentId,
    required this.startLat,
    required this.startLng,
    required this.destLat,
    required this.destLng,
    required this.startAddress,
    required this.destAddress,
    required this.departureTime,
    required this.availableSeats,
    required this.basePrice,
    required this.status,
    required this.createdAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {

    return TripModel(

      id: json['id'],

      agentId: json['agent_id'],

      startLat: (json['start_lat'] as num).toDouble(),
      startLng: (json['start_lng'] as num).toDouble(),

      destLat: (json['dest_lat'] as num).toDouble(),
      destLng: (json['dest_lng'] as num).toDouble(),

      startAddress: json['start_address'],
      destAddress: json['dest_address'],

      departureTime: DateTime.parse(json['departure_time']),

      availableSeats: json['available_seats'],

      basePrice: (json['base_price'] as num).toDouble(),

      status: json['status'],

      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {

    return {

      "id": id,
      "agent_id": agentId,

      "start_lat": startLat,
      "start_lng": startLng,

      "dest_lat": destLat,
      "dest_lng": destLng,

      "start_address": startAddress,
      "dest_address": destAddress,

      "departure_time": departureTime.toIso8601String(),

      "available_seats": availableSeats,

      "base_price": basePrice,

      "status": status,

      "created_at": createdAt.toIso8601String()

    };
  }
}