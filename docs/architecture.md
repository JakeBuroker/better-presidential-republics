# Architecture

Better Presidential Republics is built around lightweight country and character state. It does not run a full election simulation; it watches vanilla presidential republic behavior and corrects the cases where vanilla ruler selection clashes with term limits, succession, or eligibility rules.

## Flow

```text
Game on-actions
    -> Presidential scripted effects
    -> Country and character variables
    -> Traits, roles, and modifiers
    -> GUI scripted values and localization
    -> Politics and election panels
```

## Main Entry Points

- `common/on_actions/zzz_vptl_term_limits.txt` wires the system into startup, monthly country pulses, election campaign start/end, ruler selection, and character death.
- `common/scripted_effects/zzz_vptl_term_limits.txt` holds most presidential state changes.
- `common/scripted_triggers/zzz_vptl_presidential_eligibility.txt` holds reusable candidate and successor eligibility checks.
- `common/scripted_effects/zzz_vptl_presidential_number_traits.txt` applies numbered president traits.
- `common/customizable_localization/` and `localization/english/vptl_term_limits_l_english.yml` expose readable state to the UI.
- `gui/politics_panel_overview.gui` and `gui/election_panel.gui` are whole-file overrides for the visible government and campaign panels.

## Source Of Truth

- Current tracked president: country variable `vptl_presidential_current_ruler`.
- Current successor: country variable `vptl_presidential_successor`; visible role `character_role_vptl_presidential_successor`; trait `vptl_current_presidential_successor_trait`.
- Elected presidential term count: character variable `vptl_presidential_terms_served`; the initial incumbent receives one idempotent credit for the elected term already underway, while succession alone does not add a term.
- President number: character variable `vptl_presidential_order_number`, backed by country counter `vptl_presidential_order_counter`.
- Campaign ticket display: campaign variables `vptl_presidential_ticket_candidate`, `vptl_presidential_ticket_running_mate`, `vptl_presidential_opposition_candidate`, and `vptl_presidential_opposition_running_mate`.
- Election settlement: `vptl_settle_presidential_election` captures `vptl_presidential_vanilla_selected_ruler`, classifies `vptl_presidential_winning_ticket_side`, installs `vptl_presidential_final_elected_ruler` and `vptl_presidential_final_running_mate`, and uses `vptl_presidential_election_settlement_in_progress` / `vptl_presidential_election_settled` as reentrancy guards.
- Election-transition state: country variable `vptl_presidential_election_transition`; legacy forced-handoff variables remain limited to non-election succession compatibility.
- Death-succession state: country variables `vptl_presidential_death_succession_lock` and `vptl_presidential_death_successor`.
- Accession type: character variables `vptl_presidential_accession_elected`, `vptl_presidential_accession_succeeded`, `vptl_presidential_accession_interim`, `vptl_presidential_accession_provisional`, and `vptl_presidential_accession_initial`.
- Former-president service history: character variables `vptl_presidential_terms_served`, `vptl_presidential_years_served`, `vptl_presidential_order_number`, traits `vptl_presidential_history_marker*`, and service modifiers/traits.
- Vice-presidential or constitutional-successor service history: `vptl_vice_presidential_terms_served` and related traits are maintained by the successor-recording effects. `vptl_presidential_initial_successor_term_seeded` credits the valid starting successor once.
- Eligibility layers: `vptl_presidential_basic_eligibility` handles age/origin; `vptl_presidential_candidate_eligible` handles elected-president selection; `vptl_presidential_new_successor_candidate_eligible` handles a new running-mate/successor term; and `vptl_presidential_sitting_successor_handoff_eligible` protects constitutional handoff for the sitting successor.
- USA-specific eligibility: `vptl_presidential_origin_eligible`, `vptl_presidential_origin_ineligible`, `vptl_usa_natural_born_presidential_eligible`, age checks under the basic eligibility layer, and historical seed/fallback effects.

## Presidential History Ledger

The office ledger uses 128 append-only country-variable archive slots. Every slot stores the immutable president identity, associated successor, party and IG, ordinal, accession and departure markers, term counts, GDP and prestige snapshots, closed state, and month/year dates. Slots are never reused during a campaign, so completed episodes remain available and a returning president receives a separate later episode.

BPR follows the locally installed National History mod's proven architecture without depending on it: a scripted upper-left map button refreshes a latest-50 country-variable display cache and opens a standalone centered window. Durable `recent_*` records are copied into separate `display_*` variables only when the window opens, exactly separating stored state from GUI-facing state. The first stable view is text-only and reads those display variables through direct guarded `Country.MakeScope.Var(...)` chains, so normal Politics performance is unaffected and BPR remains compatible with National History's separate button and namespace.

Every genuine accession atomically captures the new archive record and shifts the previous newest records down through the 50-record recent cache. Closing updates the active archive slot and newest recent record together before any successor record opens. GDP, prestige, and term values for the active episode refresh only when the ledger opens or an existing lifecycle path explicitly refreshes it; the click then copies the recent cache into the presentation cache. Month/year dates use National History's proven explicit game-date table. No new global pulse is used.

`vptl_open_presidential_history_episode`, `vptl_request_close_presidential_history_episode`, and `vptl_sync_presidential_history_after_ruler_change` are called from existing startup, monthly, ruler-selection, election, and death hooks after BPR ruler repairs. Generic synchronization is frozen during campaigns, settlement, and delayed inauguration. Only explicit death-succession and inauguration commits may cross those guards. Reelection refreshes the same open episode, while a different inaugurated ruler closes and opens records in one installation sequence. Detailed law/war event lists and standalone VP episode records remain follow-up work.

## Current Behavior

Victoria 3 determines the winning political side, then BPR certifies that side's final visible eligible ticket. Delayed inauguration remains authoritative for configured countries. The history ledger opens only after actual office installation or the initial tracked ruler, and closes once on genuine departure.

When a character becomes president, current successor, vice-president, and former-president roles are removed from that character without deleting historical presidential or successor service variables and traits. A living outgoing president regains the former-president role. Nonconsecutive presidencies are allowed, but one character still stores only one president-number variable rather than a separate number for each service episode.

## Performance Notes

The mod already uses monthly country and election hooks. New logic should avoid broad scans unless guarded by strict country triggers, campaign state, or one-time setup variables. Character scans should be limited to eligible presidential republics and should be explained in the change summary.
