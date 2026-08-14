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

The office ledger uses 128 append-only country-variable archive slots. Every slot stores the immutable president identity, associated constitutional deputy, party and IG, ordinal, accession and departure markers, GDP, population, average SoL, prestige, numeric prestige rank and power-category snapshots, up to eight enacted-law scopes plus overflow, closed state, and month/year dates. Slots are never reused during a campaign. Consecutive reelection keeps one episode and number. The normal accession path supplies each new ruler's number; the ledger advances the counter itself only when a former president returns after an intervening presidency with an older stored number.

BPR follows the locally installed National History mod's proven architecture without depending on it: a scripted upper-left map button copies the latest-50 country-variable cache into a standalone centered window. Durable `recent_*` records are copied into separate `display_*` variables only when the window opens, exactly separating stored state from GUI-facing state. GDP and population percentage changes are calculated only for completed records in that display copy and are guarded against zero starts. Compact cards use guarded stored-character, party, IG, and law scopes, so normal Politics performance is unaffected and BPR remains compatible with National History's separate button and namespace.

Every genuine accession atomically captures the new archive record and shifts the previous newest records down through the 50-record recent cache. Closing updates the active archive slot and newest recent record together before any successor record opens. Economic and social metrics, prestige, numeric rank, and power category are captured only at accession and departure; opening the library refreshes only the lightweight associated-deputy field before copying the presentation cache. Numeric rank is calculated from countries with strictly greater prestige only at those two boundaries, so ties share a position and no ranking scan runs on a pulse or click. The first tracked USA Jackson episode is seeded to March 1829; later Jackson episodes use their actual game accession month and year. No new global pulse is used.

`vptl_open_presidential_history_episode`, `vptl_request_close_presidential_history_episode`, and `vptl_sync_presidential_history_after_ruler_change` are called from existing startup, monthly, ruler-selection, election, and death hooks after BPR ruler repairs. Generic synchronization is frozen during campaigns, settlement, and delayed inauguration. Only explicit death-succession and inauguration commits may cross those guards. Reelection refreshes the same open episode, while a different inaugurated ruler closes and opens records in one installation sequence. The proven `on_law_activated` callback records successful laws through a per-episode dedupe list and never polls enactment attempts. War event lists and standalone VP episode records remain follow-up work.

## Current Behavior

Victoria 3 determines the winning political side, then BPR certifies that side's final visible eligible ticket. Delayed inauguration remains authoritative for configured countries. The history ledger opens only after actual office installation or the initial tracked ruler, and closes once on genuine departure.

When a character becomes president, current successor, vice-president, and former-president roles are removed from that character without deleting historical presidential or successor service variables and traits. Every president and captured deputy also receives the zero-priority `character_role_vptl_presidential_history_subject` archival role so country-owned ledger references survive vanilla retirement without overriding an active political or constitutional title. Closure preserves the exact character in `vptl_presidential_history_current_president`; a living outgoing holder receives the Former President role before installation can retire them.

Presidential numbering follows the country's established sequence. Seeded traditions such as Mexico retain their historical counter even when ledger tracking begins between previously numbered officeholders; countries with no explicit presidential lineage begin at No. 1. Reelection keeps the same episode and number. A genuinely new holder, including a former president returning after an intervening presidency, receives the next number while earlier archive records remain immutable.

## Performance Notes

The mod already uses monthly country and election hooks. New logic should avoid broad scans unless guarded by strict country triggers, campaign state, or one-time setup variables. Character scans should be limited to eligible presidential republics and should be explained in the change summary.
