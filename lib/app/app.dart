import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../features/vault/cubit/vault_cubit.dart';
import 'app_scope.dart';
import 'router.dart';
import 'theme.dart';

class SecDockKeeperApp extends StatefulWidget {
  const SecDockKeeperApp({super.key, required this.services});

  final AppServices services;

  @override
  State<SecDockKeeperApp> createState() => _SecDockKeeperAppState();
}

class _SecDockKeeperAppState extends State<SecDockKeeperApp> {
  late final _router = buildAppRouter(vault: widget.services.vault);

  @override
  Widget build(BuildContext context) {
    return AppScope(
      services: widget.services,
      child: BlocProvider(
        create: (_) => VaultCubit(widget.services.vault),
        child: MaterialApp.router(
          title: 'SecDockKeeper',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeMode.system,
          routerConfig: _router,
          builder: (context, child) {
            return AppScope(services: widget.services, child: child!);
          },
        ),
      ),
    );
  }
}
