# Better Presidential Republics: Features and Low-CPU Ideas

## Current Feature Set

- Presidential term tracking: first elected term, second elected term, term-limited status, expected office-leaving date, and one-time credit for the initial incumbent's underway term.
- Vice-president/successor tracking: visible successor in the government panel, one-time credit for the initial successor, and ineligibility for selection to a third successor term without breaking sitting-successor handoff.
- Stable succession handling: when a president dies, retires, or is removed, the tracked successor is promoted where possible instead of a random party/IG figure.
- Election edge-case repair: catches campaign-period ruler swaps, term-limited winners, and ineligible USA winners.
- President numbering: displays the president number in the government panel and stores it on the character history marker.
- Numbered president markers: adds static president-number traits for No. 1 through No. 60, with a generic fallback for later offices.
- Accession type marker: distinguishes Elected, Succeeded to office, Interim, and Appointed/Provisional service.
- Former office markers: former presidents and vice presidents retain visible history traits/modifiers showing years and terms served, plus small prominence bonuses for tracked executive service.
- Current successor marker: the active vice president or constitutional successor is visibly tagged as a presidential successor.
- Constitutional flavor line: a small government-panel line explains the presidential system without adding gameplay weight.
- Successor title coverage: uses true vice-president labels where appropriate and cabinet/legislative stand-ins for countries without a clean VP office.
- Vanilla-safe character handling: uses available vanilla politicians and remains compatible with external character packs without shipping replacement historical templates.

Former presidents remain eligible to run for president when otherwise qualified, but cannot be selected for a new vice-presidential or constitutional-successor term. Current presidents do not retain former-president, vice-president, or successor roles. Separate president numbers for nonconsecutive service episodes remain deferred.

## Low-CPU Follow-Up Ideas

- Country-specific term rules: one-term limits, no-immediate-reelection rules, or unlimited reelection for selected tags where historically useful.
- More successor office titles: expand cabinet/legislative successor names for additional Latin American republics.
- Election outcome log: a small notification line for election winners, succession promotions, and provisional presidents.
- Constitutional crisis flavor: rare, event-hooked notes when a term-limited or ineligible politician is bypassed.
- Former president elder-statesman flavor: tiny prestige/approval marker or tooltip-only status, kept cosmetic to avoid balance noise.
- Historical candidate nudges: add a few more vanilla-safe historical politicians where they improve presidential lineups.
- Better eligibility by country: static, country-specific home-country checks for obvious cases beyond the USA.
- Succession-law labels: explain whether the successor is a true VP, legislative officer, cabinet officer, or gameplay stand-in.
- Optional election journal polish: lightweight text updates only, avoiding monthly polling or large candidate scans.
