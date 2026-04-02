import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;

class LocationSearchService {

  static Future<List<Map<String, dynamic>>> searchPlaces(String query) async {

    if(query.isEmpty) return [];

    final url = Uri.parse(
      "https://nominatim.openstreetmap.org/search"
      "?q=$query&format=json&addressdetails=1&limit=5"
    );

    log('Searching for: $query');

    final response = await http.get(
      url,
      headers: {
        "User-Agent": "RideMate-App"
      }
    );

    log('Response status: ${response.statusCode}');

    if(response.statusCode == 200){
      final results = jsonDecode(response.body) as List<dynamic>;
      log('Results count: ${results.length}');
      return results.cast<Map<String, dynamic>>();
    }

    log('Error: ${response.body}');
    return [];
  }
}