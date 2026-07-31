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
- Presidential term count: character variable `vptl_presidential_terms_served`.
- President number: character variable `vptl_presidential_order_number`, backed by country counter `vptl_presidential_order_counter`.
- Campaign ticket display: campaign variables `vptl_presidential_ticket_candidate`, `vptl_presidential_ticket_running_mate`, `vptl_presidential_opposition_candidate`, and `vptl_presidential_opposition_running_mate`.
- Election settlement: `vptl_settle_presidential_election` captures `vptl_presidential_vanilla_selected_ruler`, classifies `vptl_presidential_winning_ticket_side`, installs `vptl_presidential_final_elected_ruler` and `vptl_presidential_final_running_mate`, and uses `vptl_presidential_election_settlement_in_progress` / `vptl_presidential_election_settled` as reentrancy guards.
- Election-transition state: country variable `vptl_presidential_election_transition`; legacy forced-handoff variables remain limited to non-election succession compatibility.
- Death-succession state: country variables `vptl_presidential_death_succession_lock` and `vptl_presidential_death_successor`.
- Accession type: character variables `vptl_presidential_accession_elected`, `vptl_presidential_accession_succeeded`, `vptl_presidential_accession_interim`, `vptl_presidential_accession_provisional`, and `vptl_presidential_accession_initial`.
- Former-president service history: character variables `vptl_presidential_terms_served`, `vptl_presidential_years_served`, `vptl_presidential_order_number`, traits `vptl_presidential_history_marker*`, and service modifiers/traits.
- Vice-presidential service history: successor variables and traits are maintained by the successor-recording effects in `zzz_vptl_term_limits.txt`.
- USA-specific eligibility: `vptl_presidential_origin_eligible`, `vptl_presidential_origin_ineligible`, `vptl_usa_natural_born_presidential_eligible`, age checks in `vptl_presidential_candidate_eligible`, and historical seed/fallback effects.

## Current Behavior

The current system has immediate handoff behavior. Victoria 3 determines the winning political side, then BPR installs that side's final visible eligible ticket. There is no delayed inauguration period; any "president-elect" wording remains future roadmap language.

## Performance Notes

The mod already uses monthly country and election hooks. New logic should avoid broad scans unless guarded by strict country triggers, campaign state, or one-time setup variables. Character scans should be limited to eligible presidential republics and should be explained in the change summary.
