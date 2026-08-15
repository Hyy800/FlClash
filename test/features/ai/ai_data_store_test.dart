import 'dart:io';

import 'package:fl_clash/features/ai/ai_data_store.dart';
import 'package:fl_clash/models/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late File file;
  late AiDataStore store;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('flclash_ai_data_');
    file = File('${directory.path}${Platform.pathSeparator}ai.json');
    store = AiDataStore(file);
  });

  tearDown(() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  });

  test('persists all AI data in one local file', () async {
    final session = AiSession(
      title: 'Saved chat',
      messages: [AiChatMessage(role: 'user', content: 'Keep this message')],
    );
    final data = AiData(
      config: const AiConfig(
        baseUrl: 'https://example.com/v1',
        apiKey: 'key',
        model: 'model',
      ),
      sessions: AiSessionStore(
        activeSessionId: session.id,
        sessions: [session],
      ),
      skills: [AiSkill(name: 'Local skill', content: 'Persist locally')],
    );

    await store.write(data);
    final restored = await store.read();

    expect(restored?.config.apiKey, 'key');
    expect(restored?.sessions.activeSession.title, 'Saved chat');
    expect(
      restored?.sessions.activeSession.messages.single.content,
      'Keep this message',
    );
    expect(restored?.skills.single.name, 'Local skill');
    expect(await File('${file.path}.tmp').exists(), false);
  });

  test('replaces the same local file on later writes', () async {
    final first = AiData(
      config: const AiConfig(model: 'first'),
      sessions: AiSessionStore.initial(),
      skills: const [],
    );
    final second = AiData(
      config: const AiConfig(model: 'second'),
      sessions: AiSessionStore.initial(),
      skills: const [],
    );

    await store.write(first);
    await store.write(second);

    expect((await store.read())?.config.model, 'second');
    expect(await File('${file.path}.tmp').exists(), false);
  });

  test('does not replace malformed existing data while reading', () async {
    await file.writeAsString('{invalid', flush: true);

    await expectLater(store.read(), throwsFormatException);

    expect(await file.readAsString(), '{invalid');
  });
}
