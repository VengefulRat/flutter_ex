import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;
import '../theme.dart';
import '../models/world.dart';
import '../services/sandbox_sync.dart';
import '../settings.dart';

class WorldMapScreen extends StatefulWidget {
  final WorldEntry world;
  final Function(WorldEntry) onSave;
  const WorldMapScreen({super.key, required this.world, required this.onSave});

  @override
  State<WorldMapScreen> createState() => _WorldMapScreenState();
}

class _WorldMapScreenState extends State<WorldMapScreen> {
  late final WebViewController _controller;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _showWarning = true;

  @override
  void initState() {
    super.initState();
    
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        'LoreBridge',
                onMessageReceived: (JavaScriptMessage message) async {
          final data = message.message;
          
          if (data.startsWith('step:')) return;

          if (data.startsWith('error:')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                backgroundColor: cInk,
                content: Text(data, style: const TextStyle(color: cEmber)),
              ));
            }
            setState(() => _isSaving = false);
            return;
          }
          
          if (data.startsWith('url:')) {
            final fullUrl = data.substring(4); // Remove the "url:" prefix
            
            try {
              // Save the full URL as a text file
              final ref = FirebaseStorage.instance.ref().child('worlds/${widget.world.id}_maplink.txt');
              await ref.putString(fullUrl);
              final url = await ref.getDownloadURL();
              
              widget.world.mapUrl = url;
              
              final worlds = await SandboxStorage.loadWorlds();
              final idx = worlds.indexWhere((w) => w.id == widget.world.id);
              if (idx != -1) worlds[idx] = widget.world;
              await SandboxStorage.saveWorlds(worlds);
              SandboxSync.pushWorlds(worlds);

              if (mounted) {
                widget.onSave(widget.world);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  backgroundColor: cInk,
                  content: Text('Map link saved!', style: TextStyle(color: cGold)),
                ));
                Navigator.pop(context);
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  backgroundColor: cInk,
                  content: Text('Firebase save failed: $e', style: TextStyle(color: cEmber)),
                ));
              }
              setState(() => _isSaving = false);
            }
          }
        },
      )

      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) {
             if (mounted) setState(() => _isLoading = false);
          },
        ),
      );

    _startMap();
  }

    Future<void> _startMap() async {
    // 1. If we have a map image saved, display it directly!
    if (widget.world.mapUrl != null && widget.world.mapUrl!.isNotEmpty) {
      setState(() {
        _isLoading = false; // Tell UI we are done loading the WebView
      });
      return;
    }
    
    // 2. Fallback: It's a new world. Load a fresh generator.
    _controller.loadRequest(Uri.parse('https://azgaar.github.io/Fantasy-Map-Generator/'));
    
    Future.delayed(const Duration(seconds: 1), () {
      _controller.runJavaScript("localStorage.clear();");
    });
  }

    void _saveMap() {
    setState(() => _isSaving = true);
    
    _controller.runJavaScript('''
      try {
        LoreBridge.postMessage("step: Started");
        
        // 1. Intercept the prompt popup just in case
        window.prompt = function(msg, val) {
          if (val && val.includes('#')) {
            LoreBridge.postMessage("url:" + val);
          }
          return val;
        };

        // 2. Click the main Save button
        var saveBtn = document.getElementById('saveButton');
        if (saveBtn) {
          saveBtn.click();
          
          // 3. Find "Save to Browser"
          setTimeout(function() {
            var elements = document.querySelectorAll('button, a, span, div, li');
            var clicked = false;
            for (var i = 0; i < elements.length; i++) {
              var text = (elements[i].innerText || elements[i].textContent || '').toLowerCase().trim();
              if (text === 'browser' || text === 'save to browser') {
                elements[i].click();
                clicked = true;
                break;
              }
            }
            
            if (!clicked) {
               LoreBridge.postMessage("error: 'Save to browser' option not found.");
               return;
            }

            // 4. Wait up to 60 seconds for the URL to appear in the address bar OR a text box
            var attempts = 0;
            var interval = setInterval(function() {
              attempts++;
              
              // Check the main URL hash
              if (window.location.hash && window.location.hash.length > 10) {
                clearInterval(interval);
                LoreBridge.postMessage("url:" + window.location.href);
                return;
              }
              
              // Check for any text boxes that might contain the URL
              var inputs = document.querySelectorAll('input, textarea');
              for (var j = 0; j < inputs.length; j++) {
                if (inputs[j].value && inputs[j].value.includes('#maplink=')) {
                  clearInterval(interval);
                  LoreBridge.postMessage("url:" + inputs[j].value);
                  return;
                }
              }
              
              if (attempts > 120) { // 120 * 500ms = 60 seconds
                clearInterval(interval);
                LoreBridge.postMessage("error: Map saving timed out. Try a smaller map size.");
              }
            }, 500);
          }, 250);
        } else {
          LoreBridge.postMessage("error: Main 'Save' button not found.");
        }
      } catch(e) {
        LoreBridge.postMessage("error: " + e.message);
      }
    ''');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: cVoid,
      appBar: AppBar(
        backgroundColor: cInk,
        iconTheme: const IconThemeData(color: cSmoke),
        title: Text(
          widget.world.name.isEmpty ? 'Generate Map' : widget.world.name,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 14, color: cParchment),
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: cGold, strokeWidth: 1.5))),
            )
          else
            TextButton(
              onPressed: _saveMap,
              child: const Text('SAVE MAP', style: TextStyle(fontFamily: 'monospace', fontSize: 10, color: cGold, letterSpacing: 2)),
            ),
        ],
      ),
      body: Stack(
        children: [
          // 1. Show the saved image OR the WebView
          if (widget.world.mapUrl != null && widget.world.mapUrl!.isNotEmpty)
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5.0,
                child: Image.network(
                  widget.world.mapUrl!,
                  fit: BoxFit.contain,
                  loadingBuilder: (_, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator(color: cGold)),
                ),
              ),
            )
          else
            Positioned.fill(
              child: WebViewWidget(controller: _controller),
            ),

          // 2. The Warning Banner (Only shows if generating a new map)
          if (_showWarning && _isLoading && (widget.world.mapUrl == null || widget.world.mapUrl!.isEmpty))
            Positioned(
              bottom: 24,
              left: 24,
              right: 24,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: cInk,
                  border: Border.all(color: cGold.withValues(alpha: 0.5)),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.8), blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.warning_amber_rounded, color: cGold, size: 24),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'The map generator is heavy. Older devices may experience lag while generating.',
                        style: TextStyle(fontSize: 12, color: cMist, height: 1.4),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => setState(() => _showWarning = false),
                      child: const Icon(Icons.close, color: cSmoke, size: 18),
                    ),
                  ],
                ),
              ),
            ),

          // 3. The Loading Spinner
          if (_isLoading)
            const Center(child: CircularProgressIndicator(color: cGold)),
        ],
      ),
    );
  }
}