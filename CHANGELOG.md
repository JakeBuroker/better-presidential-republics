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
- Seeds an ordinary initial incumbent with one elected-term credit and a valid initial successor with one successor-term credit without repeating on reload or monthly initialization.
- Separates elected-president eligibility, new successor selection, and sitting-successor handoff so two-term successors cannot receive a third deputy term but can still succeed or run for president.
- Cleans current presidents of former-president, vice-president, and successor roles while preserving their historical service variables and traits.
- Guards ambiguous election-side fallback and records the elected president's new term only after the completed ticket has been installed and cleared.
