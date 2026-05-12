import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../features/backup/usecases/export_backup.dart';
import '../features/backup/usecases/restore_backup.dart';
import '../features/documents/cubit/document_detail_cubit.dart';
import '../features/documents/cubit/documents_list_cubit.dart';
import '../features/documents/document_detail_screen.dart';
import '../features/documents/documents_list_screen.dart';
import '../features/documents/usecases/delete_document.dart';
import '../features/documents/usecases/get_document.dart';
import '../features/documents/usecases/import_files.dart';
import '../features/documents/usecases/open_document.dart';
import '../features/documents/usecases/rename_document.dart';
import '../features/documents/usecases/scan_document.dart';
import '../features/documents/usecases/search_documents.dart';
import '../features/documents/usecases/watch_document_changes.dart';
import '../features/folders/usecases/create_folder.dart';
import '../features/folders/usecases/get_folder.dart';
import '../features/folders/usecases/list_folders.dart';
import '../features/folders/usecases/watch_folder_changes.dart';
import '../features/notes/cubit/note_editor_cubit.dart';
import '../features/notes/note_editor_screen.dart';
import '../features/notes/usecases/create_note.dart';
import '../features/notes/usecases/delete_note.dart';
import '../features/notes/usecases/get_note.dart';
import '../features/notes/usecases/list_notes.dart';
import '../features/notes/usecases/save_note.dart';
import '../features/notes/usecases/watch_note_changes.dart';
import '../features/onboarding/cubit/onboarding_cubit.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/security/usecases/biometric_unlock.dart';
import '../features/security/usecases/disable_biometrics.dart';
import '../features/security/usecases/enable_biometrics.dart';
import '../features/security/usecases/is_biometric_available.dart';
import '../features/security/usecases/is_biometric_unlock_ready.dart';
import '../features/security/usecases/register_failed_unlock.dart';
import '../features/security/usecases/set_panic_action.dart';
import '../features/settings/cubit/settings_cubit.dart';
import '../features/settings/settings_screen.dart';
import '../features/sharing/usecases/import_shared_package.dart';
import '../features/sharing/usecases/share_document.dart';
import '../features/tags/usecases/list_all_tags.dart';
import '../features/tags/usecases/list_tags_for_document.dart';
import '../features/tags/usecases/unassign_tag.dart';
import '../features/tags/usecases/watch_tag_changes.dart';
import '../features/vault/cubit/lock_cubit.dart';
import '../features/vault/lock_screen.dart';
import '../features/vault/usecases/destroy_vault.dart';
import '../features/vault/usecases/initialize_vault.dart';
import '../features/vault/usecases/lock_vault.dart';
import '../features/vault/usecases/rotate_vault_key.dart';
import '../features/vault/usecases/verify_master_password.dart';
import '../features/vault/usecases/unlock_vault.dart';
import '../features/vault/vault_service.dart';
import 'app_scope.dart';
import 'routes.dart';

GoRouter buildAppRouter({required VaultService vault}) {
  return GoRouter(
    initialLocation: AppRoutes.root,
    refreshListenable: vault,
    redirect: (context, state) {
      final loc = state.uri.path;
      switch (vault.state) {
        case VaultState.uninitialized:
          return loc == AppRoutes.onboarding ? null : AppRoutes.onboarding;
        case VaultState.locked:
          return loc == AppRoutes.lock ? null : AppRoutes.lock;
        case VaultState.unlocked:
          if (loc == AppRoutes.onboarding ||
              loc == AppRoutes.lock ||
              loc == AppRoutes.root) {
            return AppRoutes.documents;
          }
          return null;
      }
    },
    routes: [
      GoRoute(
        path: AppRoutes.root,
        builder: (_, _) => const _SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, _) {
          final s = AppScope.of(context);
          return BlocProvider(
            create: (_) => OnboardingCubit(
              initializeVault: InitializeVaultUseCase(s.vault),
              isBiometricAvailable:
                  IsBiometricAvailableUseCase(s.biometrics),
              enableBiometrics: EnableBiometricsUseCase(s.lockSettings),
              setPanicAction: SetPanicActionUseCase(s.lockSettings),
              restoreBackup: RestoreBackupUseCase(s.backup),
            ),
            child: const OnboardingScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.lock,
        builder: (context, _) {
          final s = AppScope.of(context);
          return BlocProvider(
            create: (_) => LockCubit(
              unlockVault: UnlockVaultUseCase(s.vault),
              biometricUnlock: BiometricUnlockUseCase(
                biometrics: s.biometrics,
                lockSettings: s.lockSettings,
                vault: s.vault,
              ),
              isBiometricReady: IsBiometricUnlockReadyUseCase(
                biometrics: s.biometrics,
                lockSettings: s.lockSettings,
              ),
              registerFailedUnlock: RegisterFailedUnlockUseCase(
                lockSettings: s.lockSettings,
                destroyVault: DestroyVaultUseCase(
                  vault: s.vault,
                  opener: s.opener,
                  lockSettings: s.lockSettings,
                ),
              ),
              lockSettings: s.lockSettings,
            ),
            child: const LockScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.documents,
        builder: (context, _) {
          final s = AppScope.of(context);
          return BlocProvider(
            create: (_) => DocumentsListCubit(
              searchDocuments: SearchDocumentsUseCase(
                documents: s.documents,
                tags: s.tags,
                hiddenTags: s.hiddenTags,
              ),
              listFolders: ListFoldersUseCase(s.folders),
              listAllTags: ListAllTagsUseCase(s.tags),
              importFiles: ImportFilesUseCase(s.importer),
              scanDocument: ScanDocumentUseCase(
                scanner: s.scanner,
                importer: s.importer,
              ),
              lockVault: LockVaultUseCase(
                vault: s.vault,
                opener: s.opener,
              ),
              createFolder: CreateFolderUseCase(s.folders),
              watchDocumentChanges:
                  WatchDocumentChangesUseCase(s.documents),
              watchFolderChanges: WatchFolderChangesUseCase(s.folders),
              listNotes: ListNotesUseCase(s.notes),
              createNote: CreateNoteUseCase(s.notes),
              deleteNote: DeleteNoteUseCase(s.notes),
              watchNoteChanges: WatchNoteChangesUseCase(s.notes),
            ),
            child: const DocumentsListScreen(),
          );
        },
        routes: [
          GoRoute(
            path: ':id',
            builder: (context, state) {
              final id = int.parse(state.pathParameters['id']!);
              final s = AppScope.of(context);
              return BlocProvider(
                create: (_) => DocumentDetailCubit(
                  documentId: id,
                  getDocument: GetDocumentUseCase(s.documents),
                  getFolder: GetFolderUseCase(s.folders),
                  listTagsForDocument: ListTagsForDocumentUseCase(s.tags),
                  renameDocument: RenameDocumentUseCase(s.documents),
                  deleteDocument: DeleteDocumentUseCase(
                    vault: s.vault,
                    repository: s.documents,
                  ),
                  openDocument: OpenDocumentUseCase(s.opener),
                  shareDocument: ShareDocumentUseCase(s.share),
                  unassignTag: UnassignTagUseCase(s.tags),
                  watchDocumentChanges:
                      WatchDocumentChangesUseCase(s.documents),
                  watchFolderChanges:
                      WatchFolderChangesUseCase(s.folders),
                  watchTagChanges: WatchTagChangesUseCase(s.tags),
                ),
                child: const DocumentDetailScreen(),
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: AppRoutes.noteDetail,
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          final s = AppScope.of(context);
          return BlocProvider(
            create: (_) => NoteEditorCubit(
              noteId: id,
              getNote: GetNoteUseCase(s.notes),
              saveNote: SaveNoteUseCase(s.notes),
              deleteNote: DeleteNoteUseCase(s.notes),
              getFolder: GetFolderUseCase(s.folders),
              watchFolderChanges: WatchFolderChangesUseCase(s.folders),
            ),
            child: const NoteEditorScreen(),
          );
        },
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, _) {
          final s = AppScope.of(context);
          return BlocProvider(
            create: (_) => SettingsCubit(
              lockSettings: s.lockSettings,
              setPanicAction: SetPanicActionUseCase(s.lockSettings),
              importSharedPackage: ImportSharedPackageUseCase(s.share),
              exportBackup: ExportBackupUseCase(
                backup: s.backup,
                opener: s.opener,
              ),
              rotateVaultKey: RotateVaultKeyUseCase(
                vault: s.vault,
                documents: s.documents,
                hiddenTags: s.hiddenTags,
                notes: s.notes,
                paths: s.paths,
              ),
              destroyVault: DestroyVaultUseCase(
                vault: s.vault,
                opener: s.opener,
                lockSettings: s.lockSettings,
              ),
              isBiometricAvailable: IsBiometricAvailableUseCase(s.biometrics),
              enableBiometrics: EnableBiometricsUseCase(s.lockSettings),
              disableBiometrics: DisableBiometricsUseCase(s.lockSettings),
              verifyMasterPassword: VerifyMasterPasswordUseCase(s.vault),
            ),
            child: const SettingsScreen(),
          );
        },
      ),
    ],
  );
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
