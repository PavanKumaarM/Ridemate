class UserModel {

  final String id;
  final String name;
  final String phone;
  final double rating;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.rating,
  });

  factory UserModel.fromJson(Map<String,dynamic> json){

    return UserModel(
      id: json['id'],
      name: json['name'],
      phone: json['phone'],
      rating: (json['rating'] as num).toDouble(),
    );
  }

  Map<String,dynamic> toJson(){

    return {
      "id":id,
      "name":name,
      "phone":phone,
      "rating":rating
    };
  }

}