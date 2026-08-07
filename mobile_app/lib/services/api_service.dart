import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../models/dashboard_model.dart';
import '../models/evidence_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  static final String _base = AppConstants.baseUrl;

  // ---------------- Health ----------------

  static Future<bool> checkHealth() async {
    try {
      final res = await http
          .get(Uri.parse("$_base/health"))
          .timeout(const Duration(seconds: 5));

      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // ---------------- Register ----------------

  static Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$_base/register"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "fullname": fullname,
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      return {
        "success": true,
        "message": data["message"],
      };
    }

    return {
      "success": false,
      "message": data["detail"] ?? "Registration failed",
    };
  }

  // ---------------- Login ----------------

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final res = await http.post(
      Uri.parse("$_base/login"),
      headers: {
        "Content-Type": "application/json",
      },
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    final data = jsonDecode(res.body);

    if (res.statusCode == 200) {
      return {
        "success": true,
        "user": UserModel.fromJson(data["user"]),
      };
    }

    return {
      "success": false,
      "message": data["detail"] ?? "Login failed",
    };
  }

  // ---------------- Upload ----------------

  static Future<Map<String, dynamic>> uploadEvidence(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    final request = http.MultipartRequest(
      "POST",
      Uri.parse("$_base/upload"),
    );

    request.files.add(
      await http.MultipartFile.fromPath(
        "file",
        file.path,
        contentType: MediaType.parse(
          _guessMime(file.path),
        ),
      ),
    );
final user = await AuthService.loadUser();

if (user != null) {
  request.fields["user_id"] = user.id.toString();
}
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);

print("Status: ${response.statusCode}");
print("Body: ${response.body}");

final data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      return {
        "success": true,
        "data": EvidenceModel.fromJson(data),
      };
    }

    return {
      "success": false,
      "message": data["detail"] ?? "Upload failed",
    };
  }

  static String _guessMime(String path) {
    final ext = path.split(".").last.toLowerCase();

    const map = {
      "mp4": "video/mp4",
      "mov": "video/quicktime",
      "avi": "video/x-msvideo",
      "mkv": "video/x-matroska",
      "webm": "video/webm",
      "jpg": "image/jpeg",
      "jpeg": "image/jpeg",
      "png": "image/png",
    };

    return map[ext] ?? "application/octet-stream";
  }

  // ---------------- Dashboard ----------------

  static Future<DashboardModel?> getDashboard() async {
  try {
    final user = await AuthService.loadUser();

    print("Logged in user = ${user?.id}");

    if (user == null) return null;

    final url = "$_base/dashboard/${user.id}";
    print("URL = $url");

    final res = await http.get(Uri.parse(url));

    print("Status = ${res.statusCode}");
    print("Body = ${res.body}");

    if (res.statusCode == 200) {
      return DashboardModel.fromJson(jsonDecode(res.body));
    }
  } catch (e) {
    print("Dashboard Error: $e");
  }

  return null;
}
  // ---------------- Verify ----------------

  static Future<Map<String, dynamic>> verifyEvidence(
      String evidenceId) async {
    try {
      final res = await http.get(
        Uri.parse("$_base/verify/$evidenceId"),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          "success": true,
          "data": data,
        };
      }

      return {
        "success": false,
        "message": data["detail"] ?? "Not found",
      };
    } catch (_) {
      return {
        "success": false,
        "message": "Connection error",
      };
    }
  }
}