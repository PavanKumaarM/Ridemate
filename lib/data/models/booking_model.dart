import 'package:ridemate_app/data/models/trip_model.dart';

class BookingModel {
  final String id;
  final String tripId;
  final String bookerId;
  final String hostId;
  final String status;
  final int seatsBooked;
  final double totalFare;
  final DateTime createdAt;
  final DateTime updatedAt;
  final TripModel? trip;

  BookingModel({
    required this.id,
    required this.tripId,
    required this.bookerId,
    required this.hostId,
    required this.status,
    required this.seatsBooked,
    required this.totalFare,
    required this.createdAt,
    required this.updatedAt,
    this.trip,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      tripId: json['trip_id'] as String,
      bookerId: json['booker_id'] as String,
      hostId: json['host_id'] as String,
      status: json['status'] as String,
      seatsBooked: json['seats_booked'] as int? ?? 1,
      totalFare: (json['total_fare'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      trip: json['trips'] != null
          ? TripModel.fromJson(json['trips'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'trip_id': tripId,
      'booker_id': bookerId,
      'host_id': hostId,
      'status': status,
      'seats_booked': seatsBooked,
      'total_fare': totalFare,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BookingModel copyWith({
    String? id,
    String? tripId,
    String? bookerId,
    String? hostId,
    String? status,
    int? seatsBooked,
    double? totalFare,
    DateTime? createdAt,
    DateTime? updatedAt,
    TripModel? trip,
  }) {
    return BookingModel(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      bookerId: bookerId ?? this.bookerId,
      hostId: hostId ?? this.hostId,
      status: status ?? this.status,
      seatsBooked: seatsBooked ?? this.seatsBooked,
      totalFare: totalFare ?? this.totalFare,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      trip: trip ?? this.trip,
    );
  }
}
