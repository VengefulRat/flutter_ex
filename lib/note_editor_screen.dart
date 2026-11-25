import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../theme.dart';
import '../settings.dart';
import 'models/world.dart';

class NoteEditorResult {
  final RPNote? note;
  final bool deleted;
  const NoteEditorResult.saved(RPNote this.note) : deleted = false;
  const NoteEditorResult.deleted() : note = null, deleted = true;
}

class NoteEditorScreen extends StatefulWidget {
  final RPNote? note;
  const NoteEditorScreen({super.key, this.note});
  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final quill.QuillController _ctrl;
  final _focus = FocusNode();
  final _scroll = ScrollController();
  String? _tag;
  static const _tags = ['NPC', 'Location', 'Item', 'Plot', 'Other'];

  @override
  void initState() {
    super.initState();
    _tag = widget.note?.tag;
    _ctrl = quill.QuillController(
      document: _documentFrom(widget.note),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  quill.Document _documentFrom(RPNote? note) {
    if (note == null) return quill.Document();
    if (note.contentDelta != null && note.contentDelta!.isNotEmpty) {
      try {
        final json = jsonDecode(note.contentDelta!);
        if (json is List) return quill.Document.fromJson(json);
      } catch (_) {/* fall through to plain text */}
    }
    final doc = quill.Document();
    if (note.content.isNotEmpty) doc.insert(0, note.content);
    return doc;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _save() {
    final plain = _ctrl.document.toPlainText().trim();
    if (plain.isEmpty) {
      Navigator.pop(context); // empty new note — just close
      return;
    }
    final delta = jsonEncode(_ctrl.document.toDelta().toJson());
    Navigator.pop(
      context,
      NoteEditorResult.saved(RPNote(
        id: widget.note?.id ??
            DateTime.now().millisecondsSinceEpoch.toString(),
        content: plain,
        contentDelta: delta,
        tag: _tag,
        isPinned: widget.note?.isPinned ?? false,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cInk,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: const Icon(Icons.close, color: cSmoke, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.note == null ? 'NEW NOTE' : 'EDIT NOTE',
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: cGold,
                      letterSpacing: 3,
                    ),
                  ),
                  const Spacer(),
                  if (widget.note != null)
                    GestureDetector(
                      onTap: () => Navigator.pop(
                          context, const NoteEditorResult.deleted()),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child:
                            Icon(Icons.delete_outline, color: cEmber, size: 18),
                      ),
                    ),
                  GestureDetector(
                    onTap: _save,
                    child: const Text(
                      'Save',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: cGold,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(color: cAsh, height: 1),

            // ── Tag row ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _tagChip(null, 'No tag'),
                    ..._tags.map((t) => _tagChip(t, t)),
                  ],
                ),
              ),
            ),

            // ── Toolbar (per-selection formatting lives here) ──
            Container(
              color: cVoid,
              child: quill.QuillSimpleToolbar(
                controller: _ctrl,
                config: const quill.QuillSimpleToolbarConfig(
                  multiRowsDisplay: false,
                  showFontFamily: true,
                  showFontSize: true,
                  showBoldButton: true,
                  showItalicButton: true,
                  showUnderLineButton: true,
                  showStrikeThrough: true,
                  showColorButton: true,
                  showBackgroundColorButton: true,
                  showListNumbers: true,
                  showListBullets: true,
                  showQuote: true,
                  showClearFormat: true,
                  showUndo: true,
                  showRedo: true,
                  // hide what you don't want
                  showHeaderStyle: false,
                  showSearchButton: false,
                  showSubscript: false,
                  showSuperscript: false,
                  showInlineCode: false,
                  showCodeBlock: false,
                  showLink: false,
                  showIndent: false,
                  showAlignmentButtons: false,
                  showListCheck: false,
                ),
              ),
            ),
            const Divider(color: cAsh, height: 1),

            // ── Editor ──
            Expanded(
              child: quill.QuillEditor.basic(
                controller: _ctrl,
                focusNode: _focus,
                scrollController: _scroll,
                config: quill.QuillEditorConfig(
                  autoFocus: true,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  placeholder: 'What do you want to remember?',
                  customStyles: quill.DefaultStyles(
                    paragraph: quill.DefaultTextBlockStyle(
                      TextStyle(
                        fontSize: appSettings.baseFontSize,
                        color: cParchment,
                        height: 1.7,
                      ),
                      const quill.HorizontalSpacing(0, 0),
                      const quill.VerticalSpacing(0, 0),
                      const quill.VerticalSpacing(0, 0),
                      null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tagChip(String? tag, String label) {
    final active = _tag == tag;
    return GestureDetector(
      onTap: () => setState(() => _tag = tag),
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          border: Border.all(color: active ? cGold : cAsh),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: 8,
            letterSpacing: 1,
            color: active ? cGold : cSmoke,
          ),
        ),
      ),
    );
  }
}