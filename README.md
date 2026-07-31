# Better Presidential Republics

A lightweight Victoria 3 gameplay/UI mod that makes presidential republics feel more legible and historical without adding heavy background simulation.

## Features

- Tracks presidential terms for elective presidential republics.
- Marks second-term presidents as term-limited before the next election cycle.
- Tracks vice-presidential/successor terms and blocks overused successors.
- Blocks former presidents from being picked as vice presidents/successors.
- Adds USA presidential origin checks using explicit historical markers, generated-character home country, and a conservative historical fallback.
- Promotes the tracked vice president/successor when the president dies or is removed.
- Corrects common election and campaign edge cases where the game promotes the wrong politician.
- Shows the president number beside the ruler title in the Politics > Government panel.
- Shows current term status and expected office-leaving date in the government panel.
- Shows a vice president, constitutional successor, or designated successor in the government panel.
- Shows presidential candidates in the election campaign panel, including the current president and recognized handoff candidate/successor.
- Keeps the normal successor or vice-president title during campaigns. President-elect is reserved for a future delayed-handoff and inauguration system.
- Uses country-specific successor titles where easy: Vice President, Secretary of State, President of the Senate, Minister of the Interior, and fallback Designated Successor.
- Adds constitutional flavor text for presidential republics and concentrated/caudillo-style presidencies.
- Adds former/current president and vice president history markers with terms, years served, and accession type.
- Adds numbered president history traits for president numbers 1-60, with a generic fallback beyond that.
- Marks the current constitutional successor directly on their character.
- Gives former presidents and vice presidents small visible service traits that mirror their tracked service.
- Adds a presidential transition notification when a tracked president changes.
- Seeds easy 1836 presidential numbering for several vanilla presidential republics.
- Uses vanilla character templates for startup and succession handling. Legacy fallback templates are kept inert for save compatibility, but the live startup logic does not create or target non-vanilla fallback politicians.

## Compatibility

- Built for vanilla Victoria 3 1.13.
- No dependency on Victorian Century, ECCHI, or the personal cleanup compatch.
- Should be compatible with Victorian Century content unless another mod also overrides `gui/politics_panel_overview.gui` or heavily changes presidential election/ruler selection.
- GUI conflicts require a load-order patch, because Victoria 3 uses whole-file GUI overrides.

## Validation

Run:

```powershell
powershell -ExecutionPolicy Bypass -File tools\validate_mod.ps1 -ModPath .
```

Static validation is required before testing, but it is not a substitute for an in-game boot and campaign run.

## Documentation

- `AGENTS.md` contains repo-specific instructions for future Codex work.
- `docs/architecture.md` explains the current state model and implementation flow.
- `docs/testing.md` lists repeatable in-game test cases.
- `docs/roadmap.md` separates planned features from current behavior.

## Current Testing Priorities

- USA 1836 start: Andrew Jackson should show as President No. 7 and term tracked.
- USA 1836 succession/election path: generated and historical candidates should respect USA origin and age rules.
- USA 1836 startup: BPR should not create a non-vanilla Martin Van Buren fallback; the visible successor should come from the available vanilla eligible politician pool.
- Open election campaign panel: presidential republics with a tracked successor should show the Presidential Candidates strip above the poll graph.
- USA 1836 campaign: Andrew Jackson can be marked term-limited, but should remain president until the December 7, 1836 election resolves unless he dies or is removed.
- Term-limited election campaign: the successor should keep the normal successor or vice-president title during the campaign. President-elect is reserved for the future delayed-handoff system.
- USA former president handling: John Quincy Adams should remain recorded as President No. 6 and term-limited.
- Generated USA politicians: eligible only when their home country is the USA and age is at least 35.
- Non-USA presidential republics: should ignore USA age/origin rules and keep normal presidential behavior.
- USA edge cases: a manually blocked character with `vptl_presidential_origin_ineligible` should not be selected even if they are Yankee/Dixie/Afro-American.
