import 'dart:async';
import 'dart:convert';
import 'dart:io';

class RuleTrafficStore {
  File? _file;
  Map<int, int> _totals = const {};
  Map<int, int>? _pendingTotals;
  Timer? _saveTimer;
  Future<void> _writeOperation = Future<void>.value();
  Object? _writeError;

  Map<int, int> get totals => Map.unmodifiable(_totals);

  Future<void> initialize(String path) async {
    _saveTimer?.cancel();
    _saveTimer = null;
    _pendingTotals = null;
    _totals = const {};
    _file = File(path);
    final file = _file!;
    if (!await file.exists()) {
      _totals = const {};
      return;
    }
    final value = jsonDecode(await file.readAsString());
    if (value is! Map) {
      throw const FormatException('Rule traffic data must be a JSON object.');
    }
    final data = Map<String, dynamic>.from(value);
    final storedTotals = data['totals'];
    if (storedTotals is! Map) {
      throw const FormatException('Rule traffic totals are missing.');
    }
    _totals = {
      for (final entry in storedTotals.entries)
        if (int.tryParse(entry.key.toString()) != null && entry.value is num)
          int.parse(entry.key.toString()): _nonNegativeInt(entry.value as num),
    };
  }

  void scheduleSave(Map<int, int> totals) {
    if (_file == null) return;
    final snapshot = Map<int, int>.from(totals);
    if (_sameTotals(snapshot, _pendingTotals ?? _totals)) return;
    _pendingTotals = snapshot;
    _saveTimer ??= Timer(const Duration(seconds: 2), () async {
      _saveTimer = null;
      try {
        await _writePending();
      } catch (error) {
        _writeError = error;
      }
    });
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    await _writePending();
    try {
      await _writeOperation;
    } catch (error) {
      _writeError = error;
    }
    final error = _writeError;
    _writeError = null;
    if (error != null) throw error;
  }

  Future<void> delete() async {
    _saveTimer?.cancel();
    _saveTimer = null;
    _pendingTotals = null;
    await _writeOperation.catchError((_) {});
    final file = _file;
    if (file != null && await file.exists()) await file.delete();
    if (file != null) {
      final temporaryFile = File('${file.path}.tmp');
      if (await temporaryFile.exists()) await temporaryFile.delete();
    }
    _totals = const {};
  }

  Future<void> _writePending() async {
    final snapshot = _pendingTotals;
    final file = _file;
    if (snapshot == null || file == null) return;
    _pendingTotals = null;

    Future<void> write() async {
      await file.parent.create(recursive: true);
      final temporaryFile = File('${file.path}.tmp');
      await temporaryFile.writeAsString(
        jsonEncode({
          'version': 1,
          'totals': {
            for (final entry in snapshot.entries)
              entry.key.toString(): entry.value,
          },
        }),
        flush: true,
      );
      await temporaryFile.rename(file.path);
      _totals = snapshot;
    }

    final operation = _writeOperation.catchError((_) {}).then((_) => write());
    _writeOperation = operation;
    await operation;
  }

  bool _sameTotals(Map<int, int> first, Map<int, int> second) {
    if (first.length != second.length) return false;
    return first.entries.every((entry) => second[entry.key] == entry.value);
  }

  int _nonNegativeInt(num value) {
    return value.toInt().clamp(0, 0x7FFFFFFFFFFFFFFF).toInt();
  }
}

final ruleTrafficStore = RuleTrafficStore();
