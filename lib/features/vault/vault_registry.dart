import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

import '../../core/storage/paths.dart';

/// One entry in the vault registry. Holds only non-secret metadata — the same
/// trust level as `vault.json`. A vault's actual data lives under
/// `secdockeeper/vaults/<id>/`.
class VaultEntry {
  const VaultEntry({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory VaultEntry.fromJson(Map<String, Object?> json) => VaultEntry(
        id: json['id']! as String,
        name: (json['name'] as String?) ?? 'Vault',
        createdAt:
            DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as int?) ?? 0),
      );
}

/// Plaintext index of the vaults on this device, persisted to
/// `secdockeeper/vaults.json`. Contains no key material.
///
/// The registry is deliberately decoupled from `VaultService`: it just tracks
/// which vaults exist and which is active, so a future `VaultManager` can open
/// the chosen one. [appRoot] is injectable for tests.
class VaultRegistry {
  VaultRegistry({required Directory appRoot}) : _appRoot = appRoot;

  final Directory _appRoot;
  static const _uuid = Uuid();
  static const _fileName = 'vaults.json';
  static const _formatVersion = 1;

  /// Resolves the registry rooted at the real application support directory.
  static Future<VaultRegistry> resolve() async {
    return VaultRegistry(appRoot: await VaultPaths.appRoot());
  }

  File get _file => File(p.join(_appRoot.path, _fileName));

  bool get exists => _file.existsSync();

  Future<List<VaultEntry>> entries() async {
    final state = await _read();
    return state.entries;
  }

  Future<String?> activeId() async {
    final state = await _read();
    return state.activeId;
  }

  /// Registers a new vault and returns its generated id. Optionally makes it the
  /// active vault. Does not create any vault data — the caller initialises the
  /// `VaultService` for `VaultPaths.forVault(id)` separately.
  Future<VaultEntry> add({required String name, bool makeActive = true}) async {
    final state = await _read();
    final entry = VaultEntry(
      id: _uuid.v4(),
      name: name.trim().isEmpty ? 'Vault' : name.trim(),
      createdAt: DateTime.now(),
    );
    final next = [...state.entries, entry];
    await _write(_RegistryState(
      entries: next,
      activeId: makeActive ? entry.id : state.activeId,
    ));
    return entry;
  }

  /// Adds a pre-existing vault id (used when migrating the legacy single-vault
  /// layout into the registry). Idempotent on the id.
  Future<VaultEntry> addExisting({
    required String id,
    required String name,
    bool makeActive = true,
  }) async {
    final state = await _read();
    if (state.entries.any((e) => e.id == id)) {
      return state.entries.firstWhere((e) => e.id == id);
    }
    final entry = VaultEntry(id: id, name: name, createdAt: DateTime.now());
    await _write(_RegistryState(
      entries: [...state.entries, entry],
      activeId: makeActive ? id : state.activeId,
    ));
    return entry;
  }

  Future<void> setActive(String id) async {
    final state = await _read();
    if (!state.entries.any((e) => e.id == id)) {
      throw ArgumentError('Unknown vault id: $id');
    }
    await _write(_RegistryState(entries: state.entries, activeId: id));
  }

  Future<void> remove(String id) async {
    final state = await _read();
    final next = state.entries.where((e) => e.id != id).toList();
    final active = state.activeId == id
        ? (next.isEmpty ? null : next.first.id)
        : state.activeId;
    await _write(_RegistryState(entries: next, activeId: active));
  }

  Future<_RegistryState> _read() async {
    if (!_file.existsSync()) {
      return const _RegistryState(entries: [], activeId: null);
    }
    final json = jsonDecode(await _file.readAsString()) as Map<String, Object?>;
    final rawEntries = (json['vaults'] as List?) ?? const [];
    final entries = rawEntries
        .map((e) => VaultEntry.fromJson((e as Map).cast<String, Object?>()))
        .toList();
    return _RegistryState(entries: entries, activeId: json['active'] as String?);
  }

  Future<void> _write(_RegistryState state) async {
    final json = {
      'version': _formatVersion,
      'active': state.activeId,
      'vaults': state.entries.map((e) => e.toJson()).toList(),
    };
    await _file.writeAsString(jsonEncode(json), flush: true);
  }
}

class _RegistryState {
  const _RegistryState({required this.entries, required this.activeId});
  final List<VaultEntry> entries;
  final String? activeId;
}
