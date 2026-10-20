import 'package:flutter_test/flutter_test.dart';
import 'package:icebreaker/main.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert';

void main() {
  group('Authentication Tests', () {
    test('JWT token validation - expired token', () {
      // Create an expired token (expired 1 hour ago)
      final expiredToken = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyLCJleHAiOjE1MTYyMzkwMjJ9.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      expect(JwtDecoder.isExpired(expiredToken), true);
    });

    test('JWT token validation - valid token', () {
      // Create a token with expiration date 1 year from now
      final now = DateTime.now();
      final oneYearFromNow = now.add(const Duration(days: 365));
      
      final header = {
        'alg': 'HS256',
        'typ': 'JWT'
      };
      
      final payload = {
        'sub': '1234567890',
        'name': 'John Doe',
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': oneYearFromNow.millisecondsSinceEpoch ~/ 1000
      };
      
      final encodedHeader = base64Url.encode(utf8.encode(json.encode(header)));
      final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));
      final validToken = '$encodedHeader.$encodedPayload.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      
      expect(JwtDecoder.isExpired(validToken), false);
    });

    test('JWT token decoding - valid user ID extraction', () {
      const testUserId = '1234567890';
      final now = DateTime.now();
      final oneYearFromNow = now.add(const Duration(days: 365));
      
      final header = {
        'alg': 'HS256',
        'typ': 'JWT'
      };
      
      final payload = {
        'sub': testUserId,
        'name': 'John Doe',
        'iat': now.millisecondsSinceEpoch ~/ 1000,
        'exp': oneYearFromNow.millisecondsSinceEpoch ~/ 1000
      };
      
      final encodedHeader = base64Url.encode(utf8.encode(json.encode(header)));
      final encodedPayload = base64Url.encode(utf8.encode(json.encode(payload)));
      final token = '$encodedHeader.$encodedPayload.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c';
      
      final decodedToken = JwtDecoder.decode(token);
      expect(decodedToken['sub'], testUserId);
    });
  });
} 