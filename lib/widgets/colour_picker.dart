import 'package:flutter/material.dart';
import '../theme.dart';
import '../settings.dart';

class LoreColourPicker extends StatefulWidget {
  final Color current;
  final void Function(Color) onPicked;
  
  const LoreColourPicker({
    super.key,
    required this.current,
    required this.onPicked,
  });

  /// Helper to show it as a bottom sheet
  static void show(BuildContext context, {
    required Color current,
    required void Function(Color) onPicked,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => LoreColourPicker(
        current: current,
        onPicked: onPicked,
      ),
    );
  }

  @override
  State<LoreColourPicker> createState() => _LoreColourPickerState();
}

class _LoreColourPickerState extends State<LoreColourPicker> {
  late Color _picked;
  late TextEditingController _hexCtrl;

  double _hue = 0;
  double _sat = 1;
  double _val = 1;

  final List<Color> _quickPicks = [
    cParchment, cGold, cIce, cEmber, cMagic, cVine, Colors.white,
  ];

  @override
  void initState() {
    super.initState();
    _picked = widget.current;
    final hexString = _picked.toARGB32().toRadixString(16).padLeft(8, '0');
    _hexCtrl = TextEditingController(
      text: hexString.substring(2).toUpperCase(),
    );
    
    final hsv = HSVColor.fromColor(_picked);
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  void _updateHSV({double? h, double? s, double? v}) {
    setState(() {
      _hue = h ?? _hue;
      _sat = s ?? _sat;
      _val = v ?? _val;
      _picked = HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();
      final hexString = _picked.toARGB32().toRadixString(16).padLeft(8, '0');
      _hexCtrl.text = hexString.substring(2).toUpperCase();
    });
  }

  void _updateFromHex(String val) {
    if (val.length == 6) {
      try {
        final newColor = Color(int.parse('FF$val', radix: 16));
        setState(() {
          _picked = newColor;
          final hsv = HSVColor.fromColor(_picked);
          _hue = hsv.hue;
          _sat = hsv.saturation;
          _val = hsv.value;
        });
      } catch (_) {}
    }
  }

  Widget _buildSlider({
    required String label,
    required List<Color> colors,
    required double value, // 0.0 to 1.0
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(
            fontFamily: 'monospace', fontSize: 9, 
            color: cSmoke, letterSpacing: 2)),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            return GestureDetector(
              onHorizontalDragUpdate: (details) {
                final percent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                onChanged(percent);
              },
              onHorizontalDragStart: (details) {
                final percent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                onChanged(percent);
              },
              onTapDown: (details) {
                final percent = (details.localPosition.dx / constraints.maxWidth).clamp(0.0, 1.0);
                onChanged(percent);
              },
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  gradient: LinearGradient(colors: colors),
                  border: Border.all(color: cAsh),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: (value * constraints.maxWidth) - 8,
                      top: 0, bottom: 0,
                      child: Center(
                        child: Container(
                          width: 16, height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.transparent,
                            border: Border.all(color: Colors.white, width: 2),
                            boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 2)],
                          ),
                        ),
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

    Widget _buildValueSlider({
    required String label,
    required String valueLabel,
    required double value,
    required double min,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cSmoke,
                    letterSpacing: 2)),
            const Spacer(),
            Text(valueLabel,
                style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 9,
                    color: cGold,
                    letterSpacing: 1)),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: cGold,
            inactiveTrackColor: cAsh,
            thumbColor: cParchment,
            overlayColor: cGold.withValues(alpha: 0.2),
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
          ),
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: (v) {
              onChanged(v);
              setState(() {});
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Material(
          color: cInk,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 32, height: 3,
                  decoration: BoxDecoration(color: cAsh,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 16),
              const Text('PICK COLOUR', style: TextStyle(
                  fontFamily: 'monospace', fontSize: 9,
                  color: cGold, letterSpacing: 4)),
              const SizedBox(height: 24),
              
              Row(children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: _picked,
                    shape: BoxShape.circle,
                    border: Border.all(color: cAsh),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(children: [
                    const Text('#', style: TextStyle(
                        fontFamily: 'monospace', fontSize: 20, color: cGold)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _hexCtrl,
                        style: const TextStyle(fontFamily: 'monospace', fontSize: 18, color: cParchment, letterSpacing: 2),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'FFFFFF',
                          hintStyle: TextStyle(color: cAsh, letterSpacing: 2),
                          border: InputBorder.none,
                        ),
                        onChanged: _updateFromHex,
                      ),
                    ),
                  ]),
                ),
              ]),
              
              const SizedBox(height: 24),
              
              Wrap(
                spacing: 8,
                children: _quickPicks.map((c) {
                  final isSelected = _picked.toARGB32() == c.toARGB32();
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _picked = c;
                        _hexCtrl.text = c.toARGB32().toRadixString(16).substring(2).toUpperCase();
                        final hsv = HSVColor.fromColor(_picked);
                        _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value;
                      });
                    },
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: c, shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.white : Colors.transparent, width: 2),
                      ),
                    ),
                  );
                }).toList(),
              ),
              
              const SizedBox(height: 24),
              
              _buildSlider(
                label: 'HUE',
                colors: const [
                  Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                  Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000)
                ],
                value: _hue / 360.0,
                onChanged: (v) => _updateHSV(h: v * 360.0),
              ),
              const SizedBox(height: 16),
              _buildSlider(
                label: 'SATURATION',
                colors: [
                  HSVColor.fromAHSV(1.0, _hue, 0.0, _val).toColor(),
                  HSVColor.fromAHSV(1.0, _hue, 1.0, _val).toColor(),
                ],
                value: _sat,
                onChanged: (v) => _updateHSV(s: v),
              ),
              const SizedBox(height: 16),
              _buildSlider(
                label: 'BRIGHTNESS',
                colors: [
                  HSVColor.fromAHSV(1.0, _hue, _sat, 0.0).toColor(),
                  HSVColor.fromAHSV(1.0, _hue, _sat, 1.0).toColor(),
                ],
                value: _val,
                onChanged: (v) => _updateHSV(v: v),
              ),
              
                            const SizedBox(height: 24),
              Container(height: 1, color: cAsh.withValues(alpha: 0.4)),
              const SizedBox(height: 16),
              const Text('ANIMATED BORDER',
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 9,
                      color: cGold,
                      letterSpacing: 4)),
              const SizedBox(height: 16),
              _buildValueSlider(
                label: 'THICKNESS',
                valueLabel: appSettings.animatedBorderThickness.toStringAsFixed(1),
                value: appSettings.animatedBorderThickness,
                min: 1,
                max: 8,
                onChanged: (v) => appSettings.setAnimatedBorderThickness(v),
              ),
              _buildValueSlider(
                label: 'WAVINESS',
                valueLabel: appSettings.animatedBorderWaviness.toStringAsFixed(1),
                value: appSettings.animatedBorderWaviness,
                min: 0,
                max: 12,
                onChanged: (v) => appSettings.setAnimatedBorderWaviness(v),
              ),
              _buildValueSlider(
                label: 'SPEED',
                valueLabel: '${appSettings.animatedBorderSpeed.toStringAsFixed(1)}x',
                value: appSettings.animatedBorderSpeed,
                min: 0.3,
                max: 2.5,
                onChanged: (v) => appSettings.setAnimatedBorderSpeed(v),
              ),
              _buildValueSlider(
                label: 'OPACITY',
                valueLabel:
                    '${(appSettings.animatedBorderOpacity * 100).round()}%',
                value: appSettings.animatedBorderOpacity,
                min: 0.3,
                max: 1.0,
                onChanged: (v) => appSettings.setAnimatedBorderOpacity(v),
              ),
              const SizedBox(height: 24),

                            GestureDetector(
                onTap: () {
                  widget.onPicked(_picked);
                  Navigator.pop(context);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  color: cParchment,
                  child: const Center(
                    child: Text('Use this colour',
                        style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            color: cVoid,
                            letterSpacing: 2))),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}