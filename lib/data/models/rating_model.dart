class RatingModel {

  final String id;
  final String tripId;
  final int rating;
  final String review;

  RatingModel({
    required this.id,
    required this.tripId,
    required this.rating,
    required this.review,
  });

  factory RatingModel.fromJson(Map<String,dynamic> json){

    return RatingModel(
      id: json['id'],
      tripId: json['trip_id'],
      rating: json['rating'],
      review: json['review'],
    );
  }

}