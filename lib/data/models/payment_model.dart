class PaymentModel {

  final String id;
  final String tripId;
  final double amount;
  final String status;

  PaymentModel({
    required this.id,
    required this.tripId,
    required this.amount,
    required this.status,
  });

  factory PaymentModel.fromJson(Map<String,dynamic> json){

    return PaymentModel(
      id: json['id'],
      tripId: json['trip_id'],
      amount: (json['amount'] as num).toDouble(),
      status: json['status'],
    );
  }

}