import 'dart:convert';
import 'package:http/http.dart' as http;

class MLMatchingService {

  static const baseUrl =
      "http://10.0.2.2:8000"; // emulator

  static Future<List<dynamic>> getMatches(
      Map<String, dynamic> body) async {

    final response = await http.post(

      Uri.parse("$baseUrl/match"),

      headers: {
        "Content-Type": "application/json"
      },

      body: jsonEncode(body),
    );

    final data = jsonDecode(response.body);

    return data["matches"];
  }
}