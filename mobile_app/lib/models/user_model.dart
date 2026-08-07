import 'dart:convert';

class UserModel {
  final int id;
  final String fullname;
  final String email;

  UserModel({
    required this.id,
    required this.fullname,
    required this.email,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      fullname: json['fullname'],
      email: json['email'],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'fullname': fullname,
        'email': email,
      };

  String toJsonString() => jsonEncode(toJson());

  static UserModel fromJsonString(String str) =>
      UserModel.fromJson(jsonDecode(str));
}
