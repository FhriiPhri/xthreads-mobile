import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse {
  final bool success;
  final dynamic data;
  final String? message;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
  });

  factory ApiResponse.fromHttpResponse(http.Response response) {
    final json = jsonDecode(response.body);
    return ApiResponse(
      success: response.statusCode >= 200 && response.statusCode < 300,
      data: json['data'],
      message: json['message'] ?? '',
    );
  }

  static ApiResponse withError(dynamic error) {
    return ApiResponse(success: false, message: error.toString());
  }
}
