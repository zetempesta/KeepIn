import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

@immutable
class Note extends Equatable {
  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.backgroundColor,
    required this.labels,
    required this.isPinned,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Note.create({
    String? title,
    String? content,
    Color backgroundColor = const Color(0xFFFFFFFF),
    List<String> labels = const <String>[],
    bool isPinned = false,
  }) {
    final now = DateTime.now();
    return Note(
      id: null,
      title: title?.trim() ?? '',
      content: content?.trim() ?? '',
      backgroundColor: backgroundColor,
      labels: List<String>.unmodifiable(labels),
      isPinned: isPinned,
      createdAt: now,
      updatedAt: now,
    );
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String?,
      title: (json['title'] as String? ?? '').trim(),
      content: (json['content'] as String? ?? '').trim(),
      backgroundColor: _parseColor(json['backgroundColor']),
      labels: List<String>.unmodifiable(
        ((json['labels'] as List<dynamic>?) ?? const <dynamic>[])
            .map((item) => item.toString()),
      ),
      isPinned: json['isPinned'] as bool? ?? false,
      createdAt: DateTime.parse(
        json['createdAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  factory Note.fromDatabase(Map<String, Object?> row) {
    final rawLabels = row['labels'];
    final labels = switch (rawLabels) {
      List<String> value => value,
      List<dynamic> value => value.map((item) => item.toString()).toList(),
      String value when value.isNotEmpty =>
        value.split(',').map((item) => item.trim()).toList(),
      _ => <String>[],
    };

    return Note(
      id: row['id']?.toString(),
      title: (row['title'] as String? ?? '').trim(),
      content: (row['content'] as String? ?? '').trim(),
      backgroundColor: _parseColor(row['background_color']),
      labels: List<String>.unmodifiable(labels),
      isPinned: row['is_pinned'] as bool? ?? false,
      createdAt: _parseDateTime(row['created_at']),
      updatedAt: _parseDateTime(row['updated_at']),
    );
  }

  final String? id;
  final String title;
  final String content;
  final Color backgroundColor;
  final List<String> labels;
  final bool isPinned;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isEmpty => title.isEmpty && content.isEmpty;

  Note copyWith({
    String? id,
    String? title,
    String? content,
    Color? backgroundColor,
    List<String>? labels,
    bool? isPinned,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      labels: List<String>.unmodifiable(labels ?? this.labels),
      isPinned: isPinned ?? this.isPinned,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'title': title,
      'content': content,
      'backgroundColor': backgroundColor.toARGB32(),
      'labels': labels,
      'isPinned': isPinned,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  Map<String, Object?> toDatabase() {
    return <String, Object?>{
      'id': id,
      'title': title,
      'content': content,
      'background_color': backgroundColor.toARGB32(),
      'labels': labels,
      'is_pinned': isPinned,
      'created_at': createdAt.toUtc(),
      'updated_at': updatedAt.toUtc(),
    };
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        title,
        content,
        backgroundColor,
        labels,
        isPinned,
        createdAt,
        updatedAt,
      ];

  static Color _parseColor(Object? rawColor) {
    return switch (rawColor) {
      int value => Color(value),
      String value => Color(int.tryParse(value) ?? 0xFFFFFFFF),
      _ => const Color(0xFFFFFFFF),
    };
  }

  static DateTime _parseDateTime(Object? rawValue) {
    return switch (rawValue) {
      DateTime value => value.toLocal(),
      String value => DateTime.parse(value).toLocal(),
      _ => DateTime.now(),
    };
  }
}
