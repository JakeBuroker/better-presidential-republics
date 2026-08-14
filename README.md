# Better Presidential Republics

A lightweight Victoria 3 gameplay/UI mod that makes presidential republics feel more legible and historical without adding heavy background simulation.

## Features

- Tracks elected presidential terms for elective presidential republics, including the term already underway when BPR first begins tracking a country.
- Marks second-term presidents as term-limited before the next election cycle.
- Tracks vice-presidential/constitutional-successor terms, credits the starting successor's term once, and blocks selection for a third successor term.
- Blocks former presidents from being picked as vice presidents/successors.
- Adds USA presidential origin checks using explicit historical markers, generated-character home country, and a conservative historical fallback.
- Promotes the tracked vice president/successor when the president dies or is removed.
- Keeps sitting successors eligible for constitutional handoff even after their second successor term, while leaving them eligible to run for president when otherwise qualified.
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
- When the personal ECCHI-backed USA roster is present, seeds John Quincy Adams with one prior presidential term and Martin Van Buren with one prior vice-presidential term; Jackson's and Calhoun's existing two-term seeds remain unchanged.
- Uses vanilla character templates for startup and succession handling and does not ship character-pack stand-ins for missing historical politicians.
- Adds an on-demand standalone Presidential Library with a 128-episode append-only archive and latest-50 compact display. Records retain the stored president portrait and service number, month/year span, accession and departure reason, country-specific deputy, party and IG, boundary-frozen GDP, population, average SoL, prestige, numeric prestige rank and power category, plus up to eight successfully activated laws with overflow.

An uninterrupted reelection keeps the same episode and number. A president returning after an intervening presidency receives a new episode and the next service number, while earlier archive records remain immutable.

## Compatibility

- Built for vanilla Victoria 3 1.13.
- No dependency on Victorian Century, ECCHI, or the personal cleanup compatch.
- Should be compatible with Victorian Century content unless another mod also overrides `gui/politics_panel_overview.gui` or heavily changes presidential election/ruler selection.
- GUI conflicts require a load-order patch, because Victoria 3 uses whole-file GUI overrides.
