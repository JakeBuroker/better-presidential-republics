# Presidential Election Settlement

## Vanilla Notification Inventory

The locally installed Victoria 3 1.13 files establish two vanilla election-related toast sources:

| Visible title | Key | Source | Scope | Conditional suppression | BPR handling |
| --- | --- | --- | --- | --- | --- |
| Character name followed by “is our new …” | `new_ruler` / `notification_new_ruler_*` | `common/on_actions/00_code_on_actions.txt`, `on_new_ruler` | Character, with `previous` character scope | The owner country variable `hide_ruler_change_notification` prevents the post | BPR owns a campaign-scoped suppression marker so vanilla cannot announce its temporary election pick; death transitions use the BPR card instead |
| Election! | `election_results` / `notification_election_results_*` | Engine-owned election completion; no scripted `post_notification` call exists in the installed `common` or `events` files | Country | No safe country trigger is exposed in `common/messages/00_messages.txt` | Retained; BPR extends its description with the settled president and successor |
| Presidential Transition | `vptl_presidential_transition` | `vptl_post_presidential_transition_notification` | Saved country and final ruler scopes | Fully controlled by BPR | Used for death, removal, and constitutional handoff; never posted by normal election settlement |

`common/messages/00_messages.txt` defines both vanilla messages as toasts but exposes no scripted visibility trigger. Blank localization would therefore leave an empty card and is not used.

## Winner Resolution

`vptl_settle_presidential_election` captures the ruler selected by Victoria 3 before changing any ticket state. It determines the winning side in this order:

1. Direct identity match with either displayed presidential candidate.
2. An unambiguous party match between the vanilla-selected ruler and exactly one displayed candidate.
3. An unambiguous interest-group match between the vanilla-selected ruler and exactly one displayed candidate.
4. If none is conclusive, mark the result ambiguous and retain a valid vanilla-selected ruler.

The installed script API exposes no direct winning-party scope. `GetLastElectionResultsTooltip` is localization/UI data and is not parsed.

## Final Ticket

For a resolved side, the displayed ticket head is selected when eligible. If that character became invalid, replacement stays inside the winning party: first an eligible party IG leader, then another eligible party politician, then the winning IG. Broader constitutional fallback is reached only after those pools are empty, and losing ticket members are excluded.

The displayed winning running mate becomes `vptl_presidential_successor` when eligible. If invalid, BPR searches the final president's party and then their IG before using normal successor selection. The successor role display is rebuilt after the final president is stable, and presidential and vice-presidential terms each retain their existing one-transition guards.

## Reentrancy And Notifications

`vptl_presidential_election_settlement_in_progress` blocks nested `on_ruler_selected` finalization. A nested ruler-selection callback may synchronize the current ruler but cannot re-enter settlement, repair the completed ticket, or post a normal-election transition notification. Ticket variables are removed only after the final ruler, successor, numbering, and term records are complete.

At campaign start, BPR sets `vptl_presidential_election_ruler_notification_suppression` and the vanilla `hide_ruler_change_notification` variable. This is necessary because the engine creates the vanilla ruler card before BPR settlement can replace its temporary selection. Settlement shortens the vanilla marker to one final day and removes BPR's ownership marker. The expected normal-election result is one accurate election-results card and no BPR transition card. A presidential death during the campaign remains visible through the BPR Presidential Transition card.

## Gated Diagnosis

Setting the country variable `vptl_presidential_debug_logging` enables checkpoint logging for campaign start and ticks, ticket rebuilds, election end, ruler selection, settlement, each BPR ruler assignment, BPR transition notifications, and settlement completion. The logger records the ruler, tracked ruler, all four ticket slots, party/IG data where available, selected/final rulers, and settlement guards. It is silent by default.
