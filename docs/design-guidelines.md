# Design guidelines

This page is the working contract between new screens and the existing visual
language. The redesign brief in [`redesign-brief.md`](../redesign-brief.md)
describes *intent* (brand attributes, tone, screen-by-screen layout).
This page documents what the codebase actually ships, so that a new screen
slots in without re-deriving spacing, colors, type, or component choices.

When a new requirement doesn't fit, prefer extending the system over
one-offs: add a token, add a widget in `lib/app/widgets/`, document it here.

---

## 1. Tokens

All design values live in two files. Touch them, not screens.

- [`lib/app/tokens.dart`](../lib/app/tokens.dart) — `AppColors` (a
  `ThemeExtension`) plus the `AppMono` helper for JetBrains-Mono text styles.
  Read colors via `context.c` (the extension at the bottom of the file).
- [`lib/app/theme.dart`](../lib/app/theme.dart) — Material 3 `ThemeData`
  built from `AppColors`, plus per-component themes (buttons, cards, fields,
  bottom sheets, dialogs, chips). New screens get all of this for free —
  they should never set their own button shapes, field decorations, or
  card colors.

### Color roles

Use semantic names, never raw hex.

| Token | Use it for |
| --- | --- |
| `bg` | `Scaffold.backgroundColor` (already wired through theme). The page canvas. |
| `surface` | Primary card/sheet/dialog/field surface. The thing that sits on `bg`. |
| `surface2` | Secondary surface — chip count pills, snackbar bg, the strength-meter inactive segment. |
| `surface3` | Tertiary surface — rarely needed; reserve for elements that must read as "deeper" than `surface2`. |
| `border` | Hairline 1 px borders on cards, fields, chips, sheets. |
| `borderStrong` | 1 px border for outlined buttons, drag handles, checkbox sides — anything that must remain visible at glance. |
| `fg` | Default body and title color. |
| `fgStrong` | Reserved for the rare element that has to outshout `fg` (e.g. a hero number). Don't reach for it on text by default. |
| `muted` | Secondary text — meta lines, captions, helper copy under inputs. |
| `muted2` | Tertiary text — input placeholders, "very faint" labels. Below this, prefer hiding. |
| `accent` / `accentFg` | The single brand accent. Filled buttons, the brand mark's top block, selected chips, links, focus cursor. |
| `accentSoft` | 10–12 % accent — selected-chip background tint, classification badge background, focus glow. |
| `accentLine` | 30–34 % accent — focused field border, selected outline. |
| `error` / `errorSoft` | Inline error banners, destructive button color. Use sparingly: destructive doesn't need to scream (the brief). |
| `warn` | Amber. The left rail on `WarnBanner`, the warning icon background. **Not** for chrome — only for "this is irreversible" copy. |

Both light and dark are defined; pick by role, not by lightness. The single
brand accent is green (light: `#047857`, dark: `#00D992`); don't introduce a
second brand color.

### Type

Three families on screen, in order of frequency:

1. **System sans** (the platform default) — set on `ThemeData` via `textTheme`.
   Use `Theme.of(context).textTheme.X`:
   - `displayLarge` — `32 / w600`. The onboarding/lock hero.
   - `headlineLarge` `28` · `headlineMedium` `24` · `headlineSmall` `18` —
     screen titles in roughly that order.
   - `titleLarge` `22` · `titleMedium` `17` · `titleSmall` `14.5` —
     card titles, list-row titles, sheet titles.
   - `bodyLarge` `15` (color: `fg`) — body copy, default field text.
   - `bodyMedium` `14` (color: `muted`) — subtitles and captions.
   - `bodySmall` `12.5` (color: `muted`) — long-form helper copy.
   - `labelLarge` `15 / w600` — button labels (auto-applied by button themes).
2. **JetBrains Mono** via `AppMono` — meta lines, byte/date pairs, hashes,
   uppercase section labels. The label and meta variants already set color,
   weight, and tracking; just call `AppMono.label(context)` /
   `AppMono.meta(context)`.
3. **No third typeface.** Don't import another `google_fonts.X(...)` for a
   new screen.

When a label is uppercased and tracked-out, it is `AppMono.label` with
`text.toUpperCase()` (see `SectionLabel`). Never hand-roll `letterSpacing`
on uppercased text.

### Radii

Three corner sizes, used consistently:

- **`8` and smaller** — micro-pills (count badges, dot rounded corners).
- **`10`–`12`** — chips, search field, small icon-buttons.
- **`14`** — cards, primary buttons, popup menus, inset surfaces inside meta cards.
- **`16`** — document cards in the list, action-group containers.
- **`20`** — dialogs.
- **`24`** — bottom-sheet top corners (radius applied only on top edges).

If a new component needs a radius, pick from this set. No `r=11` or `r=18`.

### Spacing

The codebase clusters around `4 / 6 / 8 / 10 / 12 / 14 / 16 / 20 / 24`. Pick
from that. Two recurring page-level patterns:

- **Centered narrow column** (onboarding, lock): `EdgeInsets.symmetric(horizontal: 24, vertical: 32)` outside, `BoxConstraints(maxWidth: 440)` inside, content centered.
- **Full-width feed** (documents list, detail body): `horizontal: 16` for tight phone density, `horizontal: 20` for sheets and detail pages with cards.

Vertical rhythm inside a card: `padding: 14`. Between cards in a feed: `gap: 10`. Between cards and the next section header: `22` above the header, `8` below (matches `SectionLabel`'s default).

### Elevation & shadows

Don't draw shadows. The system is flat: surfaces stack via `bg → surface → surface2 → surface3`, separated by `border` hairlines. The only "glow" used is the focus state on `AppField`, and that's already in the widget. New screens should have zero `BoxShadow` calls.

---

## 2. Component library

Before building anything, scan [`lib/app/widgets/`](../lib/app/widgets/). The
ones a new screen will reach for first:

| Widget | Purpose |
| --- | --- |
| `PrimaryActionButton` | 52 px filled-accent CTA. `busy: true` swaps the icon for a spinner. Always full-width. |
| `OutlineActionButton` | 52 px outlined secondary CTA. |
| `GhostActionButton` | 52 px surface-coloured quiet action. |
| `DestructiveButton` | 52 px outlined error CTA. The brief: destructive doesn't scream. |
| `IconChipButton` | 36×36 squared icon button. `ghost: true` removes border + fill. App-bar trailing actions and inline tile actions. |
| `AppField` | Labeled input with a 50 px row, accent focus ring, optional prefix icon and suffix. Use for every text input that isn't a global search. |
| `AppStrengthMeter` | 4-segment password strength bar. Sits under an `AppField`. |
| `AppSearchField` | 44 px filled search bar. The list-screen search field. |
| `AppChip` | 36 px rail chip with optional count and selected state — folder rail, filter rail. |
| `ClassBadge` | Small accent-soft pill with leading dot — the classification badges on document cards. |
| `MetaCard` / `MetaRow` | Vertical `KEY · value` rows separated by hairlines — document detail meta block. |
| `RowTile` | 40-icon + title + optional subtitle + chevron. Folder picker rows, action group rows. |
| `SectionLabel` | The uppercase mono header above a card or list. |
| `SheetScaffold` / `SheetDoneButton` | Modal-bottom-sheet skeleton. Use this for every sheet — never build a raw `showModalBottomSheet` body. |
| `WarnBanner` | Amber-rail "this is irreversible" banner. For privacy / no-recovery copy, not for transient errors. |
| `BrandMark` | The three-block logo. `size: 24` in headers, `size: 40` on lock, `size: 72` (with `tile: true`) on onboarding. Don't use a different mark. |

If a screen needs a "card with title, meta line, trailing chevron, accent left-tinted icon tile" — that's `RowTile` with `accentIcon: true`. Don't rebuild it.

### When to add a widget

Add a new file in `lib/app/widgets/` when **two screens** would otherwise reach for the same `Container(...decoration:...child: Row(...))`. Single-use compositions stay in the screen file. The bar to add to the library is "I've copy-pasted this once already."

A new widget must:
- Read colors from `context.c`, never hardcode.
- Take its sizes/colors via the props the design language already exposes (`accentIcon`, `primary`, `selected`, `ghost`, `busy`) — don't invent new modifier vocabulary.
- Have a one-line dartdoc on the class explaining the visual role and the design surface it came from.

---

## 3. Screen scaffolding

Every screen lives in `lib/features/<feature>/<screen>.dart` and follows the same outer shape:

```dart
return Scaffold(
  appBar: ...,                    // optional; omit on onboarding/lock
  body: SafeArea(
    child: ...,                   // padding inside, never on Scaffold
  ),
  floatingActionButton: ...,      // FAB only when there's a single primary "add" action
);
```

Notes:

- `Scaffold.backgroundColor` is `c.bg` (set by theme). Don't override.
- The `AppBar` styling is themed: transparent `surfaceTint`, no elevation, `bg` background, `centerTitle: false`. Trailing actions use `IconChipButton(ghost: true)`, not raw `IconButton`.
- `SafeArea` on the body handles the status bar; bottom safe-area is provided by `SheetScaffold` for sheets and by your scroll-view `padding.bottom` for the feed.
- Scroll views: prefer a single outermost `CustomScrollView` or `ListView` per screen. Don't nest a `SingleChildScrollView` inside a `Column` to make a section scroll.
- For loading spinners on a busy region, use a `CircularProgressIndicator` with `strokeWidth: 2.4` — this matches the button busy state.

### Top-level layout templates

There are two recurring shells. New screens should pick one rather than mixing.

**A. Centered narrow column** — onboarding, lock, error states, anything with one focal task.

```dart
SafeArea(
  child: Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [...],
        ),
      ),
    ),
  ),
)
```

The `BrandMark` (40 or 72) sits at the top, then a `headlineLarge` title, then a `bodyMedium` subhead, then the form, then primary CTA.

**B. Feed of cards** — documents list, detail body, sheet bodies with sections.

```dart
SafeArea(
  child: ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 110), // bottom = FAB clearance
    children: [
      SectionLabel('Folder'),
      RowTile(...),
      SectionLabel('Meta'),
      MetaCard(rows: [...]),
      ...
    ],
  ),
)
```

Card list spacing comes from the cards themselves (`SizedBox(height: 10)` between siblings), not from a `Column` `spacing` prop.

### Empty states

Only the documents list shows an illustrated empty state (a 96 px circular surface with an icon, headline, body). Other screens — sheets, detail subsections, search results — get a single line of `bodyMedium` muted text. Don't propose new illustrations.

---

## 4. Interaction rules

These are mostly restated from the brief, but worth keeping near the layout decisions.

- **Primary action per screen**: at most one. If you have a CTA stack, the primary is the topmost `PrimaryActionButton` and everything below is `Outline`/`Ghost`/`Destructive`.
- **Busy states**: in-place — spinner replaces button label, FAB icon, or the action chip's leading icon. **Never** a full-screen blocking overlay or modal progress dialog.
- **Errors**:
  - Hard / blocking errors → inline banner using the theme's `errorContainer` styling (or `WarnBanner` only when the failure is about irreversibility / privacy, not transience).
  - Confirmations and transient info ("Imported 3 file(s)") → `SnackBar` (themed).
- **Long-press**: only used today on folder rows in the folder picker. Don't introduce broader long-press menus on new screens.
- **No splashes**: `splashFactory: NoSplash.splashFactory` is set globally. Use `InkWell` for hit feedback, but expect no ripple. If a tile needs feedback at all, lean on the existing `Material` + `InkWell` pattern in `RowTile`/`AppChip` and don't tweak the splash.
- **Auto-lock**: a screen can be torn down at any moment when the vault locks. Don't hold decrypted bytes in screen-level state for longer than the action requires; let `VaultService` own the lifetime (see [`security.md`](security.md)).
- **No persistent toasts, no banners pinned to the top of the page, no FAB-blocking scrims.**

---

## 5. Iconography

- Icons are Material symbols (`Icons.X`) at three sizes: **16** (inside fields, inside buttons next to a label), **18** (icon-chip buttons, sheet head icons, list-row leading icons in dense rows), **20–24** (hero/tile icons).
- Line weight comes from the Material font itself; don't switch icon families per screen. Cupertino icons are not used.
- Color: icons inside accent-filled surfaces use `c.accentFg`; icons on `surface` use `c.fg`; secondary/decorative icons (prefix in fields, meta-line lock) use `c.muted`.
- For an icon that needs a tinted backing tile (40×40 with rounded corners), use `RowTile(accentIcon: true)` or copy its `iconBg` switch — the three accepted backing colors are `accent`, `accentSoft`, and `surface2`.

---

## 6. Voice & copy

The brief sets the tone; for screens, three concrete rules:

- **Section labels are nouns, uppercased**: `FOLDER`, `TAGS`, `META`, `ACTIONS`, `RECOGNIZED TEXT`. Not verbs, not sentences.
- **Button labels are imperatives, not gerunds**: "Create vault", not "Creating your vault". Two words max where possible.
- **Helper copy under fields and inside warn-banners is technically literal**: "AES-256-GCM • encrypted at rest" is the register; "Your stuff is safe with us" is not. When in doubt, name the algorithm or the guarantee.

Don't use emoji anywhere in the UI. (The lint that `Write` enforces in this repo also forbids emoji in source files unless explicitly asked.)

---

## 7. Dark vs. light

Both themes ship and are first-class. Two practical rules:

- Always test a new screen in both. The cheap way: `MaterialApp.themeMode` flip at runtime, or the system toggle.
- **Don't pick contrast by tone alone.** A `Color(0xFF...)` that's "dark grey" in light mode is not the right color in dark mode; use `c.muted`, `c.border`, `c.surface2`. The `AppColors` definition is the only place to express "this token darkens differently in dark mode."

---

## 8. Performance and stability hygiene for screens

- **Don't use `Border` with non-uniform sides on a `BoxDecoration` that also has a `borderRadius`.** Flutter throws at paint time — there's history of this in `WarnBanner`. If you need an accent rail, use a uniform `Border.all` on the outer container and a separate `Container(width: N, color: ...)` strip inside (clipped via `ClipRRect` if rounded corners must be preserved). See `lib/app/widgets/warn_banner.dart` for the pattern.
- **`Border.all(width: 1)` insets layout by 1 px on every side.** When a fixed-size container has a border *and* internal padding *and* fixed-size children, do the math: outer − 2·border − 2·padding ≥ children. When this is tight (e.g. `BrandMark` at `tile: true`), wrap the children in `FittedBox(fit: BoxFit.scaleDown)` so they degrade safely instead of overflowing 2 px.
- **Don't introduce `RepaintBoundary` or `cacheExtent` tuning preemptively.** The list is short; correctness first.
- **Memory & lifetimes**: a screen that decrypts data must release it on dispose and on lock. The pattern is in `DocumentOpenService` — a screen-level decrypt should mirror it (write to temp, hand off, schedule cleanup) rather than keeping plaintext in widget state.

---

## 9. Adding a new screen — checklist

1. Decide which top-level template (centered column / feed of cards) the screen is.
2. Pick an existing widget for every visual atom (button, field, chip, tile, banner, card). If something is missing, ask whether it's worth a widget — see §2.
3. Set padding from the spacing scale (§1). Don't pick odd numbers.
4. Use `Theme.of(context).textTheme` for type and `context.c` for color. No hex literals.
5. Wire busy / error / empty states using the rules in §4 — inline, no modals.
6. Run on light and dark; verify no `RenderFlex` overflow and no border-radius assertions in the debug console.
7. If the screen reaches a publishable shape, add it to [`features.md`](features.md) so the registry stays current. If it introduces a new use case or repository, follow [`contributing.md`](contributing.md) — a new screen is the cheap part; the wiring and tests are the rest.
