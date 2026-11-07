import 'package:flutter/material.dart';

import '../audio/engine.dart';
import '../main.dart';
import '../samples/library.dart';

/// Full-screen picker over the phone's audio files. Tap a row to preview,
/// tap "Välj" to return it. Returns the picked [SampleFile] or null.
class SampleBrowser extends StatefulWidget {
  const SampleBrowser({super.key, required this.title});
  final String title;

  static Future<SampleFile?> open(BuildContext context, {String title = 'Välj ljud'}) =>
      Navigator.of(context).push<SampleFile>(
        MaterialPageRoute(builder: (_) => SampleBrowser(title: title), fullscreenDialog: true),
      );

  @override
  State<SampleBrowser> createState() => _SampleBrowserState();
}

class _SampleBrowserState extends State<SampleBrowser> {
  final lib = SampleLibrary.instance;
  final engine = AudioEngine.instance;
  final search = TextEditingController();
  String? playing;

  @override
  void initState() {
    super.initState();
    if (lib.files.value.isEmpty) _rescan();
    search.addListener(() => setState(() {}));
  }

  Future<void> _rescan() async {
    await lib.loadExtraFolders();
    await lib.scan();
    if (mounted) setState(() {});
  }

  Future<void> _preview(SampleFile f) async {
    setState(() => playing = f.path);
    await engine.stopPreview();
    await engine.preview(f.path);
  }

  Future<void> _addFolder() async {
    final ctl = TextEditingController(text: '/storage/emulated/0/');
    final path = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Bg.lane,
        title: const Text('Lägg till mapp'),
        content: TextField(
          controller: ctl,
          autofocus: true,
          decoration: const InputDecoration(hintText: '/storage/emulated/0/Music/MinaSamples'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Avbryt')),
          FilledButton(onPressed: () => Navigator.pop(context, ctl.text.trim()), child: const Text('Lägg till')),
        ],
      ),
    );
    if (path == null || path.isEmpty) return;
    await lib.addFolder(path);
    await _rescan();
  }

  @override
  void dispose() {
    engine.stopPreview();
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = search.text.trim().toLowerCase();
    final all = lib.files.value;
    final shown = q.isEmpty
        ? all
        : all.where((f) => f.name.toLowerCase().contains(q) || f.folder.toLowerCase().contains(q)).toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Bg.base,
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _addFolder, icon: const Icon(Icons.create_new_folder_outlined), tooltip: 'Lägg till mapp'),
          ValueListenableBuilder<bool>(
            valueListenable: lib.scanning,
            builder: (_, busy, __) => IconButton(
              onPressed: busy ? null : _rescan,
              icon: busy
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Bg.lime))
                  : const Icon(Icons.refresh),
              tooltip: 'Sök igenom igen',
            ),
          ),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: search,
            decoration: InputDecoration(
              hintText: 'Sök bland ${all.length} ljud…',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Bg.lane,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              isDense: true,
            ),
          ),
        ),
        if (lib.lastError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(lib.lastError!, style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
          ),
        if (lib.scanReport.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              lib.scanReport.entries
                  .map((e) => '${e.key.replaceFirst('/storage/emulated/0/', '')}: ${e.value < 0 ? 'finns inte' : '${e.value} filer'}')
                  .join(' · '),
              style: const TextStyle(color: Bg.muted, fontSize: 10, height: 1.4),
            ),
          ),
        if (all.isEmpty && lib.lastError == null && !lib.scanning.value)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text(
              'Inga ljudfiler hittades i Download, Download/Splice eller Music.\n\n'
              'Ladda ner något i Splice-appen (Download → Save to Files) eller lägg till en egen mapp med knappen uppe till höger.',
              style: TextStyle(color: Bg.muted, height: 1.5),
            ),
          ),
        Expanded(
          child: ListView.builder(
            itemCount: shown.length,
            itemBuilder: (_, i) {
              final f = shown[i];
              final showHeader = i == 0 || shown[i - 1].folder != f.folder;
              final isPlaying = playing == f.path;
              return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                if (showHeader)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                    child: Text(f.folder.toUpperCase(),
                        style: const TextStyle(color: Bg.muted, fontSize: 11, letterSpacing: 1.2)),
                  ),
                ListTile(
                  dense: true,
                  onTap: () => _preview(f),
                  leading: Icon(isPlaying ? Icons.graphic_eq : Icons.play_arrow_rounded,
                      color: isPlaying ? Bg.lime : Bg.muted),
                  title: Text(f.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${(f.size / 1024).round()} kB', style: const TextStyle(color: Bg.muted, fontSize: 11)),
                  trailing: TextButton(
                    onPressed: () => Navigator.pop(context, f),
                    child: const Text('Välj', style: TextStyle(color: Bg.lime, fontWeight: FontWeight.w700)),
                  ),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}
