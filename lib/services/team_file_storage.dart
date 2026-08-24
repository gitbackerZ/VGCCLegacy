import 'dart:io';
import 'package:path_provider/path_provider.dart';

class SavedTeamFile {
  final File file;
  final String name;
  final DateTime modified;
  SavedTeamFile({required this.file, required this.name, required this.modified});
}

/// Local on-device save/load for exported team text. Default filename is
/// "TEAM.txt"; repeated saves without an explicit name auto-increment
/// ("TEAM_1.txt", "TEAM_2.txt", ...) instead of overwriting silently.
class TeamFileStorage {
  static const String _subdir = 'saved_teams';
  static const String defaultBaseName = 'TEAM';
  static const String extension = '.txt';

  Future<Directory> _dir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory('${docs.path}/$_subdir');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<File> saveTeam(String text, {String? filename}) async {
    final dir = await _dir();
    String base = (filename == null || filename.trim().isEmpty)
        ? defaultBaseName
        : filename.trim();
    if (base.toLowerCase().endsWith(extension)) {
      base = base.substring(0, base.length - extension.length);
    }

    File target = File('${dir.path}/$base$extension');
    int suffix = 1;
    while (await target.exists()) {
      target = File('${dir.path}/${base}_$suffix$extension');
      suffix++;
    }
    return target.writeAsString(text);
  }

  Future<List<SavedTeamFile>> listSavedTeams() async {
    final dir = await _dir();
    final entities = await dir.list().toList();
    final files =
        entities.whereType<File>().where((f) => f.path.endsWith(extension)).toList();

    final List<SavedTeamFile> result = [];
    for (final f in files) {
      final stat = await f.stat();
      final name = f.path.split(Platform.pathSeparator).last.replaceAll(extension, '');
      result.add(SavedTeamFile(file: f, name: name, modified: stat.modified));
    }
    result.sort((a, b) => b.modified.compareTo(a.modified));
    return result;
  }

  Future<String> readTeam(File file) => file.readAsString();

  Future<void> deleteTeam(File file) async {
    if (await file.exists()) await file.delete();
  }
}