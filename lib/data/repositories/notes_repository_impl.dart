import '../../domain/entities/note.dart';
import '../../domain/repositories/notes_repository.dart';
import '../services/database_service.dart';

class NotesRepositoryImpl implements NotesRepository {
  NotesRepositoryImpl(this._apiService);

  final NotesApiService _apiService;

  @override
  Future<void> delete(String id) {
    return _apiService.deleteNote(id);
  }

  @override
  Future<List<Note>> fetchAll() {
    return _apiService.fetchNotes();
  }

  @override
  Future<Note> save(Note note) {
    return _apiService.saveNote(note);
  }
}
