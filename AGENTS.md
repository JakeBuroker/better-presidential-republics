# Better Presidential Republics Agent Instructions

This repository is a Victoria 3 Clausewitz/Jomini script mod, not a normal application. Treat scripted effects, triggers, on-actions, localization, and GUI files as the project surface.

Before changing behavior, read `README.md`, `docs/architecture.md`, and `docs/testing.md`. Use `docs/roadmap.md` to distinguish future ideas from implemented behavior.

Project conventions:

- Preserve UTF-8 BOM encoding for `.txt`, `.yml`, and `.gui` files.
- Use the `vptl_` prefix for new scripted effects, triggers, variables, traits, modifiers, localization keys, and GUI-facing identifiers.
- Treat `common/scripted_effects/zzz_vptl_term_limits.txt` as the primary implementation layer for presidential logic.
- Prefer scripted effects and triggers over new GUI-only state.
- Do not modify unrelated GUI files.
- Treat GUI files as whole-file overrides with compatibility risk. Any GUI edit must explain which panel is overridden and what load-order risk it creates.
- Do not add new monthly pulses, broad `every_country` scans, or repeated character scans without explaining the performance impact.
- Avoid copying personal cleanup-pack, ECCHI, JOI, or donor-mod logic into this standalone mod unless it is guarded as an optional fallback and remains vanilla-safe.
- Do not claim a feature was game-tested unless the user reported an in-game result.

Validation and reporting:

- Run `powershell -ExecutionPolicy Bypass -File tools\validate_mod.ps1 -ModPath .` after every implementation.
- Static validation only checks repository health; it does not prove Victoria 3 booted or that election behavior is correct.
- Report files changed, identifiers added or changed, validation results, and manual test cases still needed.

High-risk integration files:

- `common/scripted_effects/zzz_vptl_term_limits.txt`
- `common/on_actions/zzz_vptl_term_limits.txt`
- `gui/politics_panel_overview.gui`
- `gui/election_panel.gui`

Avoid parallel feature work in those files unless each branch has a very narrow purpose.

