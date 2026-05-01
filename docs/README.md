# SecDockKeeper — Developer Documentation

This folder contains technical documentation for contributors. The top-level
[`README.md`](../README.md) covers the user-facing pitch, build commands, and
high-level security model. These pages dig into the codebase: how layers fit
together, where state lives, why the cryptography is shaped the way it is, and
how to add new features without breaking invariants.

## Table of contents

| Page | What it covers |
| --- | --- |
| [Architecture](architecture.md) | Layered architecture (Screen → Cubit → UseCase → Repository), `AppServices` wiring, dataflow examples |
| [Design guidelines](design-guidelines.md) | Tokens, components, screen scaffolding, interaction rules — the visual contract for new screens |
| [Security model](security.md) | Argon2id KDF, KEK/DEK envelope, AES-GCM AEAD, hidden-tag HMAC, vault lifecycle, what's in memory and for how long |
| [Storage](storage.md) | Filesystem layout, SQLCipher schema, migrations, FTS5 index, blob store |
| [Routing](routing.md) | `go_router` configuration, redirect-based vault gating, sub-routes, sheets |
| [State management](state-management.md) | Cubit/state conventions used in this project, stream subscriptions, side-effect signaling |
| [Use cases registry](usecases.md) | Every use case in the codebase with one-line descriptions and dependencies |
| [Features](features.md) | Per-feature walkthroughs — onboarding, lock, documents, folders, tags, hidden tags, sharing, backup, biometrics |
| [Testing](testing.md) | Test strategy, mocktail patterns, fakes, what's covered and what isn't |
| [Contributing](contributing.md) | Recipes — adding a screen, adding a use case, schema migrations, working with hidden tags |
| [Roadmap](roadmap.md) | Categorized list of functional suggestions — items planned in the README plus net-new ideas |

## How to read this documentation

If you're new to the project, read the root [`README.md`](../README.md) first
for context, then [`architecture.md`](architecture.md). After that, dip into
whatever page matches the change you're making.

If you're looking for a specific piece of code, [`usecases.md`](usecases.md)
and [`features.md`](features.md) link directly to the files involved.

[`CLAUDE.md`](../CLAUDE.md) is a condensed version of `architecture.md` and
`security.md` aimed at AI coding assistants. The two should not drift; if you
change architecture in this folder, update `CLAUDE.md`.
