import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../firebase_options.dart';

/// Secure Desktop OAuth 2.0 Loopback Provider for Windows & Linux
///
/// Implements RFC 8252 (OAuth 2.0 for Native Apps) using an ephemeral
/// local loopback server and Firebase Identity Toolkit.
class DesktopGoogleAuthService {
  static Future<UserCredential?> signIn() async {
    HttpServer? server;
    try {
      // 1. Bind local loopback server on port 8080 (standard OAuth desktop port)
      int port = 8080;
      try {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
      } catch (_) {
        server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        port = server.port;
      }
      final redirectUri = 'http://localhost:$port';

      // 2. Request Auth URI from Firebase Identity Toolkit
      final apiKey = DefaultFirebaseOptions.windows.apiKey;
      final createAuthResponse = await http.post(
        Uri.parse('https://identitytoolkit.googleapis.com/v1/accounts:createAuthUri?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'providerId': 'google.com',
          'continueUri': redirectUri,
        }),
      );

      if (createAuthResponse.statusCode != 200) {
        debugPrint('DesktopGoogleAuthService: Failed to create auth URI: ${createAuthResponse.body}');
        return null;
      }

      final authData = jsonDecode(createAuthResponse.body) as Map<String, dynamic>;
      final authUri = authData['authUri'] as String?;
      if (authUri == null || authUri.isEmpty) {
        debugPrint('DesktopGoogleAuthService: authUri is missing in response');
        return null;
      }

      // 3. Launch the Google OAuth sign-in page in system browser
      final launched = await launchUrl(
        Uri.parse(authUri),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('DesktopGoogleAuthService: Could not launch URL: $authUri');
        return null;
      }

      // 4. Listen on local loopback server for Google redirect
      final completer = Completer<Map<String, String>?>();

      // Timeout after 2 minutes if user abandons browser
      final timer = Timer(const Duration(minutes: 2), () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      server.listen((HttpRequest request) async {
        final path = request.uri.path;
        final response = request.response;
        response.headers.contentType = ContentType.html;

        if (path == '/callback') {
          // Received parameters from the client JS redirect
          final params = request.uri.queryParameters;
          response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Reminda - Signed In</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #0F172A; color: white;">
  <div style="text-align: center; padding: 24px;">
    <h1 style="color: #38BDF8; font-size: 28px; margin-bottom: 12px;">&#10004; Signed in to Reminda!</h1>
    <p style="color: #94A3B8; font-size: 16px;">You can now close this tab and return to the application.</p>
  </div>
  <script>setTimeout(function() { window.close(); }, 1200);</script>
</body>
</html>
''');
          await response.close();

          if (!completer.isCompleted) {
            completer.complete(params);
          }
        } else {
          // Initial landing from Google OAuth with hash fragment (#id_token=...)
          response.write('''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Reminda Authentication</title>
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh; margin: 0; background: #0F172A; color: white;">
  <div style="text-align: center; padding: 24px;">
    <h2 style="color: #60A5FA; margin-bottom: 8px;">Authenticating...</h2>
    <p style="color: #94A3B8;">Redirecting back to Reminda desktop application...</p>
  </div>
  <script>
    if (window.location.hash) {
      window.location.href = '/callback?' + window.location.hash.substring(1);
    } else if (window.location.search) {
      window.location.href = '/callback' + window.location.search;
    }
  </script>
</body>
</html>
''');
          await response.close();
        }
      });

      final params = await completer.future;
      timer.cancel();

      if (params == null) {
        debugPrint('DesktopGoogleAuthService: Authentication timed out or was cancelled');
        return null;
      }

      final idToken = params['id_token'];
      final accessToken = params['access_token'];

      if (idToken == null || idToken.isEmpty) {
        debugPrint('DesktopGoogleAuthService: id_token not found in callback params: $params');
        return null;
      }

      // 5. Sign in to Firebase Auth using GoogleAuthProvider.credential
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e, st) {
      debugPrint('DesktopGoogleAuthService error: $e\n$st');
      return null;
    } finally {
      await server?.close(force: true);
    }
  }
}
