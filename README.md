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
- Keeps the normal successor or vice-president title during campaigns.
- Uses country-specific successor titles where easy: Vice President, Secretary of State, President of the Senate, Minister of the Interior, and fallback Designated Successor.
- Adds constitutional flavor text for presidential republics and concentrated/caudillo-style presidencies.
- Adds former/current president and vice president history markers with terms, years served, and accession type.
- Adds numbered president history traits for president numbers 1-60, with a generic fallback beyond that.
- Marks the current constitutional successor directly on their character.
- Gives former presidents and vice presidents small visible service traits that mirror their tracked service.
- Adds a presidential transition notification when a tracked president changes.
- Seeds easy 1836 presidential numbering for several vanilla presidential republics.
- Uses vanilla character templates for startup and succession handling and does not ship character-pack stand-ins for missing historical politicians.

## Compatibility

- Built for vanilla Victoria 3 1.13.
- No dependency on Victorian Century, ECCHI, or the personal cleanup compatch.
- Should be compatible with Victorian Century content unless another mod also overrides `gui/politics_panel_overview.gui` or heavily changes presidential election/ruler selection.
- GUI conflicts require a load-order patch, because Victoria 3 uses whole-file GUI overrides.
