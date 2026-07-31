# Changelog

## 0.1.4

- Current baseline for Better Presidential Republics.
- Tracks presidential terms, president numbers, successor/vice-president state, and basic USA eligibility rules.
- Adds government and election panel UI support.
- Static validator available at `tools/validate_mod.ps1`.
- Makes the final visible winning ticket authoritative after vanilla determines the winning political side.
- Guards election settlement against nested ruler-selection callbacks and suppresses duplicate ruler notifications only around BPR-directed handoffs.
- Suppresses vanilla's temporary election-ruler toast for the duration of a BPR presidential campaign so the finalized results card is authoritative.
- Prevents duplicate owner/home-country death repairs and promotes only a dead ticket head's own surviving running mate before filling that ticket's new VP vacancy.
