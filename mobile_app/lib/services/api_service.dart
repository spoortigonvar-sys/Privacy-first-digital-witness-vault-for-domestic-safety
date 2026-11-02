import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:flutter/foundation.dart';
import '../models/dashboard_model.dart';
import '../models/evidence_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';
import 'auth_service.dart';

class ApiService {
  static final String _base = AppConstants.baseUrl;

  // ============================================================
  // VAULT UNLOCK
  // ============================================================
  static Future<String?> getEvidenceVideoUrl(
  String evidenceId,
) async {
  try {
    final user = await AuthService.loadUser();

    if (user == null) {
      return null;
    }

    return "$_base/vault/video/$evidenceId?user_id=${user.id}";
  } catch (_) {
    return null;
  }
}
  static Future<Map<String, dynamic>> unlockVault(String pin) async {
    try {
      final user = await AuthService.loadUser();

      if (user == null) {
        return {
          "success": false,
          "message": "User is not logged in",
        };
      }

      final res = await http.post(
        Uri.parse("$_base/vault/unlock"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "user_id": user.id,
          "pin": pin,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          "success": true,
          "message": data["message"] ?? "Vault unlocked",
        };
      }

      return {
        "success": false,
        "message": data["detail"] ?? "Invalid code",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Unable to connect to Vault",
      };
    }
  }

  // ============================================================
  // MY EVIDENCE
  // ============================================================

  static Future<Map<String, dynamic>> getMyEvidence() async {
    try {
      final user = await AuthService.loadUser();

      if (user == null) {
        return {
          "success": false,
          "message": "Please log in first",
        };
      }

      final res = await http.get(
        Uri.parse("$_base/vault/evidence/${user.id}"),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          "success": true,
          "evidence": data["evidence"] ?? [],
        };
      }

      return {
        "success": false,
        "message": data["detail"] ?? "Unable to load evidence",
      };
    } catch (e) {
      return {
        "success": false,
        "message": "Connection error",
      };
    }
  }

  // ============================================================
  // HEALTH
  // ============================================================

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

  // ============================================================
  // REGISTER
  // ============================================================

  static Future<Map<String, dynamic>> register({
    required String fullname,
    required String email,
    required String password,
  }) async {
    try {
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
    } catch (e) {
      return {
        "success": false,
        "message": "Connection error",
      };
    }
  }

  // ============================================================
  // LOGIN
  // ============================================================

 
static Future<Map<String, dynamic>> login({
  required String email,
  required String password,
}) async {
  final url = Uri.parse("$_base/login");

  print("========== LOGIN DEBUG ==========");
  print("Base URL: $_base");
  print("Login URL: $url");
  print("LOGIN METHOD CALLED");

  try {
    final res = await http
        .post(
          url,
          headers: {
            "Content-Type": "application/json",
          },
          body: jsonEncode({
            "email": email.trim(),
            "password": password,
          }),
        )
        .timeout(const Duration(seconds: 15));

    print("LOGIN STATUS: ${res.statusCode}");
    print("LOGIN RESPONSE: ${res.body}");

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
  } catch (e, stackTrace) {
    print("LOGIN ERROR: $e");
    print(stackTrace);

    return {
      "success": false,
      "message": "Connection error: $e",
    };
  }
}


  // ============================================================
  // UPLOAD EVIDENCE
  // ============================================================

  
  static Future<Map<String, dynamic>> uploadEvidence(
    File file, {
    void Function(double progress)? onProgress,
  }) async {
    try {
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

      final response = await http.Response.fromStream(
        streamed,
      );

      debugPrint("Status: ${response.statusCode}");
      debugPrint("Body: ${response.body}");

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
    } catch (e, stackTrace) {
      debugPrint("Upload Error: $e");
      debugPrint("Upload StackTrace: $stackTrace");

      return {
        "success": false,
        "message": "Upload error: $e",
      };
    }
  } // IMPORTANT: closes uploadEvidence()



  // ============================================================
  // MIME TYPE
  // ============================================================

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

  // ============================================================
  // DASHBOARD
  // ============================================================

  static Future<DashboardModel?> getDashboard() async {
    try {
      final user = await AuthService.loadUser();

      print("Logged in user = ${user?.id}");

      if (user == null) {
        return null;
      }

      final url = "$_base/dashboard/${user.id}";

      print("URL = $url");

      final res = await http.get(
        Uri.parse(url),
      );

      print("Status = ${res.statusCode}");
      print("Body = ${res.body}");

      if (res.statusCode == 200) {
        return DashboardModel.fromJson(
          jsonDecode(res.body),
        );
      }
    } catch (e) {
      print("Dashboard Error: $e");
    }

    return null;
  }

  // ============================================================
  // VERIFY EVIDENCE
  // ============================================================

  static Future<Map<String, dynamic>> verifyEvidence(
    String evidenceId,
  ) async {
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

  // ============================================================
  // EMERGENCY CONTACTS - GET
  // ============================================================

  static Future<Map<String, dynamic>> getEmergencyContacts() async {
    try {
      final user = await AuthService.loadUser();

      if (user == null) {
        return {
          "success": false,
          "message": "Please log in first",
        };
      }

      final res = await http.get(
        Uri.parse("$_base/contacts/${user.id}"),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          "success": true,
          "contacts": data["contacts"] ?? [],
        };
      }

      return {
        "success": false,
        "message": data["detail"] ?? "Unable to load contacts",
      };
    } catch (e) {
      print("Get Contacts Error: $e");

      return {
        "success": false,
        "message": "Connection error",
      };
    }
  }

  // ============================================================
  // EMERGENCY CONTACTS - ADD
  // ============================================================

  static Future<Map<String, dynamic>> addEmergencyContact({
    required String name,
    required String email,
    String? phone,
  }) async {
    try {
      final user = await AuthService.loadUser();

      if (user == null) {
        return {
          "success": false,
          "message": "Please log in first",
        };
      }

      final res = await http.post(
        Uri.parse("$_base/contacts/add"),
        headers: {
          "Content-Type": "application/json",
        },
        body: jsonEncode({
          "user_id": user.id,
          "name": name,
          "email": email,
          "phone": phone,
        }),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          "success": true,
          "message":
              data["message"] ?? "Emergency contact added",
        };
      }

      return {
        "success": false,
        "message":
            data["detail"] ?? "Unable to add contact",
      };
    } catch (e) {
      print("Add Contact Error: $e");

      return {
        "success": false,
        "message": "Connection error",
      };
    }
  }

  // ============================================================
  // EMERGENCY CONTACTS - DELETE
  // ============================================================

  static Future<Map<String, dynamic>> deleteEmergencyContact(
    int contactId,
  ) async {
    try {
      final user = await AuthService.loadUser();

      if (user == null) {
        return {
          "success": false,
          "message": "Please log in first",
        };
      }

      final res = await http.delete(
        Uri.parse(
          "$_base/contacts/${user.id}/$contactId",
        ),
      );

      final data = jsonDecode(res.body);

      if (res.statusCode == 200) {
        return {
          "success": true,
          "message":
              data["message"] ?? "Contact deleted",
        };
      }

      return {
        "success": false,
        "message":
            data["detail"] ?? "Unable to delete contact",
      };
    } catch (e) {
      print("Delete Contact Error: $e");

      return {
        "success": false,
        "message": "Connection error",
      };
    }
  }
}