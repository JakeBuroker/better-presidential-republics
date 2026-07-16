# Presidential Term Limits and Successors

A lightweight Victoria 3 gameplay/UI mod that adds presidential term tracking and a visible vice president / successor for presidential republics.

## Features

- Tracks first and second presidential terms for elective presidential republics.
- Marks second-term presidents as term-limited before the next election cycle.
- Shows term status and expected office-leaving date in the Politics panel.
- Shows a vice president or designated successor when one can be identified.
- Picks successors from the president's party first, then from the president's interest group.
- Avoids selecting previous presidents as vice presidents/successors.
- Includes tiny vanilla-safe startup characters for Martin Van Buren and Lorenzo de Zavala, who are missing as start-date successor figures in vanilla.

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