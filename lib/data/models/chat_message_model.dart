class ChatMessageModel {

  final String id;
  final String tripId;
  final String senderId;
  final String message;

  ChatMessageModel({
    required this.id,
    required this.tripId,
    required this.senderId,
    required this.message,
  });

  factory ChatMessageModel.fromJson(Map<String,dynamic> json){

    return ChatMessageModel(
      id: json['id'],
      tripId: json['trip_id'],
      senderId: json['sender_id'],
      message: json['message'],
    );
  }

}