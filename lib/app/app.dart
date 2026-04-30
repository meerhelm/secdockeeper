import 'package:flutter/material.dart';

import '../features/documents/documents_list_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/vault/lock_screen.dart';
import '../features/vault/vault_service.dart';
import 'app_scope.dart';
import 'theme.dart';

class SecDockKeeperApp extends StatelessWidget {
  const SecDockKeeperApp({super.key, required this.services});

  final AppServices services;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: services,
      child: MaterialApp(
        title: 'SecDockKeeper',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
        builder: (context, child) {
          return AppScope(services: services, child: child!);
        },
        home: ListenableBuilder(
          listenable: services.vault,
          builder: (context, _) {
            switch (services.vault.state) {
              case VaultState.uninitialized:
                return OnboardingScreen(vault: services.vault);
              case VaultState.locked:
                return LockScreen(vault: services.vault);
              case VaultState.unlocked:
                return const DocumentsListScreen();
            }
          },
        ),
      ),
    );
  }
}
