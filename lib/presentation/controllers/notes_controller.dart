import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/di/providers.dart';
import '../../domain/entities/note.dart';

final notesControllerProvider =
    AsyncNotifierProvider<NotesController, NotesState>(NotesController.new);
final selectedLabelProvider = StateProvider<String?>((ref) => null);
final notesSearchQueryProvider = StateProvider<String>((ref) => '');
final labelsSearchQueryProvider = StateProvider<String>((ref) => '');
final labelsCatalogProvider =
    AsyncNotifierProvider<LabelsCatalogController, List<String>>(
  LabelsCatalogController.new,
);

@immutable
class NotesState {
  const NotesState({
    required this.notes,
    this.isSaving = false,
    this.errorMessage,
  });

  final List<Note> notes;
  final bool isSaving;
  final String? errorMessage;

  NotesState copyWith({
    List<Note>? notes,
    bool? isSaving,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotesState(
      notes: notes ?? this.notes,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class NotesController extends AsyncNotifier<NotesState> {
  @override
  Future<NotesState> build() async {
    return _loadState();
  }

  Future<void> saveNote(Note note) async {
    final current = state.valueOrNull ?? const NotesState(notes: <Note>[]);
    state = AsyncData(current.copyWith(isSaving: true, clearError: true));

    try {
      final savedNote = await ref.read(notesRepositoryProvider).save(
            note.copyWith(updatedAt: DateTime.now()),
          );
      final nextNotes = _mergeNote(current.notes, savedNote);
      state = AsyncData(
        current.copyWith(
          notes: nextNotes,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isSaving: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> deleteNote(String id) async {
    final current = state.valueOrNull ?? const NotesState(notes: <Note>[]);
    state = AsyncData(current.copyWith(isSaving: true, clearError: true));

    try {
      await ref.read(notesRepositoryProvider).delete(id);
      final nextNotes =
          current.notes.where((note) => note.id != id).toList(growable: false);
      state = AsyncData(
        current.copyWith(
          notes: nextNotes,
          isSaving: false,
          clearError: true,
        ),
      );
    } catch (error) {
      state = AsyncData(
        current.copyWith(
          isSaving: false,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(await _loadState());
  }

  Future<NotesState> _loadState() async {
    final repository = ref.read(notesRepositoryProvider);

    try {
      final notes = await repository.fetchAll();
      return NotesState(notes: _sortNotes(notes));
    } catch (error) {
      return NotesState(
        notes: const <Note>[],
        errorMessage: error.toString(),
      );
    }
  }

  List<Note> _mergeNote(List<Note> currentNotes, Note savedNote) {
    final withoutCurrent = currentNotes
        .where((note) => note.id != savedNote.id)
        .toList(growable: true)
      ..add(savedNote);
    return _sortNotes(withoutCurrent);
  }

  List<Note> _sortNotes(List<Note> notes) {
    final sorted = List<Note>.of(notes);
    sorted.sort((left, right) {
      if (left.isPinned != right.isPinned) {
        return left.isPinned ? -1 : 1;
      }

      return right.updatedAt.compareTo(left.updatedAt);
    });
    return List<Note>.unmodifiable(sorted);
  }
}

class LabelsCatalogController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    try {
      return await ref.read(notesApiServiceProvider).fetchLabels();
    } catch (_) {
      return const <String>[];
    }
  }

  Future<void> addLabel(String label) async {
    final normalized = _normalizeLabel(label);
    final current = state.valueOrNull ?? const <String>[];
    if (normalized == null || current.contains(normalized)) {
      return;
    }

    state = AsyncData(current);

    try {
      final savedLabel =
          await ref.read(notesApiServiceProvider).createLabel(normalized);
      state = AsyncData(
        List<String>.unmodifiable(<String>[
          ...current,
          savedLabel,
        ]..sort()),
      );
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<String?> renameLabel({
    required String currentName,
    required String newName,
  }) async {
    final normalizedCurrent = _normalizeLabel(currentName);
    final normalizedNew = _normalizeLabel(newName);
    final current = state.valueOrNull ?? const <String>[];

    if (normalizedCurrent == null || normalizedNew == null) {
      return null;
    }

    if (normalizedCurrent == normalizedNew) {
      return normalizedCurrent;
    }

    state = AsyncData(current);

    try {
      final savedLabel = await ref.read(notesApiServiceProvider).renameLabel(
            currentName: normalizedCurrent,
            newName: normalizedNew,
          );
      final next = <String>{
        ...current.where((label) => label != normalizedCurrent),
        savedLabel,
      }.toList(growable: false)
        ..sort();
      state = AsyncData(List<String>.unmodifiable(next));
      return savedLabel;
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }

  Future<void> deleteLabel(String label) async {
    final normalized = _normalizeLabel(label);
    final current = state.valueOrNull ?? const <String>[];
    if (normalized == null) {
      return;
    }

    state = AsyncData(current);

    try {
      await ref.read(notesApiServiceProvider).deleteLabel(normalized);
      final next =
          current.where((item) => item != normalized).toList(growable: false);
      state = AsyncData(List<String>.unmodifiable(next));
    } catch (_) {
      state = AsyncData(current);
      rethrow;
    }
  }
}

String? normalizeLabelInput(String label) => _normalizeLabel(label);

String? _normalizeLabel(String label) {
  final normalized = label.trim();
  if (normalized.isEmpty) {
    return null;
  }

  return normalized;
}
