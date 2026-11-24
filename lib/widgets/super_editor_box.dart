import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class EditorRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final int color;
  final double size;
  const EditorRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    required this.color,
    required this.size,
  });
}

class SuperEditorBox extends StatefulWidget {
  final String initialText;
  final Color characterColor;
  final String characterName;
  final List<EditorRun>? initialRuns;
  final void Function(List<EditorRun> runs, String plain) onPost;
  final void Function(String plain)? onChanged;
  final void Function(List<EditorRun> runs)? onRunsChanged;
  const SuperEditorBox({
    super.key,
    this.initialText = '',
    required this.characterColor,
    this.characterName = '',
    this.initialRuns,
    required this.onPost,
    this.onChanged,
    this.onRunsChanged,
  });
  @override
  State<SuperEditorBox> createState() => SuperEditorBoxState();
}

class SuperEditorBoxState extends State<SuperEditorBox> {
  late final MutableDocument _doc;
  late final MutableDocumentComposer _composer;
  late final Editor _editor;
  late final DocumentChangeListener _docListener;
  final FocusNode _focus = FocusNode();
  bool _bold = false;
  bool _italic = false;
  bool _underline = false;
  double _fontSize = 16;
  int _nodeCounter = 0;
  late Color _fontColor;
  final List<Color> _palette = const [
    Colors.white,
    Colors.black,
    Color(0xFFFFD166),
    Color(0xFFFF6B6B),
    Color(0xFF6BCB77),
    Color(0xFF4D96FF),
    Color(0xFFFF9F45),
    Color(0xFFB983FF),
    Color(0xFFFF6FB5),
    Color(0xFF00C2A8),
  ];
  String _newNodeId() {
    _nodeCounter++;
    return 'node_${_nodeCounter}_${DateTime.now().microsecondsSinceEpoch}';
  }

  @override
  void initState() {
    super.initState();
    _fontColor = Colors.white;
    _doc = MutableDocument(
      nodes: [
        ParagraphNode(
          id: _newNodeId(),
          text: AttributedText(widget.initialText),
        ),
      ],
    );
    _composer = MutableDocumentComposer();
    _editor = createDefaultDocumentEditor(document: _doc, composer: _composer);
    // Edit mode: re-apply saved runs (colour/size/bold/italic/underline)
    final initRuns = widget.initialRuns;
    if (initRuns != null && initRuns.isNotEmpty) {
      final firstNode = _doc.first;
      if (firstNode is TextNode) {
        var offset = 0;
        for (final r in initRuns) {
          final start = offset;
          final end = offset + r.text.length;
          offset = end;
          final attrs = <Attribution>{};
          if (r.bold) attrs.add(boldAttribution);
          if (r.italic) attrs.add(italicsAttribution);
          if (r.underline) attrs.add(underlineAttribution);
          attrs.add(ColorAttribution(Color(r.color)));
          attrs.add(FontSizeAttribution(r.size));
          if (attrs.isNotEmpty && end > start) {
            _editor.execute([
              AddTextAttributionsRequest(
                documentRange: DocumentRange(
                  start: DocumentPosition(
                    nodeId: firstNode.id,
                    nodePosition: TextNodePosition(offset: start),
                  ),
                  end: DocumentPosition(
                    nodeId: firstNode.id,
                    nodePosition: TextNodePosition(offset: end),
                  ),
                ),
                attributions: attrs,
              ),
            ]);
          }
        }
      }
    }
    _docListener = (_) {
      // SuperEditor renders text with NO ColorAttribution as black.
      // Stamp the default colour onto uncoloured text so typing shows white, not black.
      widget.onChanged?.call(plainText);
      widget.onRunsChanged?.call(runs);
      if (mounted) setState(() {});
    };
    _doc.addListener(_docListener);
  }

  @override
  void dispose() {
    _doc.removeListener(_docListener);
    _editor.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get plainText => _doc.toPlainText();
  List<EditorRun> get runs {
    final out = <EditorRun>[];
    for (final node in _doc) {
      if (node is! TextNode) continue;
      final attributed = node.text;
      final plain = attributed.toPlainText();
      if (plain.isEmpty) continue;
      // Build per-character attribution sets from spans, then group runs
      final perChar = List<Set<Attribution>>.generate(plain.length, (_) => <Attribution>{});
      for (final span in attributed.computeAttributionSpans()) {
        final start = span.start.clamp(0, plain.length);
        final end = span.end.clamp(0, plain.length - 1);
        for (var k = start; k <= end; k++) {
          perChar[k].addAll(span.attributions);
        }
      }
      var i = 0;
      while (i < plain.length) {
        final attrs = perChar[i];
        var j = i + 1;
        while (j < plain.length && _sameStyle(perChar[j], attrs)) {
          j++;
        }
        final runText = plain.substring(i, j);
        bool b = false, it = false, u = false;
        Color? c;
        double? s;
        for (final a in attrs) {
          if (a == boldAttribution) b = true;
          if (a == italicsAttribution) it = true;
          if (a == underlineAttribution) u = true;
          if (a is ColorAttribution) c = a.color;
          if (a is FontSizeAttribution) s = a.fontSize;
        }
        out.add(EditorRun(
          text: runText,
          bold: b,
          italic: it,
          underline: u,
          color: (c ?? _fontColor).toARGB32(),
          size: s ?? _fontSize,
        ));
        i = j;
      }
    }
    return out;
  }

  bool _sameStyle(Set<Attribution> a, Set<Attribution> b) {
    if (a.length != b.length) return false;
    return a.every((x) => b.contains(x));
  }

  void _applyToggle(Attribution attr) {
    final sel = _composer.selection;
    if (sel == null) return;
    if (sel.isCollapsed) {
      _composer.preferences.toggleStyles({attr});
    } else {
      _editor.execute([
        ToggleTextAttributionsRequest(documentRange: sel, attributions: {attr}),
      ]);
    }
    _focus.requestFocus();
  }

  void _toggleBold() {
    setState(() => _bold = !_bold);
    _applyToggle(boldAttribution);
  }

  void _toggleItalic() {
    setState(() => _italic = !_italic);
    _applyToggle(italicsAttribution);
  }

  void _toggleUnderline() {
    setState(() => _underline = !_underline);
    _applyToggle(underlineAttribution);
  }

  void _applyValueAttribution(Attribution next, bool Function(Attribution) isSameKind) {
    final sel = _composer.selection;
    if (sel == null) return;
    if (sel.isCollapsed) {
      // Caret: remove old attributions of this kind from preferences, add new one
      final prefs = _composer.preferences;
      final toRemove = prefs.currentAttributions.where(isSameKind).toList();
      for (final old in toRemove) {
        prefs.removeStyle(old);
      }
      prefs.addStyle(next);
    } else {
      // Selection: remove old attributions of this kind in range, then add new one
      final existing = <Attribution>{};
      final targetNode = _doc.getNodeById(sel.base.nodeId);
      final List<MultiAttributionSpan> targetSpans = [];
      if (targetNode is TextNode) {
        targetSpans.addAll(targetNode.text.computeAttributionSpans());
      }
      for (final span in targetSpans) {
        for (final a in span.attributions) {
          if (isSameKind(a)) existing.add(a);
        }
      }
      if (existing.isNotEmpty) {
        _editor.execute([
          RemoveTextAttributionsRequest(documentRange: sel, attributions: existing),
        ]);
      }
      _editor.execute([
        AddTextAttributionsRequest(documentRange: sel, attributions: {next}),
      ]);
    }
    _focus.requestFocus();
  }

  void _changeSize(double delta) {
    setState(() => _fontSize = (_fontSize + delta).clamp(10, 28));
    _applyValueAttribution(
      FontSizeAttribution(_fontSize),
      (a) => a is FontSizeAttribution,
    );
  }

  void _pickColor(Color c) {
    setState(() => _fontColor = c);
    _applyValueAttribution(
      ColorAttribution(c),
      (a) => a is ColorAttribution,
    );
  }

  void clear() {
    _doc.clear();
    final id = _newNodeId();
    _doc.add(ParagraphNode(id: id, text: AttributedText('')));
    _composer.setSelectionWithReason(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: id,
          nodePosition: const TextNodePosition(offset: 0),
        ),
      ),
      SelectionReason.userInteraction,
    );
  }

  void setText(String text) {
    _doc.clear();
    final id = _newNodeId();
    _doc.add(ParagraphNode(id: id, text: AttributedText(text)));
    _composer.setSelectionWithReason(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: id,
          nodePosition: TextNodePosition(offset: text.length),
        ),
      ),
      SelectionReason.userInteraction,
    );
  }

  @override
  Widget build(BuildContext context) {
    final plain = plainText;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            _toolBtn('B', _bold, _toggleBold, bold: true),
            _toolBtn('I', _italic, _toggleItalic, italic: true),
            _toolBtn('U', _underline, _toggleUnderline, underline: true),
            _toolBtn('A-', false, () => _changeSize(-2)),
            _toolBtn('A+', false, () => _changeSize(2)),
            Text(
              '${_fontSize.toInt()}',
              style: const TextStyle(color: Colors.white70),
            ),
            ..._palette.map(
              (c) => GestureDetector(
                onTap: () => _pickColor(c),
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: c,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _fontColor == c ? Colors.white : Colors.white30,
                      width: _fontColor == c ? 2 : 1,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          constraints: const BoxConstraints(minHeight: 80, maxHeight: 180),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A22),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white12),
          ),
          child: SuperEditor(editor: _editor, focusNode: _focus),
        ),
      ],
    );
  }

  Widget _toolBtn(
    String label,
    bool active,
    VoidCallback onTap, {
    bool bold = false,
    bool italic = false,
    bool underline = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: active ? Colors.white24 : Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: Colors.white,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
            decoration: underline
                ? TextDecoration.underline
                : TextDecoration.none,
          ),
        ),
      ),
    );
  }
}
