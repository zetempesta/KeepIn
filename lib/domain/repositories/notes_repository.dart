import '../entities/note.dart';

abstract interface class NotesRepository {
  Future<Note> save(Note note);
  Future<List<Note>> fetchAll();
  Future<void> delete(String id);
}
