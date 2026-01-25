# Operational Notes

## Important Code Locations

### Entry Point
- `sources/source/index/index.coffee` - Service bootstrap

### Module Configuration
- `sources/source/configmodule/configmodule.coffee` - All config exports
- `.config.json` (gitignored) - Secrets and credentials

### Business Logic
- `sources/source/startupmodule/startupmodule.coffee` - Startup orchestration
- `sources/source/datamodule/datamodule.coffee` - Central data layer (freshness, storage, slicing)
- `sources/source/marketstackmodule/marketstackmodule.coffee` - MarketStack API client
- `sources/source/dateutilsmodule/dateutilsmodule.coffee` - Shared date utilities
- `sources/source/tradovatemodule/tradovatemodule.coffee` - Tradovate API client (disabled)

### Client API Layer
- `sources/source/scimodule/scimodule.coffee` - Server setup, calls scicore
- `sources/source/scimodule/accesssci.coffee` - Admin routes (grantAccess, revokeAccess)
- `sources/source/scimodule/datasci.coffee` - Data routes (getData)
- `sources/source/scicore/` - SCI framework (submodule)

### Authentication & Access
- `sources/source/authmodule/authmodule.coffee` - Signature auth, nonce tracking
- `sources/source/accessmodule/accessmodule.coffee` - Token management with TTL
- `sources/source/earlyblockermodule/earlyblockermodule.coffee` - Origin/IP blocking

### Module Registry
- `sources/source/allmodules/allmodules.coffee` - Exports all modules

### Storage Layer
- `sources/source/storagemodule/storagemodule.coffee` - Public API
- `sources/source/storagemodule/statecache.coffee` - LRU cache layer (internal)
- `sources/source/storagemodule/statesaver.coffee` - File I/O with backup (internal)

## Quick Reference
### Add a new module
There is a convenience script `np addmodule <module-name>`
However I should tell my partner and let him do this.

### Configuration values available (from configmodule)
- `trdvtSecret`, `trdvtCid`, `trdvtUsername`, `trdvtPassword` - Tradovate
- `mrktStackSecret` - MarketStack
- `urlTrdvt`, `urlMrktStack` - API base URLs
- `checkAccessMS`, `checkSymbolsMS` - Polling intervals
- `persistentStateOptions` - State storage config
- `accessManagerId` - Public key for admin signature auth
- `legalOrigins` - Allowed request origins
- `fallbackAuthCode` - Dev-mode access token (hardcoded)
- `snitchSocket` - Bugsnitch Unix socket path

## Critical Conventions

### Date Handling
All date arithmetic MUST use UTC midnight: `new Date(dateStr + "T00:00:00Z")`
- Ensures consistent day boundaries across the codebase
- Using `new Date(dateStr)` alone interprets as local time → off-by-one errors
- **Centralized in `dateutilsmodule`**: `nextDay`, `prevDay`, `daysBetween`, `generateDateRange`
- Both marketstackmodule and datamodule import from dateutilsmodule

## Current Quirks

1. **Tradovate disabled**: In `tradovatemodule.coffee:31` there's an early `return` that skips initialization

2. **Bugsnitch disabled**: In `bugsnitch.coffee:27` there's an early `return` that skips initialization

3. **Fallback authCode**: Hardcoded dev token in configmodule for testing without access manager

4. **accessmodule TODO**: Comment about upgrading from per-token setTimeout to single heartbeat pruning (optimization for many tokens)

## Storage Layer Status

**Architecture:**
```
storagemodule (public API) → statecache (LRU cache) → statesaver (file I/O)
```

All components now live in `sources/source/storagemodule/`. Wired up and ready to use.

## Implementation Status

### Completed ✓

**Data Layer:**
- [x] Uniform data format: `DataPoint: [high, low, close]`, `DataSet: { meta, data }`
- [x] Gap-fill rule: Missing days → `[lastClose, lastClose, lastClose]`
- [x] Stock retrieval: pagination, normalize, gap-fill, history completeness detection
- [x] DataModule: freshness check, top-up, storage integration
- [x] Storage layer: LRU cache + file persistence

**Client API:**
- [x] HTTP server via scicore framework
- [x] Admin endpoints: `grantAccess`, `revokeAccess` (signature-authenticated)
- [x] Data endpoint: `getData` with optional `yearsBack` slicing
- [x] Token-based access control with TTL
- [x] Origin validation and IP blocking

### Remaining

**For v0.1.0:**
- [ ] End-to-end testing
- [ ] Deployment configuration

**Future:**
- [ ] Commodity heartbeat (push model, 1 req/min)
- [ ] Forex data integration
- [ ] Preprocessed data endpoints

## Key Architecture References

**Data Format:**
```
DataSet: { meta: { startDate, endDate, interval, historyComplete }, data: [[h,l,c], ...] }
```

**API Flow:**
```
Client Request → scimodule → authCheck → datamodule → response
                                              │
                                              ├─ Fresh? → return cached
                                              └─ Stale? → fetch → store → slice → return
```

**See:** `sources/source/marketstackmodule/README.md`, `sources/source/datamodule/README.md`

## MarketStack API Quick Reference

### Rate Limits
- Normal endpoints: Plan-based limits
- Commodities: **1 request per minute** (hardcoded by API)

### Key Gotchas
- Ticker symbols with `.` → use `-` (e.g., `BRK.B` → `BRK-B`)
- Commodities response has different shape than EOD
- No forex data available in MarketStack

### Alternative Data Sources (Future)
- Forex: Tradovate API (already scaffolded), histdata.com (free downloads)
