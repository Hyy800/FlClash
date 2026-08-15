import 'dart:convert';
import 'dart:io';

import 'package:fl_clash/models/models.dart';

class AiData {
  static const version = 1;

  final AiConfig config;
  final AiSessionStore sessions;
  final List<AiSkill> skills;

  const AiData({
    required this.config,
    required this.sessions,
    required this.skills,
  });

  factory AiData.fromJson(Map<String, dynamic> json) {
    final storedVersion = json['version'] as int? ?? 0;
    if (storedVersion > version) {
      throw FormatException(
        'AI data version $storedVersion is newer than $version.',
      );
    }
    return AiData(
      config: AiConfig.fromJson(
        Map<String, dynamic>.from(json['config'] as Map? ?? const {}),
      ),
      sessions: AiSessionStore.fromJson(
        Map<String, dynamic>.from(json['sessions'] as Map? ?? const {}),
      ),
      skills: (json['skills'] as List? ?? const [])
          .whereType<Map>()
          .map((item) => AiSkill.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'config': config.toJson(),
    'sessions': sessions.toJson(),
    'skills': skills.map((skill) => skill.toJson()).toList(),
  };
}

class AiDataStore {
  final File file;

  const AiDataStore(this.file);

  Future<AiData?> read() async {
    if (!await file.exists()) return null;
    final value = jsonDecode(await file.readAsString());
    if (value is! Map) {
      throw const FormatException('AI data must be a JSON object.');
    }
    return AiData.fromJson(Map<String, dynamic>.from(value));
  }

  Future<void> write(AiData data) async {
    await file.parent.create(recursive: true);
    final temporaryFile = File('${file.path}.tmp');
    await temporaryFile.writeAsString(jsonEncode(data.toJson()), flush: true);
    await temporaryFile.rename(file.path);
  }

  Future<void> delete() async {
    if (await file.exists()) await file.delete();
    final temporaryFile = File('${file.path}.tmp');
    if (await temporaryFile.exists()) await temporaryFile.delete();
  }
}
