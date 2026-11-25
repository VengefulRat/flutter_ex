import 'package:flutter/material.dart';
import 'package:super_editor/super_editor.dart';

class EditorRun {
  final String text;
  final bool bold;
  final bool italic;
  final bool underline;
  final int color;
  final double size;
  final String? speaker;

  const EditorRun({
    required this.text,
    this.bold = false,
    this.italic = false,
    this.underline = false,
    required this.color,
    required this.size,
    this.speaker,
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
  final List<_CharacterSection> _sections = [];
  late _CharacterSection _activeSection;

  String get _selectedSpeaker =>
      widget.characterName.isEmpty ? 'Self' : widget.characterName;

  @override
  void initState() {
    super.initState();
    final savedRuns = widget.initialRuns;
    final initialRuns = <EditorRun>[...?savedRuns];
    final savedText = initialRuns.map((run) => run.text).join();
    if (initialRuns.isNotEmpty && savedText == widget.initialText.trim()) {
      final leadingLength =
          widget.initialText.length - widget.initialText.trimLeft().length;
      final trailingStart = leadingLength + savedText.length;
      if (leadingLength > 0) {
        final first = initialRuns.first;
        initialRuns.insert(
          0,
          EditorRun(
            text: widget.initialText.substring(0, leadingLength),
            bold: first.bold,
            italic: first.italic,
            underline: first.underline,
            color: first.color,
            size: first.size,
            speaker: first.speaker,
          ),
        );
      }
      if (trailingStart < widget.initialText.length) {
        final last = initialRuns.last;
        initialRuns.add(
          EditorRun(
            text: widget.initialText.substring(trailingStart),
            bold: last.bold,
            italic: last.italic,
            underline: last.underline,
            color: last.color,
            size: last.size,
            speaker: last.speaker,
          ),
        );
      }
    }
    if (initialRuns.isNotEmpty &&
        initialRuns.map((run) => run.text).join() == widget.initialText) {
      for (final run in initialRuns) {
        final speaker = run.speaker?.trim().isNotEmpty == true
            ? run.speaker!.trim()
            : _selectedSpeaker;
        if (_sections.isEmpty || _sections.last.speaker != speaker) {
          _sections.add(
            _CharacterSection(
              speaker: speaker,
              color: speaker == _selectedSpeaker
                  ? widget.characterColor
                  : Colors.white54,
            ),
          );
        }
        _sections.last.initialRuns.add(run);
      }
    } else {
      _sections.add(
        _CharacterSection(
          speaker: _selectedSpeaker,
          color: widget.characterColor,
          initialText: widget.initialText,
        ),
      );
    }
    _activeSection = _sections.last;
  }

  @override
  void didUpdateWidget(covariant SuperEditorBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldSpeaker = oldWidget.characterName.isEmpty
        ? 'Self'
        : oldWidget.characterName;
    if (_selectedSpeaker != oldSpeaker) {
      final section = _CharacterSection(
        speaker: _selectedSpeaker,
        color: widget.characterColor,
      );
      final index = _sections.indexOf(_activeSection);
      if (_activeSection.key.currentState?.rawText.isEmpty ?? false) {
        _sections[index] = section;
      } else {
        _sections.insert(index + 1, section);
      }
      _activeSection = section;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(_activeSection, section)) {
          section.key.currentState?.requestFocus();
          final sectionContext = section.key.currentContext;
          if (sectionContext != null) {
            Scrollable.ensureVisible(sectionContext);
          }
        }
      });
    }
  }

  String get plainText => _sections
      .map((section) => section.key.currentState?.rawText ?? section.text)
      .join();

  List<EditorRun> get runs {
    final allRuns = <EditorRun>[];
    for (final section in _sections) {
      allRuns.addAll(section.key.currentState?.rawRuns ?? section.initialRuns);
    }
    final text = plainText;
    final start = text.length - text.trimLeft().length;
    final end = start + text.trim().length;
    return _sliceEditorRuns(allRuns, start, end);
  }

  void _notifyChanged() {
    widget.onChanged?.call(plainText);
    widget.onRunsChanged?.call(runs);
  }

  void clear() {
    setState(() {
      _sections
        ..clear()
        ..add(
          _CharacterSection(
            speaker: _selectedSpeaker,
            color: widget.characterColor,
          ),
        );
      _activeSection = _sections.single;
    });
    widget.onChanged?.call('');
    widget.onRunsChanged?.call([]);
  }

  void setText(String text) {
    setState(() {
      _sections
        ..clear()
        ..add(
          _CharacterSection(
            speaker: _selectedSpeaker,
            color: widget.characterColor,
            initialText: text,
          ),
        );
      _activeSection = _sections.single;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _notifyChanged();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 360),
      child: CustomScrollView(
        shrinkWrap: true,
        slivers: [
          for (final section in _sections)
            SliverPadding(
              padding: const EdgeInsets.only(bottom: 8),
              sliver: _CharacterSectionEditor(
                key: section.key,
                initialText: section.text,
                initialRuns: section.initialRuns,
                characterName: section.speaker,
                characterColor: section.color,
                onFocus: () => _activeSection = section,
                onChanged: _notifyChanged,
              ),
            ),
        ],
      ),
    );
  }
}

class _CharacterSection {
  _CharacterSection({
    required this.speaker,
    required this.color,
    this.initialText = '',
  });

  final String speaker;
  final Color color;
  final String initialText;
  final List<EditorRun> initialRuns = [];
  final key = GlobalKey<_CharacterSectionEditorState>();

  String get text =>
      initialRuns.isEmpty ? initialText : initialRuns.map((r) => r.text).join();
}

List<EditorRun> _sliceEditorRuns(List<EditorRun> input, int start, int end) {
  final out = <EditorRun>[];
  var offset = 0;
  for (final run in input) {
    final runEnd = offset + run.text.length;
    final sliceStart = start > offset ? start : offset;
    final sliceEnd = end < runEnd ? end : runEnd;
    if (sliceEnd > sliceStart) {
      out.add(
        EditorRun(
          text: run.text.substring(sliceStart - offset, sliceEnd - offset),
          bold: run.bold,
          italic: run.italic,
          underline: run.underline,
          color: run.color,
          size: run.size,
          speaker: run.speaker,
        ),
      );
    }
    offset = runEnd;
    if (offset >= end) break;
  }
  return out;
}

class _CharacterSectionEditor extends StatefulWidget {
  const _CharacterSectionEditor({
    super.key,
    required this.initialText,
    required this.initialRuns,
    required this.characterName,
    required this.characterColor,
    required this.onFocus,
    required this.onChanged,
  });

  final String initialText;
  final List<EditorRun> initialRuns;
  final String characterName;
  final Color characterColor;
  final VoidCallback onFocus;
  final VoidCallback onChanged;

  @override
  State<_CharacterSectionEditor> createState() =>
      _CharacterSectionEditorState();
}

class _CharacterSectionEditorState extends State<_CharacterSectionEditor> {
  final String _inputRole = UniqueKey().toString();
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
    _focus.addListener(_handleFocus);
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
    // Edit mode: re-apply saved runs (colour/size/bold/italic/underline).
    final initRuns = widget.initialRuns;
    if (initRuns.isNotEmpty) {
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
          if (end > start) {
            for (final attribution in attrs) {
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
                  attributions: {attribution},
                ),
              ]);
            }
          }
        }
      }
    }
    _docListener = (_) {
      widget.onChanged();
      if (mounted) setState(() {});
    };
    _doc.addListener(_docListener);
  }

  @override
  void dispose() {
    _doc.removeListener(_docListener);
    _editor.dispose();
    _focus.removeListener(_handleFocus);
    _focus.dispose();
    super.dispose();
  }

  void _handleFocus() {
    if (_focus.hasFocus) widget.onFocus();
  }

  void requestFocus() {
    final lastNode = _doc.last;
    _composer.setSelectionWithReason(
      DocumentSelection.collapsed(
        position: DocumentPosition(
          nodeId: lastNode.id,
          nodePosition: lastNode.endPosition,
        ),
      ),
      SelectionReason.userInteraction,
    );
    _focus.requestFocus();
  }

  String get rawText => _doc
      .whereType<TextNode>()
      .map((node) => node.text.toPlainText())
      .join('\n');

  List<EditorRun> get rawRuns {
    final out = <EditorRun>[];
    final textNodes = _doc.whereType<TextNode>().toList();
    for (var nodeIndex = 0; nodeIndex < textNodes.length; nodeIndex++) {
      final node = textNodes[nodeIndex];
      final attributed = node.text;
      final plain = attributed.toPlainText();
      if (plain.isEmpty) {
        if (nodeIndex < textNodes.length - 1) {
          out.add(
            EditorRun(
              text: '\n',
              color: _fontColor.toARGB32(),
              size: _fontSize,
              speaker: widget.characterName,
            ),
          );
        }
        continue;
      }
      // Build per-character attribution sets from spans, then group runs
      final perChar = List<Set<Attribution>>.generate(
        plain.length,
        (_) => <Attribution>{},
      );
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
        out.add(
          EditorRun(
            text: runText,
            bold: b,
            italic: it,
            underline: u,
            color: (c ?? Colors.white).toARGB32(),
            size: s ?? _fontSize,
            speaker: widget.characterName,
          ),
        );
        i = j;
      }
      if (nodeIndex < textNodes.length - 1) {
        final previousRun = out.last;
        out.add(
          EditorRun(
            text: '\n',
            bold: previousRun.bold,
            italic: previousRun.italic,
            underline: previousRun.underline,
            color: previousRun.color,
            size: previousRun.size,
            speaker: previousRun.speaker,
          ),
        );
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

  void _applyValueAttribution(
    Attribution next,
    bool Function(Attribution) isSameKind,
  ) {
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
          RemoveTextAttributionsRequest(
            documentRange: sel,
            attributions: existing,
          ),
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
    _applyValueAttribution(ColorAttribution(c), (a) => a is ColorAttribution);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedSliver(
      key: ValueKey('character-section-${widget.characterName}'),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: widget.characterColor.withValues(alpha: 0.6)),
      ),
      sliver: SliverPadding(
        padding: const EdgeInsets.all(10),
        sliver: SliverMainAxisGroup(
          slivers: [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.characterName.toUpperCase(),
                    style: TextStyle(
                      color: widget.characterColor,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      _toolBtn('B', _bold, _toggleBold, bold: true),
                      _toolBtn('I', _italic, _toggleItalic, italic: true),
                      _toolBtn(
                        'U',
                        _underline,
                        _toggleUnderline,
                        underline: true,
                      ),
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
                                color: _fontColor == c
                                    ? Colors.white
                                    : Colors.white30,
                                width: _fontColor == c ? 2 : 1,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              sliver: SuperEditor(
                editor: _editor,
                focusNode: _focus,
                inputRole: _inputRole,
                stylesheet: defaultStylesheet.copyWith(
                  addRulesAfter: [
                    StyleRule(const BlockSelector("paragraph"), (doc, docNode) {
                      return {
                        Styles.padding: const CascadingPadding.only(top: 2),
                      };
                    }),
                  ],
                  inlineTextStyler: (attributions, existingStyle) {
                    TextStyle style = defaultInlineTextStyler(
                      attributions,
                      existingStyle,
                    );

                    style = style.copyWith(
                      color: Colors.white,
                      fontSize: 14,
                      height: 1.35,
                    );

                    for (final attribution in attributions) {
                      if (attribution is ColorAttribution) {
                        style = style.copyWith(color: attribution.color);
                      }
                    }
                    return style;
                  },
                ),
              ),
            ),
          ],
        ),
      ),
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
