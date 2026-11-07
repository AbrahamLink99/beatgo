/// Scans the phone's shared storage for audio one-shots and loops.
///
/// Sources, in order: Download/Splice (Splice Mobile's download folder),
/// the rest of Download, Music, and any folders the user adds.
library;

import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _audioExt = {'.wav', '.aif', '.aiff', '.mp3', '.flac', '.ogg', '.m4a'};

class SampleFile {
  final String path;
  final String name; // file name without extension
  final String folder; // short folder label for grouping
  final int size;
  const SampleFile(this.path, this.name, this.folder, this.size);
}

class SampleLibrary {
  SampleLibrary._();
  static final instance = SampleLibrary._();

  static const _root = '/storage/emulated/0';
  static const defaultFolders = [
    '$_root/Download/Splice',
    '$_root/Download',
    '$_root/Music',
  ];

  final ValueNotifier<List<SampleFile>> files = ValueNotifier(const []);
  final ValueNotifier<bool> scanning = ValueNotifier(false);
  String? lastError;
  List<String> extraFolders = [];

  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) return true;
    // Android 13+: READ_MEDIA_AUDIO; older: storage.
    var s = await Permission.audio.request();
    if (s.isGranted) return true;
    s = await Permission.storage.request();
    return s.isGranted;
  }

  Future<void> loadExtraFolders() async {
    try {
      final p = await SharedPreferences.getInstance();
      extraFolders = p.getStringList('extraFolders') ?? [];
    } catch (_) {}
  }

  Future<void> addFolder(String path) async {
    if (extraFolders.contains(path)) return;
    extraFolders.add(path);
    try {
      final p = await SharedPreferences.getInstance();
      await p.setStringList('extraFolders', extraFolders);
    } catch (_) {}
  }

  Future<void> scan() async {
    if (scanning.value) return;
    scanning.value = true;
    lastError = null;
    final found = <String, SampleFile>{};
    try {
      final ok = await requestPermission();
      if (!ok) {
        lastError = 'Ingen tillgång till ljudfiler. Ge BeatGo behörighet under Appinfo → Behörigheter.';
      } else {
        for (final f in [...defaultFolders, ...extraFolders]) {
          await _walk(Directory(f), found, depth: 0);
        }
      }
    } catch (e) {
      lastError = 'Kunde inte läsa mappar: $e';
    }
    final list = found.values.toList()
      ..sort((a, b) {
        final c = a.folder.compareTo(b.folder);
        return c != 0 ? c : a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
    files.value = list;
    scanning.value = false;
  }

  Future<void> _walk(Directory dir, Map<String, SampleFile> out, {required int depth}) async {
    if (depth > 4 || !await dir.exists()) return;
    try {
      await for (final e in dir.list(followLinks: false)) {
        if (e is Directory) {
          final base = e.path.split('/').last;
          if (base.startsWith('.')) continue;
          await _walk(e, out, depth: depth + 1);
        } else if (e is File) {
          final p = e.path;
          final dot = p.lastIndexOf('.');
          if (dot < 0 || !_audioExt.contains(p.substring(dot).toLowerCase())) continue;
          if (out.containsKey(p)) continue;
          int size = 0;
          try {
            size = await e.length();
          } catch (_) {}
          out[p] = SampleFile(p, p.substring(p.lastIndexOf('/') + 1, dot), _label(p), size);
        }
      }
    } catch (_) {
      // folder not readable – skip it
    }
  }

  String _label(String path) {
    var rel = path.startsWith(_root) ? path.substring(_root.length + 1) : path;
    final parts = rel.split('/')..removeLast();
    if (parts.isEmpty) return '/';
    // "Download/Splice/Pack Name/…" → "Splice · Pack Name"
    if (parts.length >= 2 && parts[0] == 'Download' && parts[1] == 'Splice') {
      return parts.length > 2 ? 'Splice · ${parts[2]}' : 'Splice';
    }
    return parts.take(2).join(' / ');
  }
}
