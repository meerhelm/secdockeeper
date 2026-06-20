import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:secdockeeper/features/vault/vault_registry.dart';

void main() {
  late Directory tmp;
  late VaultRegistry registry;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('sdk_registry_test');
    registry = VaultRegistry(appRoot: tmp);
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  test('starts empty with no active vault', () async {
    expect(registry.exists, isFalse);
    expect(await registry.entries(), isEmpty);
    expect(await registry.activeId(), isNull);
  });

  test('add registers a vault and makes it active by default', () async {
    final entry = await registry.add(name: 'Personal');

    expect(registry.exists, isTrue);
    final entries = await registry.entries();
    expect(entries.map((e) => e.id), [entry.id]);
    expect(entries.single.name, 'Personal');
    expect(await registry.activeId(), entry.id);
  });

  test('blank names fall back to a default', () async {
    final entry = await registry.add(name: '   ');
    expect(entry.name, 'Vault');
  });

  test('multiple vaults persist and active can be switched', () async {
    final a = await registry.add(name: 'A');
    final b = await registry.add(name: 'B');

    expect((await registry.entries()).length, 2);
    expect(await registry.activeId(), b.id);

    await registry.setActive(a.id);
    expect(await registry.activeId(), a.id);
  });

  test('setActive rejects an unknown id', () async {
    await registry.add(name: 'A');
    expect(() => registry.setActive('nope'), throwsArgumentError);
  });

  test('addExisting is idempotent on the id', () async {
    await registry.addExisting(id: 'legacy-1', name: 'Default');
    await registry.addExisting(id: 'legacy-1', name: 'Default again');
    expect((await registry.entries()).length, 1);
    expect((await registry.entries()).single.name, 'Default');
  });

  test('remove drops the vault and reassigns active', () async {
    final a = await registry.add(name: 'A');
    final b = await registry.add(name: 'B');

    await registry.remove(b.id);
    final entries = await registry.entries();
    expect(entries.map((e) => e.id), [a.id]);
    expect(await registry.activeId(), a.id);

    await registry.remove(a.id);
    expect(await registry.entries(), isEmpty);
    expect(await registry.activeId(), isNull);
  });

  test('state survives a fresh registry instance over the same dir', () async {
    final a = await registry.add(name: 'Persisted');
    final reopened = VaultRegistry(appRoot: tmp);
    final entries = await reopened.entries();
    expect(entries.single.id, a.id);
    expect(await reopened.activeId(), a.id);
  });
}
