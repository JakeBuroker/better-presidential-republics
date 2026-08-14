# Roadmap

This file separates planned features from current behavior. Do not treat roadmap items as implemented unless the README and scripted effects confirm them.

## Current Baseline

- Immediate presidential succession and election correction.
- Two-term tracking and term-limited markers.
- Successor and vice-president display in the government panel.
- Presidential candidate strip in the election panel.
- USA-specific age and origin eligibility checks.
- President numbering and former-service history markers.
- Presidential office history ledger with 128 append-only country records and an on-demand standalone latest-50 window.
- Transition notification when a tracked president changes.

## Near-Term Stabilization

- Keep campaign tickets locked once selected, except when a listed candidate dies or becomes invalid.
- Make election result text consistently name the winning president.
- Continue reducing duplicate character interactions when optional character packs are enabled.
- Expand validator coverage before broader feature work.

## Future Mechanics

- Detailed presidential law/war event history and standalone VP episode records.
- Constitution journal for presidential republic setup.
- Country-specific term, age, and birthplace rules.
- More country-specific successor offices and clearer succession-law labels.

## Release Discipline

- `0.1.4`: current baseline.
- `0.1.5`: bug fixes, documentation, and validator/workflow cleanup.
- `0.2.0`: first meaningful new presidential mechanic.
- `1.0.0`: stable Workshop-ready release.

Only bump `descriptor.mod` after a coherent tested batch. Only tag a release after static validation and the manual test checklist both pass.

