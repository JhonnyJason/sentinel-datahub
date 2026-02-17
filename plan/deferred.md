# Collection of Deferred Information
Anything that cannot be considered during the current process will be deferred and remembered here. 

## Deferred Items
- **feature:** Data Retrieval Commodities
- **feature:** Data Retrieval Currencies
- **feature:** Data Preprocessing (to-be-refined)
- **refactor:** Pre-adjusted split factor handling — currently `isPreAdjusted` is detected per split event and carried forward implicitly. Cleaner approach: store a single `preAdjusted` flag in `meta` on first detection, verify consistency on future splits, simplify `normalizeEodResponse` accordingly. Also: `mergeSplitFactors` can produce inconsistent `applied` flags when merging pre-adjusted and non-pre-adjusted entries.
