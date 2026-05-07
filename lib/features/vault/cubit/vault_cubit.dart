import 'package:flutter_bloc/flutter_bloc.dart';

import '../vault_service.dart';

/// Mirrors [VaultService.state] into a Cubit so screens and the router can
/// react to vault transitions through the bloc API. The service remains the
/// authoritative owner of secret material; the cubit only forwards state.
class VaultCubit extends Cubit<VaultState> {
  VaultCubit(this.vault) : super(vault.state) {
    vault.addListener(_onChange);
  }

  final VaultService vault;

  void _onChange() {
    if (!isClosed && state != vault.state) emit(vault.state);
  }

  @override
  Future<void> close() {
    vault.removeListener(_onChange);
    return super.close();
  }
}
