# Routing

The app uses [`go_router`](https://pub.dev/packages/go_router) 17.x with a
single top-level redirect that gates every route by the current
[`VaultState`](../lib/features/vault/vault_service.dart). The router is also
the place where each screen's cubit is constructed and wired up — see
[`architecture.md`](architecture.md#routing-as-the-composition-root).

## Route table

Defined in [`lib/app/routes.dart`](../lib/app/routes.dart):

| Constant | Path | Screen |
| --- | --- | --- |
| `AppRoutes.root` | `/` | Splash (briefly visible while redirect resolves) |
| `AppRoutes.onboarding` | `/onboarding` | `OnboardingScreen` |
| `AppRoutes.lock` | `/lock` | `LockScreen` |
| `AppRoutes.documents` | `/documents` | `DocumentsListScreen` |
| `AppRoutes.documentDetail` | `/documents/:id` | `DocumentDetailScreen` |

`/documents/:id` is a *child* of `/documents`, not a sibling. That means
`context.pop()` from the detail screen returns to the list with the same
Navigator stack; back gestures and the system back button just work.

`AppRoutes.documentDetailPath(id)` is the helper that builds the concrete
path — use it instead of string-formatting yourself.

Sheets (`FolderPickerSheet`, `TagPickerSheet`, `HiddenTagsSheet`) are **not**
routes. They are `showModalBottomSheet` overlays. Each sheet's
`static show(context, ...)` is the entry point and the only place its cubit
is provided.

## Redirect logic

[`router.dart`](../lib/app/router.dart) sets `refreshListenable: vault` so the
redirect re-runs whenever `VaultService` notifies. The redirect:

```dart
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
```

In practice:

- App cold-start with no vault → `/` → redirected to `/onboarding`.
- App cold-start with an existing vault → `/` → redirected to `/lock`.
- Successful unlock → `vault.unlock` notifies → redirect → `/documents`.
- User taps the lock button or auto-lock fires → `vault.lock` notifies →
  redirect → `/lock`. Any sub-route (e.g. `/documents/123`) is also redirected
  away, so a locked detail screen never lingers.
- Successful onboarding → `vault.initialize` notifies → redirect →
  `/documents`. The cubit doesn't navigate.

## Composition root

Each `GoRoute.builder` is responsible for constructing the cubit it needs.
The pattern looks like this:

```dart
GoRoute(
  path: AppRoutes.documents,
  builder: (context, _) {
    final s = AppScope.of(context);
    return BlocProvider(
      create: (_) => DocumentsListCubit(
        searchDocuments: SearchDocumentsUseCase(
          documents: s.documents, tags: s.tags, hiddenTags: s.hiddenTags,
        ),
        // ... other use cases pulled from s
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
            // ... use cases
          ),
          child: const DocumentDetailScreen(),
        );
      },
    ),
  ],
),
```

This is the only place where:

- `AppScope.of(context)` is read for cubit construction
- Use cases are instantiated
- The full set of dependencies for a screen are visible together

Keep it that way. If you find yourself constructing a use case inside a
screen, you've stepped over a layer.

## Navigating

| Operation | API |
| --- | --- |
| Push detail | `context.push(AppRoutes.documentDetailPath(id))` |
| Pop back | `context.pop()` (works for both routed pages and dialogs) |
| Replace location | `context.go(...)` (rarely needed — vault state changes drive most navigation) |

`Navigator.of(context).pop(value)` still works inside dialogs and bottom
sheets. Don't replace it with `context.pop` for those — `Navigator` is the
correct API there because they aren't routes.

After unlocking the vault, the cubit does **not** call `context.go` — it
just succeeds. The vault's `notifyListeners` triggers the router redirect.
This keeps cubits free of `BuildContext` and avoids races between cubit
emission and route changes.

## Adding a new route

1. Add a path constant to [`routes.dart`](../lib/app/routes.dart).
2. Add a `GoRoute` in [`router.dart`](../lib/app/router.dart). Wrap the
   screen in `BlocProvider` if it has a cubit.
3. Update the redirect if the new route should only be reachable in a
   specific vault state. For most new screens (under `/documents`), no
   redirect change is needed — the parent `/documents` redirect covers
   their visibility.
4. Use `context.push(...)` from the source screen to navigate.

If the new screen is under `/documents`, prefer making it a child route
(nested in the existing `routes:` array) so back navigation lands on the
list. If it's a sibling top-level route, you'll get a fresh navigator stack
and back will go to the root.

## go_router gotchas seen in this codebase

- **`refreshListenable` only re-evaluates the redirect.** It doesn't rebuild
  any of your widgets. If a widget needs to react to `VaultState`, use
  `BlocBuilder<VaultCubit, VaultState>` instead of relying on the router.
- **`state.pathParameters['id']` is a `String`.** Always parse it with
  `int.parse(...)` for the documents detail route. There's no automatic
  conversion.
- **Dialogs and sheets are not routed.** `context.pop()` works on them
  because under the hood they push a `MaterialPageRoute`-equivalent on the
  current Navigator. But the URL bar (web) wouldn't change for them, and
  `redirect` doesn't run for them. Don't try to make them routed.
