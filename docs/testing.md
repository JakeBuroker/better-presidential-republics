# Testing

Run static validation first:

```powershell
powershell -ExecutionPolicy Bypass -File tools\validate_mod.ps1 -ModPath .
```

Static validation passing means the files are structurally cleaner; it does not mean Victoria 3 booted or that the election system worked in-game.

## Manual Test Matrix

| Test ID | Country/start | Required setup | Actions | Expected ruler | Expected successor | Expected traits/UI | Known limitations | Last tested game version | Result |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| BPR-US-1836-BOOT | USA, January 1 1836 | Vanilla plus Better Presidential Republics; optional Cheat Pro for law switching only | Start a new game and open Politics > Government | Andrew Jackson remains ruler | Successor comes from the available vanilla eligible politician pool | Jackson shows President No. 7, term info, and leaving date | BPR should not create non-vanilla historical stand-ins; character packs may add their own historical candidates | 1.13.* | Untested in this checklist |
| BPR-US-1836-CAMPAIGN | USA, 1836 campaign | Same as above | Open election campaign panel during 1836 election | Andrew Jackson remains incumbent unless he dies/is removed | Candidate strip uses available vanilla eligible politicians | Candidate strip appears above poll graph; no president-elect title yet | Vanilla party leaders can shift if outside mods alter IG leaders | 1.13.* | Untested in this checklist |
| BPR-US-1836-DEATH | USA, 1836 campaign | Same as above | Kill or remove Andrew Jackson during campaign | An eligible vanilla successor should take office | A new eligible successor should be selected | One clean transition notification; campaign panel should not reset to nonsense candidates | Needs user-reported in-game result | 1.13.* | Untested in this checklist |
| BPR-US-1836-ELECTION-END | USA, December 1836 | Same as above | Let the 1836 election resolve | Winning eligible candidate should take/keep office according to current immediate-handoff rules | Successor should refresh after ruler stabilizes | Election result text should name the elected president where localization supports it | No delayed inauguration yet | 1.13.* | Untested in this checklist |
| BPR-US-AGE-ORIGIN | USA after presidential republic is active | Cheat Pro allowed for fast law changes | Try generated or manually marked candidates | Under-35 or origin-ineligible USA candidates should not be selected | Eligible successor should be chosen if ruler is invalid | USA age/origin markers behave visibly through traits/modifiers where applicable | Birthplace is approximated through available character/home-country data | 1.13.* | Untested in this checklist |
| BPR-NON-US | Any non-USA presidential republic | Vanilla plus BPR | Run several years through election | Normal presidential behavior continues | Successor tracking should not apply USA natural-born age/origin rules | President number and successor UI should remain stable where supported | Country-specific rules are not fully implemented yet | 1.13.* | Untested in this checklist |
| BPR-GUI-COMPAT | Any presidential republic | Add one known GUI-overriding mod at a time | Open Government and Election panels | No crash; ruler and successor still visible | No duplicate/overlapping text | Whole-file GUI overrides may require a compatibility patch | Load order matters | 1.13.* | Untested in this checklist |

## Campaign Death Regression Checklist

Use a presidential republic with an active election campaign, then test these in separate reloads or separate campaigns:

1. Kill the incumbent-side presidential candidate.
2. Kill the incumbent-side running mate.
3. Kill the opposition presidential candidate.
4. Kill the opposition running mate.
5. Kill the tracked successor when that character is also displayed on the ticket.

Expected result for each case: the custom election panel remains usable or immediately repopulates, dead portraits disappear, blank character scopes are not shown, the election-transition state is not restarted, and the election can still finish normally.

When a presidential candidate dies, that same ticket's surviving running mate should move into the presidential slot and only its newly vacant running-mate slot should refill. Killing a running mate should refill only that running-mate slot. The opposite ticket must remain unchanged, and a character whose owner and home country are identical must not cause two repair passes.

## Vanilla-Aligned Election Regression Checklist

Test these in order:

1. Reproduce the Winfield Scott / John C. Calhoun case: the prior VP/successor is Winfield Scott, the relevant eligible incumbent-party or IG leader is John C. Calhoun, and the incumbent cannot run.
2. Run an eligible-incumbent election.
3. Run a term-limited-incumbent election.
4. Run an opposition victory.
5. Kill each ticket position separately during a campaign.
6. Force or reproduce an invalid vanilla winner: term-limited incumbent, dead candidate, or USA-ineligible candidate.

Expected result: Victoria 3's selected ruler identifies the winning political side, the displayed eligible ticket head for that side becomes president, its running mate becomes VP/successor, the losing ticket remains out of office, and normal elections do not create a BPR presidential-transition notification.

## Ticket-Authoritative Settlement Checklist

Run each case with `vptl_presidential_debug_logging` enabled when diagnosing ordering or notification problems.

| Case | Visible final ticket | Vanilla-selected ruler | Expected final BPR ruler | Expected successor | Maximum popups |
| --- | --- | --- | --- | --- | --- |
| Incumbent-party mismatch | Record both incumbent ticket names | Different politician from the same incumbent party | Displayed incumbent head | Displayed incumbent running mate | Prefer 1; never more than 2 |
| Opposition-party mismatch | Record both opposition ticket names | Different politician from the same opposition party | Displayed opposition head | Displayed opposition running mate | Prefer 1; never more than 2 |
| Direct candidate match | Record winning ticket | Same as displayed head | Vanilla-selected/displayed head, with no second ruler assignment | Displayed running mate | Prefer 1; never more than 2 |
| Invalid winner | Record winning ticket after any death reroll | Dead, term-limited, or USA-ineligible politician | Eligible replacement from the same winning party | Winning running mate or same-side replacement | Prefer 1; never more than 2 |
| Ambiguous side | Record both tickets | Party and IG match neither or both tickets | Valid vanilla-selected ruler | Normal eligible successor | Prefer 1; never more than 2 |

For notification checks, record the visible title, named ruler, source key, and order. A normal election should now show only the accurate election-results card. Death succession should produce the BPR Presidential Transition card without a generic new-ruler card. Non-presidential ruler changes must retain vanilla behavior.

## Repeated Succession Regression Checklist

Test these in order:

1. Kill the incumbent outside a campaign.
2. Kill the incumbent during a campaign.
3. Kill the newly promoted president shortly afterward.
4. Kill several successive presidents and successors.
5. Kill a ticket member without killing the ruler.
6. Let the election finish after one or more campaign deaths.

Expected result for each actual presidential death: one final intended successor becomes ruler, president numbering changes at most once, accession type is `Succeeded to office`, current-ruler and successor variables resynchronize, the previous successor role is removed from the new president, no more than one BPR transition notification posts for that ruler, and the custom election ticket remains usable.

## Reporting Template

When reporting a manual test, include:

- Active mods, especially GUI mods and character packs.
- Country and exact in-game date.
- Current ruler, successor, and visible candidate strip.
- What action was taken.
- What notification appeared.
- Whether the result survived one monthly tick.
