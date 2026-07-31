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

## Reporting Template

When reporting a manual test, include:

- Active mods, especially GUI mods and character packs.
- Country and exact in-game date.
- Current ruler, successor, and visible candidate strip.
- What action was taken.
- What notification appeared.
- Whether the result survived one monthly tick.
