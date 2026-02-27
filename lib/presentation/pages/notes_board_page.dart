import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../core/theme/app_colors.dart';
import '../../domain/entities/note.dart';
import '../controllers/auth_controller.dart';
import '../controllers/notes_controller.dart';
import '../widgets/note_card.dart';

class NotesBoardPage extends ConsumerWidget {
  const NotesBoardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notesStateAsync = ref.watch(notesControllerProvider);
    final notesState = notesStateAsync.valueOrNull;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            CustomScrollView(
              slivers: <Widget>[
                SliverPersistentHeader(
                  pinned: true,
                  delegate: const _HeaderDelegate(),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  sliver: SliverToBoxAdapter(
                    child: _NotesContent(
                      notesStateAsync: notesStateAsync,
                      onEdit: (note) => _openNoteEditor(
                        context,
                        ref,
                        initialNote: note,
                      ),
                      onDelete: (note) => _confirmDelete(context, ref, note),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 16,
              right: 20,
              child: Tooltip(
                message: 'Sair',
                child: IconButton.filledTonal(
                  onPressed: () =>
                      ref.read(authControllerProvider.notifier).logout(),
                  icon: const Icon(Icons.logout_rounded),
                ),
              ),
            ),
            if (notesState?.isSaving ?? false)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openNoteEditor(context, ref),
        backgroundColor: AppColors.electricBlue,
        foregroundColor: AppColors.pureWhite,
        elevation: 6,
        child: const Icon(Icons.add_rounded),
      ),
    );
  }

  Future<void> _openNoteEditor(
    BuildContext context,
    WidgetRef ref, {
    Note? initialNote,
  }) async {
    final result = await showModalBottomSheet<_NoteEditorResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _NoteEditorSheet(initialNote: initialNote),
    );

    if (result == null) {
      return;
    }

    final controller = ref.read(notesControllerProvider.notifier);

    switch (result.action) {
      case _EditorAction.save:
        await controller.saveNote(result.note!);
      case _EditorAction.delete:
        final noteId = initialNote?.id;
        if (noteId != null) {
          await controller.deleteNote(noteId);
        }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Note note,
  ) async {
    if (note.id == null) {
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir nota'),
        content: Text(
          'Remover "${note.title.isEmpty ? 'Sem titulo' : note.title}" permanentemente?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      await ref.read(notesControllerProvider.notifier).deleteNote(note.id!);
    }
  }
}

class _NotesContent extends ConsumerWidget {
  const _NotesContent({
    required this.notesStateAsync,
    required this.onEdit,
    required this.onDelete,
  });

  final AsyncValue<NotesState> notesStateAsync;
  final ValueChanged<Note> onEdit;
  final ValueChanged<Note> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedLabel = ref.watch(selectedLabelProvider);
    final searchQuery = ref.watch(notesSearchQueryProvider);
    final labelsSearchQuery = ref.watch(labelsSearchQueryProvider);
    final catalogLabelsAsync = ref.watch(labelsCatalogProvider);
    final catalogLabels = catalogLabelsAsync.valueOrNull ?? const <String>[];

    return notesStateAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.only(top: 48),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => _NotesFeedback(
        icon: Icons.cloud_off_rounded,
        title: 'Nao foi possivel carregar',
        message: error.toString(),
      ),
      data: (state) {
        final availableLabels = _collectLabels(
          state.notes,
          catalogLabels: catalogLabels,
        );
        final normalizedLabelsSearch = _normalizedSearchText(labelsSearchQuery);
        final filteredLabels = normalizedLabelsSearch.isEmpty
            ? availableLabels
            : availableLabels
                .where(
                  (label) => _normalizedSearchText(label)
                      .contains(normalizedLabelsSearch),
                )
                .toList(growable: false);
        final activeLabel =
            availableLabels.contains(selectedLabel) ? selectedLabel : null;
        final labelFilteredNotes = activeLabel == null
            ? state.notes
            : state.notes
                .where((note) => note.labels.contains(activeLabel))
                .toList(growable: false);
        final normalizedSearch = _normalizedSearchText(searchQuery);
        final visibleNotes = normalizedSearch.isEmpty
            ? labelFilteredNotes
            : labelFilteredNotes
                .where(
                  (note) => _normalizedSearchText(
                    '${note.title} ${note.content} ${note.labels.join(' ')}',
                  ).contains(normalizedSearch),
                )
                .toList(growable: false);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (state.errorMessage != null) ...<Widget>[
              _InlineError(message: state.errorMessage!),
              const SizedBox(height: 12),
            ],
            _NotesSearchBar(
              query: searchQuery,
              onChanged: (value) {
                ref.read(notesSearchQueryProvider.notifier).state = value;
              },
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final sidebarWidth = constraints.maxWidth >= 960
                    ? 248.0
                    : constraints.maxWidth >= 720
                        ? 220.0
                        : 188.0;

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: sidebarWidth,
                      child: _LabelsSidebar(
                        labels: filteredLabels,
                        labelsSearchQuery: labelsSearchQuery,
                        selectedLabel: activeLabel,
                        notes: state.notes,
                        isLoading: catalogLabelsAsync.isLoading,
                        onSelected: (label) {
                          ref.read(selectedLabelProvider.notifier).state =
                              label;
                        },
                        onLabelsSearchChanged: (value) {
                          ref.read(labelsSearchQueryProvider.notifier).state =
                              value;
                        },
                        onCreateLabel: () => _promptCreateLabel(context, ref),
                        onRenameLabel: (label) =>
                            _promptRenameLabel(context, ref, label),
                        onDeleteLabel: (label) =>
                            _confirmDeleteLabel(context, ref, label),
                        onDropNoteToLabel: (payload, label) =>
                            _moveNoteToLabel(ref, payload, label),
                      ),
                    ),
                    const SizedBox(width: 18),
                    Expanded(
                      child: visibleNotes.isEmpty
                          ? _NotesFeedback(
                              icon: state.notes.isEmpty
                                  ? Icons.note_add_outlined
                                  : Icons.label_outline_rounded,
                              title: state.notes.isEmpty
                                  ? 'Nenhuma nota ainda'
                                  : normalizedSearch.isNotEmpty
                                      ? 'Nenhuma nota encontrada'
                                      : 'Nenhuma nota nessa label',
                              message: state.notes.isEmpty
                                  ? (state.errorMessage ??
                                      'Toque no botao + para criar sua primeira nota.')
                                  : normalizedSearch.isNotEmpty
                                      ? 'Ajuste sua busca ou selecione outro filtro.'
                                      : 'Selecione outra label ou volte para todas as notas.',
                            )
                          : LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final crossAxisCount =
                                    gridConstraints.maxWidth >= 900
                                        ? 4
                                        : gridConstraints.maxWidth >= 640
                                            ? 3
                                            : 2;

                                return MasonryGridView.count(
                                  crossAxisCount: crossAxisCount,
                                  mainAxisSpacing: 16,
                                  crossAxisSpacing: 16,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: visibleNotes.length,
                                  itemBuilder: (context, index) {
                                    final note = visibleNotes[index];

                                    return LongPressDraggable<_NoteDragPayload>(
                                      data: _NoteDragPayload(
                                        note: note,
                                        sourceLabel: activeLabel,
                                      ),
                                      feedback: Material(
                                        color: Colors.transparent,
                                        child: ConstrainedBox(
                                          constraints: const BoxConstraints(
                                            maxWidth: 280,
                                          ),
                                          child: Opacity(
                                            opacity: 0.92,
                                            child: NoteCard(note: note),
                                          ),
                                        ),
                                      ),
                                      childWhenDragging: Opacity(
                                        opacity: 0.35,
                                        child: NoteCard(
                                          key: ValueKey(note.id ??
                                              '${note.createdAt.microsecondsSinceEpoch}-$index'),
                                          note: note,
                                          onTap: () => onEdit(note),
                                        ),
                                      ),
                                      child: NoteCard(
                                        key: ValueKey(note.id ??
                                            '${note.createdAt.microsecondsSinceEpoch}-$index'),
                                        note: note,
                                        onTap: () => onEdit(note),
                                      ),
                                    );
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _NotesFeedback extends StatelessWidget {
  const _NotesFeedback({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 44),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(28),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: AppColors.shadowBlue,
                  blurRadius: 24,
                  offset: Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(icon, color: AppColors.electricBlue, size: 34),
                  const SizedBox(height: 12),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NotesSearchBar extends StatefulWidget {
  const _NotesSearchBar({
    required this.query,
    required this.onChanged,
  });

  final String query;
  final ValueChanged<String> onChanged;

  @override
  State<_NotesSearchBar> createState() => _NotesSearchBarState();
}

class _NotesSearchBarState extends State<_NotesSearchBar> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _NotesSearchBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query == _controller.text) {
      return;
    }

    final selection = _controller.selection;
    _controller.value = TextEditingValue(
      text: widget.query,
      selection: selection.isValid
          ? selection.copyWith(
              baseOffset: selection.baseOffset.clamp(0, widget.query.length),
              extentOffset:
                  selection.extentOffset.clamp(0, widget.query.length),
            )
          : TextSelection.collapsed(offset: widget.query.length),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: 'Buscar notas por titulo, conteudo ou label',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: widget.query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        filled: true,
        fillColor: AppColors.pureWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
    );
  }
}

class _LabelsSidebar extends StatelessWidget {
  const _LabelsSidebar({
    required this.labels,
    required this.labelsSearchQuery,
    required this.selectedLabel,
    required this.notes,
    required this.isLoading,
    required this.onSelected,
    required this.onLabelsSearchChanged,
    required this.onCreateLabel,
    required this.onRenameLabel,
    required this.onDeleteLabel,
    required this.onDropNoteToLabel,
  });

  final List<String> labels;
  final String labelsSearchQuery;
  final String? selectedLabel;
  final List<Note> notes;
  final bool isLoading;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onLabelsSearchChanged;
  final VoidCallback onCreateLabel;
  final ValueChanged<String> onRenameLabel;
  final ValueChanged<String> onDeleteLabel;
  final Future<void> Function(_NoteDragPayload payload, String label)
      onDropNoteToLabel;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: AppColors.shadowBlue,
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'Labels',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                IconButton(
                  onPressed: isLoading ? null : onCreateLabel,
                  tooltip: 'Nova label',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.add_circle_outline_rounded,
                    color: AppColors.electricBlue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isLoading) ...<Widget>[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 12),
            ],
            _SidebarSearchField(
              query: labelsSearchQuery,
              hintText: 'Buscar labels',
              onChanged: onLabelsSearchChanged,
            ),
            const SizedBox(height: 12),
            _LabelMenuTile(
              label: 'Todas',
              count: notes.length,
              selected: selectedLabel == null,
              onTap: () => onSelected(null),
            ),
            const SizedBox(height: 8),
            if (labels.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  labelsSearchQuery.isEmpty
                      ? 'Crie labels para organizar suas notas.'
                      : 'Nenhuma label corresponde a busca.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...labels.map(
                (label) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LabelMenuTile(
                    label: label,
                    count: notes
                        .where((note) => note.labels.contains(label))
                        .length,
                    selected: selectedLabel == label,
                    onTap: () => onSelected(
                      selectedLabel == label ? null : label,
                    ),
                    onRename: () => onRenameLabel(label),
                    onDelete: () => onDeleteLabel(label),
                    onDropNote: (payload) => onDropNoteToLabel(payload, label),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SidebarSearchField extends StatefulWidget {
  const _SidebarSearchField({
    required this.query,
    required this.hintText,
    required this.onChanged,
  });

  final String query;
  final String hintText;
  final ValueChanged<String> onChanged;

  @override
  State<_SidebarSearchField> createState() => _SidebarSearchFieldState();
}

class _SidebarSearchFieldState extends State<_SidebarSearchField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.query);
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _SidebarSearchField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.query == _controller.text) {
      return;
    }

    _controller.value = TextEditingValue(
      text: widget.query,
      selection: TextSelection.collapsed(
        offset: widget.query.length,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      focusNode: _focusNode,
      onChanged: widget.onChanged,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search_rounded, size: 20),
        suffixIcon: widget.query.isEmpty
            ? null
            : IconButton(
                onPressed: () {
                  _controller.clear();
                  widget.onChanged('');
                },
                icon: const Icon(Icons.close_rounded),
              ),
        isDense: true,
        filled: true,
        fillColor: AppColors.mist,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
      ),
    );
  }
}

class _LabelMenuTile extends StatelessWidget {
  const _LabelMenuTile({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    this.onRename,
    this.onDelete,
    this.onDropNote,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onRename;
  final VoidCallback? onDelete;
  final Future<void> Function(_NoteDragPayload payload)? onDropNote;

  @override
  Widget build(BuildContext context) {
    return DragTarget<_NoteDragPayload>(
      onWillAcceptWithDetails: (details) => onDropNote != null,
      onAcceptWithDetails: (details) async {
        await onDropNote?.call(details.data);
      },
      builder: (context, candidateData, rejectedData) {
        final isDropTarget = candidateData.isNotEmpty;

        return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              color: isDropTarget
                  ? AppColors.electricBlue.withValues(alpha: 0.2)
                  : selected
                      ? AppColors.electricBlue.withValues(alpha: 0.12)
                      : Colors.transparent,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isDropTarget || selected
                    ? AppColors.electricBlue
                    : AppColors.divider,
                width: isDropTarget ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      label,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDropTarget || selected
                                ? AppColors.electricBlue
                                : AppColors.ink,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: isDropTarget || selected
                          ? AppColors.electricBlue.withValues(alpha: 0.16)
                          : AppColors.mist,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      child: Text(
                        '$count',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: isDropTarget || selected
                                  ? AppColors.electricBlue
                                  : AppColors.ink,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                  ),
                  if (onRename != null || onDelete != null)
                    PopupMenuButton<_LabelMenuAction>(
                      tooltip: 'Acoes da label',
                      onSelected: (action) {
                        switch (action) {
                          case _LabelMenuAction.rename:
                            onRename?.call();
                          case _LabelMenuAction.delete:
                            onDelete?.call();
                        }
                      },
                      itemBuilder: (context) =>
                          <PopupMenuEntry<_LabelMenuAction>>[
                        if (onRename != null)
                          const PopupMenuItem<_LabelMenuAction>(
                            value: _LabelMenuAction.rename,
                            child: Text('Renomear'),
                          ),
                        if (onDelete != null)
                          const PopupMenuItem<_LabelMenuAction>(
                            value: _LabelMenuAction.delete,
                            child: Text('Excluir'),
                          ),
                      ],
                      icon: Icon(
                        Icons.more_vert_rounded,
                        size: 18,
                        color: isDropTarget || selected
                            ? AppColors.electricBlue
                            : AppColors.ink,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

enum _LabelMenuAction {
  rename,
  delete,
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4F4),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFD6D6)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, color: Color(0xFFC2410C)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _promptCreateLabel(BuildContext context, WidgetRef ref) async {
  String draftLabel = '';

  final createdLabel = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Nova label'),
      content: TextField(
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Nome da label',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => draftLabel = value,
        onSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(draftLabel),
          child: const Text('Criar'),
        ),
      ],
    ),
  );

  final normalized = normalizeLabelInput(createdLabel ?? '');
  if (normalized == null) {
    return;
  }

  try {
    await ref.read(labelsCatalogProvider.notifier).addLabel(normalized);
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

Future<void> _promptRenameLabel(
  BuildContext context,
  WidgetRef ref,
  String currentLabel,
) async {
  String draftLabel = currentLabel;

  final renamedLabel = await showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Renomear label'),
      content: TextFormField(
        initialValue: currentLabel,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(
          labelText: 'Novo nome',
          border: OutlineInputBorder(),
        ),
        onChanged: (value) => draftLabel = value,
        onFieldSubmitted: (value) => Navigator.of(context).pop(value),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(draftLabel),
          child: const Text('Salvar'),
        ),
      ],
    ),
  );

  final normalized = normalizeLabelInput(renamedLabel ?? '');
  if (normalized == null) {
    return;
  }

  try {
    final savedLabel =
        await ref.read(labelsCatalogProvider.notifier).renameLabel(
              currentName: currentLabel,
              newName: normalized,
            );
    if (savedLabel != null && ref.read(selectedLabelProvider) == currentLabel) {
      ref.read(selectedLabelProvider.notifier).state = savedLabel;
    }
    await ref.read(notesControllerProvider.notifier).refresh();
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

Future<void> _confirmDeleteLabel(
  BuildContext context,
  WidgetRef ref,
  String label,
) async {
  final shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Excluir label'),
      content: Text(
        'Excluir "$label" e remover essa label de todas as notas?',
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );

  if (shouldDelete != true) {
    return;
  }

  try {
    await ref.read(labelsCatalogProvider.notifier).deleteLabel(label);
    if (ref.read(selectedLabelProvider) == label) {
      ref.read(selectedLabelProvider.notifier).state = null;
    }
    await ref.read(notesControllerProvider.notifier).refresh();
  } catch (error) {
    if (!context.mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error.toString())),
    );
  }
}

Future<void> _moveNoteToLabel(
  WidgetRef ref,
  _NoteDragPayload payload,
  String targetLabel,
) async {
  final nextLabels = payload.note.labels.toSet();

  if (payload.sourceLabel != null && payload.sourceLabel != targetLabel) {
    nextLabels.remove(payload.sourceLabel);
  }

  nextLabels.add(targetLabel);
  final sortedLabels = nextLabels.toList(growable: false)..sort();

  if (_sameLabels(payload.note.labels, sortedLabels)) {
    return;
  }

  await ref.read(notesControllerProvider.notifier).saveNote(
        payload.note.copyWith(
          labels: sortedLabels,
          updatedAt: DateTime.now(),
        ),
      );
}

bool _sameLabels(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }

  final sortedLeft = List<String>.of(left)..sort();
  final sortedRight = List<String>.of(right)..sort();

  for (var index = 0; index < sortedLeft.length; index++) {
    if (sortedLeft[index] != sortedRight[index]) {
      return false;
    }
  }

  return true;
}

List<String> _collectLabels(
  List<Note> notes, {
  List<String> catalogLabels = const <String>[],
}) {
  final labels = notes
      .expand((note) => note.labels)
      .map((label) => label.trim())
      .where((label) => label.isNotEmpty)
      .followedBy(
        catalogLabels
            .map((label) => label.trim())
            .where((label) => label.isNotEmpty),
      )
      .toSet()
      .toList(growable: false)
    ..sort();

  return labels;
}

class _NoteDragPayload {
  const _NoteDragPayload({
    required this.note,
    required this.sourceLabel,
  });

  final Note note;
  final String? sourceLabel;
}

enum _EditorAction {
  save,
  delete,
}

class _NoteEditorResult {
  const _NoteEditorResult.save(this.note) : action = _EditorAction.save;

  const _NoteEditorResult.delete()
      : action = _EditorAction.delete,
        note = null;

  final _EditorAction action;
  final Note? note;
}

class _NoteEditorSheet extends ConsumerStatefulWidget {
  const _NoteEditorSheet({this.initialNote});

  final Note? initialNote;

  @override
  ConsumerState<_NoteEditorSheet> createState() => _NoteEditorSheetState();
}

class _NoteEditorSheetState extends ConsumerState<_NoteEditorSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  late final TextEditingController _labelsController;
  late final FocusNode _labelsFocusNode;
  late Color _selectedColor;
  late bool _isPinned;
  late List<String> _selectedLabels;
  bool _isSyncingLabelInput = false;
  int _highlightedSuggestionIndex = -1;
  late final KeyEventCallback _labelsKeyHandler;

  @override
  void initState() {
    super.initState();
    final note = widget.initialNote;
    _titleController = TextEditingController(text: note?.title ?? '');
    _contentController = TextEditingController(text: note?.content ?? '');
    _labelsController = TextEditingController();
    _labelsFocusNode = FocusNode();
    _selectedLabels = List<String>.from(note?.labels ?? const <String>[])
      ..sort();
    _selectedColor = note?.backgroundColor ?? AppColors.pureWhite;
    _isPinned = note?.isPinned ?? false;
    _labelsKeyHandler = _handleGlobalLabelsKeyEvent;
    HardwareKeyboard.instance.addHandler(_labelsKeyHandler);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _labelsController.dispose();
    _labelsFocusNode.dispose();
    HardwareKeyboard.instance.removeHandler(_labelsKeyHandler);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final catalogLabels =
        ref.watch(labelsCatalogProvider).valueOrNull ?? const <String>[];

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.pureWhite,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const <BoxShadow>[
            BoxShadow(
              color: AppColors.shadowBlue,
              blurRadius: 30,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Text(
                      widget.initialNote == null ? 'Nova nota' : 'Editar nota',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: AppColors.ink,
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const Spacer(),
                    if (widget.initialNote?.id != null)
                      IconButton(
                        onPressed: () {
                          Navigator.of(context)
                              .pop(const _NoteEditorResult.delete());
                        },
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _titleController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Titulo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  minLines: 4,
                  maxLines: 8,
                  decoration: const InputDecoration(
                    labelText: 'Conteudo',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                _LabelsChipEditor(
                  controller: _labelsController,
                  focusNode: _labelsFocusNode,
                  selectedLabels: _selectedLabels,
                  suggestions: _matchingCatalogLabels(catalogLabels),
                  highlightedSuggestionIndex: _highlightedSuggestionIndex,
                  onChanged: _handleLabelInputChanged,
                  onRemoveLabel: _removeLabelChip,
                  onSelectSuggestion: _selectSuggestedLabel,
                  onSubmitCurrentInput: _commitCurrentLabelDraft,
                  onMoveSuggestionHighlight: _moveSuggestionHighlight,
                ),
                const SizedBox(height: 16),
                Text(
                  'Cor da nota',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: AppColors.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 10),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: _openColorPicker,
                  child: Ink(
                    decoration: BoxDecoration(
                      color: AppColors.mist,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: <Widget>[
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 140),
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppColors.electricBlue,
                                width: 1.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              '#${_selectedColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          Text(
                            'Escolher',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.electricBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.palette_outlined,
                            color: AppColors.electricBlue,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _isPinned,
                  onChanged: (value) => setState(() => _isPinned = value),
                  title: const Text('Fixar no topo'),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Salvar nota'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _save() {
    final initialNote = widget.initialNote;
    _commitCurrentLabelDraft();
    final labels = _selectedLabels.toSet().toList(growable: false);
    labels.sort();
    final now = DateTime.now();

    final note = (initialNote ?? Note.create()).copyWith(
      title: _titleController.text.trim(),
      content: _contentController.text.trim(),
      backgroundColor: _selectedColor,
      labels: labels,
      isPinned: _isPinned,
      createdAt: initialNote?.createdAt ?? now,
      updatedAt: now,
    );

    Navigator.of(context).pop(_NoteEditorResult.save(note));
  }

  Future<void> _openColorPicker() async {
    Color draftColor = _selectedColor;

    final pickedColor = await showDialog<Color>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Selecionar cor'),
          content: SizedBox(
            width: 320,
            child: StatefulBuilder(
              builder: (context, setDialogState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: draftColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.electricBlue),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '#${draftColor.value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ColorPicker(
                      pickerColor: draftColor,
                      onColorChanged: (color) {
                        setDialogState(() => draftColor = color);
                      },
                      enableAlpha: false,
                      portraitOnly: true,
                      hexInputBar: true,
                      labelTypes: const [
                        ColorLabelType.hex,
                        ColorLabelType.rgb,
                      ],
                      pickerAreaBorderRadius: BorderRadius.circular(16),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(draftColor),
              child: const Text('Aplicar'),
            ),
          ],
        );
      },
    );

    if (pickedColor != null) {
      setState(() => _selectedColor = pickedColor);
    }
  }

  List<String> _matchingCatalogLabels(List<String> catalogLabels) {
    final draft = _normalizedSearchText(_labelsController.text.trim());
    if (draft.isEmpty) {
      return const <String>[];
    }

    final selected = _selectedLabels.toSet();
    return catalogLabels
        .where(
          (label) =>
              _normalizedSearchText(label).contains(draft) &&
              !selected.contains(label),
        )
        .toList(growable: false);
  }

  void _handleLabelInputChanged(String value) {
    if (_isSyncingLabelInput) {
      return;
    }

    if (value.contains(',')) {
      final parts = value.split(',');
      final complete = parts.take(parts.length - 1);
      for (final part in complete) {
        _addLabelChip(part);
      }

      _syncLabelInput(parts.isEmpty ? '' : parts.last.trimLeft());
      return;
    }

    _resetSuggestionHighlight();
  }

  void _commitCurrentLabelDraft() {
    final draft = _labelsController.text.trim();
    if (draft.isEmpty) {
      return;
    }

    final suggestions = _matchingCatalogLabels(
      ref.read(labelsCatalogProvider).valueOrNull ?? const <String>[],
    );
    if (_highlightedSuggestionIndex >= 0 &&
        _highlightedSuggestionIndex < suggestions.length) {
      _selectSuggestedLabel(suggestions[_highlightedSuggestionIndex]);
      return;
    }

    _addLabelChip(draft);
    _syncLabelInput('');
  }

  void _addLabelChip(String rawLabel) {
    final normalized = normalizeLabelInput(rawLabel);
    if (normalized == null || _selectedLabels.contains(normalized)) {
      return;
    }

    final nextLabels = List<String>.from(_selectedLabels)..add(normalized);
    nextLabels.sort();
    setState(() {
      _selectedLabels = nextLabels;
      _highlightedSuggestionIndex = -1;
    });
  }

  void _removeLabelChip(String label) {
    setState(() {
      _selectedLabels = _selectedLabels
          .where((item) => item != label)
          .toList(growable: false);
      _highlightedSuggestionIndex = -1;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _labelsFocusNode.requestFocus();
      }
    });
  }

  void _selectSuggestedLabel(String label) {
    _addLabelChip(label);
    _syncLabelInput('');
  }

  void _moveSuggestionHighlight(int delta) {
    final suggestions = _matchingCatalogLabels(
      ref.read(labelsCatalogProvider).valueOrNull ?? const <String>[],
    );
    if (suggestions.isEmpty) {
      setState(() => _highlightedSuggestionIndex = -1);
      return;
    }

    setState(() {
      final nextIndex = _highlightedSuggestionIndex + delta;
      if (nextIndex < 0) {
        _highlightedSuggestionIndex = suggestions.length - 1;
      } else if (nextIndex >= suggestions.length) {
        _highlightedSuggestionIndex = 0;
      } else {
        _highlightedSuggestionIndex = nextIndex;
      }
    });
  }

  void _resetSuggestionHighlight() {
    final hasSuggestions = _matchingCatalogLabels(
      ref.read(labelsCatalogProvider).valueOrNull ?? const <String>[],
    ).isNotEmpty;

    setState(() {
      _highlightedSuggestionIndex = hasSuggestions ? 0 : -1;
    });
  }

  void _syncLabelInput(String value) {
    _isSyncingLabelInput = true;
    _labelsController
      ..text = value
      ..selection = TextSelection.collapsed(offset: value.length);
    _isSyncingLabelInput = false;
    _resetSuggestionHighlight();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _labelsFocusNode.requestFocus();
      }
    });
  }

  bool _handleGlobalLabelsKeyEvent(KeyEvent event) {
    if (!_labelsFocusNode.hasFocus || event is! KeyDownEvent) {
      return false;
    }

    final suggestions = _matchingCatalogLabels(
      ref.read(labelsCatalogProvider).valueOrNull ?? const <String>[],
    );

    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        suggestions.isNotEmpty) {
      _moveSuggestionHighlight(1);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        suggestions.isNotEmpty) {
      _moveSuggestionHighlight(-1);
      return true;
    }

    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _commitCurrentLabelDraft();
      return true;
    }

    return false;
  }
}

String _normalizedSearchText(String value) {
  const accentMap = <String, String>{
    'a': 'a',
    'á': 'a',
    'à': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'A': 'a',
    'Á': 'a',
    'À': 'a',
    'Â': 'a',
    'Ã': 'a',
    'Ä': 'a',
    'Å': 'a',
    'e': 'e',
    'é': 'e',
    'è': 'e',
    'ê': 'e',
    'ẽ': 'e',
    'ë': 'e',
    'E': 'e',
    'É': 'e',
    'È': 'e',
    'Ê': 'e',
    'Ẽ': 'e',
    'Ë': 'e',
    'i': 'i',
    'í': 'i',
    'ì': 'i',
    'î': 'i',
    'ĩ': 'i',
    'ï': 'i',
    'I': 'i',
    'Í': 'i',
    'Ì': 'i',
    'Î': 'i',
    'Ĩ': 'i',
    'Ï': 'i',
    'o': 'o',
    'ó': 'o',
    'ò': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'O': 'o',
    'Ó': 'o',
    'Ò': 'o',
    'Ô': 'o',
    'Õ': 'o',
    'Ö': 'o',
    'u': 'u',
    'ú': 'u',
    'ù': 'u',
    'û': 'u',
    'ũ': 'u',
    'ü': 'u',
    'U': 'u',
    'Ú': 'u',
    'Ù': 'u',
    'Û': 'u',
    'Ũ': 'u',
    'Ü': 'u',
    'c': 'c',
    'ç': 'c',
    'C': 'c',
    'Ç': 'c',
    'n': 'n',
    'ñ': 'n',
    'N': 'n',
    'Ñ': 'n',
    'y': 'y',
    'ý': 'y',
    'ÿ': 'y',
    'Y': 'y',
    'Ý': 'y',
  };

  final buffer = StringBuffer();
  for (final rune in value.runes) {
    final char = String.fromCharCode(rune);
    buffer.write(accentMap[char] ?? char.toLowerCase());
  }

  return buffer.toString().toLowerCase();
}

class _LabelsChipEditor extends StatelessWidget {
  const _LabelsChipEditor({
    required this.controller,
    required this.focusNode,
    required this.selectedLabels,
    required this.suggestions,
    required this.highlightedSuggestionIndex,
    required this.onChanged,
    required this.onRemoveLabel,
    required this.onSelectSuggestion,
    required this.onSubmitCurrentInput,
    required this.onMoveSuggestionHighlight,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final List<String> selectedLabels;
  final List<String> suggestions;
  final int highlightedSuggestionIndex;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onRemoveLabel;
  final ValueChanged<String> onSelectSuggestion;
  final VoidCallback onSubmitCurrentInput;
  final ValueChanged<int> onMoveSuggestionHighlight;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.pureWhite,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.divider),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Labels',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.ink,
                      ),
                ),
                if (selectedLabels.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: selectedLabels
                        .map(
                          (label) => InputChip(
                            label: Text(label),
                            selected: true,
                            showCheckmark: false,
                            onDeleted: () => onRemoveLabel(label),
                            deleteIconColor: AppColors.electricBlue,
                            backgroundColor: AppColors.mist,
                            selectedColor:
                                AppColors.electricBlue.withValues(alpha: 0.16),
                            side: const BorderSide(
                              color: AppColors.electricBlue,
                            ),
                            labelStyle: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppColors.electricBlue,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: controller,
                  focusNode: focusNode,
                  decoration: const InputDecoration(
                    hintText: 'Digite uma label e pressione Enter',
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: onChanged,
                  onSubmitted: (_) => onSubmitCurrentInput(),
                ),
              ],
            ),
          ),
        ),
        if (suggestions.isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              color: AppColors.pureWhite,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const <BoxShadow>[
                BoxShadow(
                  color: AppColors.shadowBlue,
                  blurRadius: 18,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 220),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: suggestions.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: AppColors.divider),
                itemBuilder: (context, index) {
                  final suggestion = suggestions[index];
                  final isHighlighted = highlightedSuggestionIndex == index;

                  return ListTile(
                    dense: true,
                    tileColor: isHighlighted
                        ? AppColors.electricBlue.withValues(alpha: 0.22)
                        : null,
                    leading: Icon(
                      Icons.subdirectory_arrow_right_rounded,
                      size: 18,
                      color: isHighlighted
                          ? AppColors.electricBlue
                          : Colors.transparent,
                    ),
                    title: Text(
                      suggestion,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isHighlighted
                                ? AppColors.electricBlue
                                : AppColors.ink,
                            fontWeight: isHighlighted
                                ? FontWeight.w800
                                : FontWeight.w500,
                          ),
                    ),
                    onTap: () => onSelectSuggestion(suggestion),
                  );
                },
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _HeaderDelegate extends SliverPersistentHeaderDelegate {
  const _HeaderDelegate();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.mist.withValues(alpha: 0.96),
        border: const Border(
          bottom: BorderSide(color: AppColors.divider),
        ),
      ),
      child: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              'logo_original_ajustada.png',
              height: 42,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }

  @override
  double get maxExtent => 108;

  @override
  double get minExtent => 108;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return false;
  }
}
