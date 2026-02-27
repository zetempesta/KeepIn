import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/auth/auth_session.dart';
import '../../domain/entities/note.dart';

class AuthApiService {
  AuthApiService({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  Future<AuthSessionData> login({
    required String username,
    required String password,
  }) async {
    return _authenticate(
      endpoint: '/auth/login',
      username: username,
      password: password,
      expectedStatuses: const <int>{200},
      actionLabel: 'signing in',
    );
  }

  Future<AuthSessionData> register({
    required String username,
    required String password,
  }) async {
    return _authenticate(
      endpoint: '/auth/register',
      username: username,
      password: password,
      expectedStatuses: const <int>{201},
      actionLabel: 'creating the account',
    );
  }

  Future<AuthSessionData> _authenticate({
    required String endpoint,
    required String username,
    required String password,
    required Set<int> expectedStatuses,
    required String actionLabel,
  }) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: _defaultHeaders,
        body: jsonEncode(<String, String>{
          'username': username,
          'password': password,
        }),
      );

      _throwIfInvalid(response, expectedStatuses: expectedStatuses);
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return AuthSessionData(
        username: payload['username'] as String? ?? username.trim(),
        token: payload['token'] as String? ?? '',
      );
    } catch (error) {
      if (error is NotesApiException) {
        rethrow;
      }

      throw NotesApiException(
        'Unexpected error while $actionLabel: $error',
      );
    }
  }

  Future<void> dispose() async {
    _client.close();
  }
}

class NotesApiService {
  NotesApiService({
    required this.baseUrl,
    this.authToken,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String? authToken;
  final http.Client _client;

  Future<Note> saveNote(Note note) async {
    try {
      final uri = note.id == null
          ? Uri.parse('$baseUrl/notes')
          : Uri.parse('$baseUrl/notes/${note.id}');
      final body = jsonEncode(note.toJson()..remove('id'));
      final response = note.id == null
          ? await _client.post(
              uri,
              headers: _headers,
              body: body,
            )
          : await _client.put(
              uri,
              headers: _headers,
              body: body,
            );

      _throwIfInvalid(response, expectedStatuses: <int>{200, 201});
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return Note.fromJson(payload);
    } catch (error) {
      if (error is NotesApiException) {
        rethrow;
      }

      throw NotesApiException(
        'Unexpected error while saving the note: $error',
      );
    }
  }

  Future<List<Note>> fetchNotes() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/notes'),
        headers: _headers,
      );

      _throwIfInvalid(response, expectedStatuses: <int>{200});
      final payload = jsonDecode(response.body) as List<dynamic>;

      return payload
          .map((item) => Note.fromJson(item as Map<String, dynamic>))
          .toList(growable: false);
    } catch (error) {
      if (error is NotesApiException) {
        rethrow;
      }

      throw NotesApiException(
        'Unexpected error while fetching notes: $error',
      );
    }
  }

  Future<void> deleteNote(String id) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/notes/$id'),
        headers: _headers,
      );

      _throwIfInvalid(response, expectedStatuses: <int>{200});
    } catch (error) {
      if (error is NotesApiException) {
        rethrow;
      }

      throw NotesApiException(
        'Unexpected error while deleting the note: $error',
      );
    }
  }

  Future<List<String>> fetchLabels() async {
    try {
      final response = await _client.get(
        Uri.parse('$baseUrl/labels'),
        headers: _headers,
      );

      _throwIfInvalid(response, expectedStatuses: <int>{200});
      final payload = jsonDecode(response.body) as List<dynamic>;

      return payload
          .map((item) => (item as Map<String, dynamic>)['name'] as String)
          .toList(growable: false);
    } catch (error) {
      if (error is NotesApiException) {
        rethrow;
      }

      throw NotesApiException(
        'Unexpected error while fetching labels: $error',
      );
    }
  }

  Future<String> createLabel(String name) async {
    try {
      final response = await _client.post(
        Uri.parse('$baseUrl/labels'),
        headers: _headers,
        body: jsonEncode(<String, String>{'name': name}),
      );

      _throwIfInvalid(response, expectedStatuses: <int>{201});
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return payload['name'] as String;
    } catch (error) {
      if (error is NotesApiException) {
        rethrow;
      }

      throw NotesApiException(
        'Unexpected error while creating label: $error',
      );
    }
  }

  Future<String> renameLabel({
    required String currentName,
    required String newName,
  }) async {
    try {
      final response = await _client.put(
        Uri.parse('$baseUrl/labels/${Uri.encodeComponent(currentName)}'),
        headers: _headers,
        body: jsonEncode(<String, String>{'newName': newName}),
      );

      _throwIfInvalid(response, expectedStatuses: <int>{200});
      final payload = jsonDecode(response.body) as Map<String, dynamic>;
      return payload['name'] as String;
    } catch (error) {
      if (error is NotesApiException) {
        rethrow;
      }

      throw NotesApiException(
        'Unexpected error while renaming label: $error',
      );
    }
  }

  Future<void> deleteLabel(String name) async {
    try {
      final response = await _client.delete(
        Uri.parse('$baseUrl/labels/${Uri.encodeComponent(name)}'),
        headers: _headers,
      );

      _throwIfInvalid(response, expectedStatuses: <int>{200});
    } catch (error) {
      if (error is NotesApiException) {
        rethrow;
      }

      throw NotesApiException(
        'Unexpected error while deleting label: $error',
      );
    }
  }

  Future<void> dispose() async {
    _client.close();
  }

  Map<String, String> get _headers {
    final headers = <String, String>{..._defaultHeaders};
    final token = authToken;
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }
}

class NotesApiException implements Exception {
  const NotesApiException(this.message);

  final String message;

  @override
  String toString() => 'NotesApiException($message)';
}

const Map<String, String> _defaultHeaders = <String, String>{
  'Content-Type': 'application/json',
  'Accept': 'application/json',
};

void _throwIfInvalid(
  http.Response response, {
  required Set<int> expectedStatuses,
}) {
  if (expectedStatuses.contains(response.statusCode)) {
    return;
  }

  String message = 'HTTP ${response.statusCode}';

  if (response.body.isNotEmpty) {
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic> && decoded['detail'] is String) {
        message = decoded['detail'] as String;
      } else {
        message = response.body;
      }
    } catch (_) {
      message = response.body;
    }
  }

  throw NotesApiException(
    'Backend request failed (${response.statusCode}): $message',
  );
}
