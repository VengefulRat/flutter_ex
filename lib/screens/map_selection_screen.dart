import 'package:flutter/material.dart';
import '../theme.dart';
import 'package:url_launcher/url_launcher.dart';

class MapSelectionScreen extends StatelessWidget {
  final String worldName;
  const MapSelectionScreen({super.key, required this.worldName});

  Future<void> _openMap(BuildContext context, String urlString) async {
    final url = Uri.parse(urlString);
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not open browser';
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: cInk,
            content: Text(
              'Could not open the map generator. Check your browser and try again.',
              style: TextStyle(color: cParchment, fontStyle: FontStyle.italic),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cVoid,
      appBar: AppBar(
        backgroundColor: cInk,
        iconTheme: const IconThemeData(color: cSmoke),
        title: Text(
          'Map for $worldName',
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 14,
            color: cParchment,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── INSTRUCTIONS ──
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cInk,
                border: Border.all(color: cGold.withValues(alpha: 0.3)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, color: cGold, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'HOW IT WORKS',
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: cGold,
                          letterSpacing: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '1. Tap a generator below to open it in your browser.\n'
                    '2. Build your perfect world or town.\n'
                    '3. Take a screenshot of the map. (Do NOT download the web page).\n'
                    '4. Return here, go to your World overview, and upload that screenshot.',
                    style: TextStyle(
                      fontSize: 13,
                      color: cMist,
                      height: 1.7,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),
            Text(
              'Give $worldName its shape.',
              style: const TextStyle(
                fontSize: 20,
                color: cParchment,
                fontWeight: FontWeight.w300,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Every world deserves a map its stories can walk across. '
              'Pick a generator below, build it, then bring it home.',
              style: TextStyle(
                fontSize: 13,
                color: cSmoke,
                fontStyle: FontStyle.italic,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Choose a generator:',
              style: TextStyle(
                fontSize: 16,
                color: cMist,
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 16),

            // ── WORLD MAP CARD (Azgaar) ──
            _MapOptionCard(
              title: 'World Map',
              subtitle:
                  'Full continents, factions, and religions. Best for large-scale world building.',
              icon: Icons.public,
              accent: cGold,
              onTap: () => _openMap(
                context,
                'https://azgaar.github.io/Fantasy-Map-Generator/',
              ),
            ),

            const SizedBox(height: 16),

            // ── TOWN MAP CARD (Fantasy Town Generator) ──
            _MapOptionCard(
              title: 'Town Map',
              subtitle:
                  'Detailed settlements and streets. No account needed to generate or export.',
              icon: Icons.location_city,
              accent: cIce,
              onTap: () =>
                  _openMap(context, 'https://www.fantasytowngenerator.com/'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MapOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  const _MapOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cInk,
          border: Border.all(color: accent.withValues(alpha: 0.4), width: 1.5),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: accent.withValues(alpha: 0.1),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: accent, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w300,
                      fontStyle: FontStyle.italic,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: cSmoke,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new, color: cSmoke),
          ],
        ),
      ),
    );
  }
}
