import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secdockeeper/core/crypto/kdf.dart';
import 'package:secdockeeper/core/storage/paths.dart';
import 'package:secdockeeper/features/vault/key_rotation_journal.dart';
import 'package:secdockeeper/features/vault/vault_descriptor.dart';

class _FakePaths extends Fake implements VaultPaths {
  _FakePaths(this.root);

  @override
  final Directory root;
}

VaultDescriptor _descriptor() => VaultDescriptor(
      version: 1,
      salt: randomBytes(16),
      kdf: KdfParams.defaultParams,
    );

void main() {
  late Directory tmp;
  late VaultPaths paths;
  late SecretKey oldKek;
  late SecretKey newKek;
  late VaultDescriptor oldDescriptor;
  late VaultDescriptor newDescriptor;
  late KeyRotationJournal journal;

  setUp(() async {
    tmp = Directory.systemTemp.createTempSync('sdk_journal_test');
    paths = _FakePaths(tmp);
    oldKek = SecretKey(randomBytes(32));
    newKek = SecretKey(randomBytes(32));
    oldDescriptor = _descriptor();
    newDescriptor = _descriptor();
    journal = await KeyRotationJournal.create(
      oldDescriptor: oldDescriptor,
      newDescriptor: newDescriptor,
      oldKek: oldKek,
      newKek: newKek,
    );
  });

  tearDown(() => tmp.deleteSync(recursive: true));

  test('old KEK recovers the new one and targets the old descriptor', () async {
    final keys = (await journal.resolve(oldKek))!;
    expect(await keys.other.extractBytes(), await newKek.extractBytes());
    expect(keys.descriptor.salt, oldDescriptor.salt);
  });

  test('new KEK recovers the old one and targets the new descriptor', () async {
    final keys = (await journal.resolve(newKek))!;
    expect(await keys.other.extractBytes(), await oldKek.extractBytes());
    expect(keys.descriptor.salt, newDescriptor.salt);
  });

  test('an unrelated KEK resolves to null', () async {
    expect(await journal.resolve(SecretKey(randomBytes(32))), isNull);
  });

  test('survives a save/load round trip and can be deleted', () async {
    expect(KeyRotationJournal.exists(paths), isFalse);
    await journal.save(paths);
    expect(KeyRotationJournal.exists(paths), isTrue);

    final loaded = (await KeyRotationJournal.load(paths))!;
    final keys = (await loaded.resolve(newKek))!;
    expect(await keys.other.extractBytes(), await oldKek.extractBytes());
    expect(loaded.oldDescriptor.salt, oldDescriptor.salt);

    await KeyRotationJournal.delete(paths);
    expect(await KeyRotationJournal.load(paths), isNull);
  });

  test('vault descriptor save is atomic and leaves no temp file', () async {
    await oldDescriptor.save(paths);
    await newDescriptor.save(paths);
    final loaded = await VaultDescriptor.load(paths);
    expect(loaded.salt, newDescriptor.salt);
    expect(tmp.listSync().map((e) => e.uri.pathSegments.last), ['vault.json']);
  });
}
