# Operational Notes

## Important Code Locations

### Entry Point
- `sources/source/index/index.coffee` - Service bootstrap

### Module Configuration
- `sources/source/configmodule/configmodule.coffee` - All config exports
- `.config.json` (gitignored) - Secrets and credentials

### Business Logic
- `sources/source/startupmodule/startupmodule.coffee` - Startup orchestration
- `sources/source/datamodule/datamodule.coffee` - Central data layer (freshness, storage)
- `sources/source/marketstackmodule/marketstackmodule.coffee` - MarketStack API client
- `sources/source/dateutilsmodule/dateutilsmodule.coffee` - Shared date utilities
- `sources/source/tradovatemodule/tradovatemodule.coffee` - Tradovate API client (disabled)

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

## Critical Conventions

### Date Handling
All date arithmetic MUST use UTC midnight: `new Date(dateStr + "T00:00:00Z")`
- Ensures consistent day boundaries across the codebase
- Using `new Date(dateStr)` alone interprets as local time → off-by-one errors
- **Centralized in `dateutilsmodule`**: `nextDay`, `prevDay`, `daysBetween`, `generateDateRange`
- Both marketstackmodule and datamodule import from dateutilsmodule

## Current Quirks

1. **Tradovate disabled**: In `tradovatemodule.coffee:31` there's an early `return` that skips initialization

2. **Special mission mode**: Currently `startupmodule.serviceStartup()` runs `mrktStack.executeSpecialMission()` which is a one-shot data dump (not a persistent service)

3. **Bugsnitch disabled**: In `bugsnitch.coffee:27` there's an early `return` that skips initialization

4. **No HTTP server**: The service currently has no way to receive requests

5. **Storage layer ready**: storagemodule wired up and integrated into standard init pattern

## Storage Layer Status

**Architecture:**
```
storagemodule (public API) → statecache (LRU cache) → statesaver (file I/O)
```

All components now live in `sources/source/storagemodule/`. Wired up and ready to use.

## Next Implementation Focus

### Priority 1: Data Retrieval (In Progress)
**Decision made:** Uniform data format for all price data:
```
DataPoint: [high, low, close]  // array of 3 floats

DataSet: {
  meta: { startDate: "YYYY-MM-DD", endDate: "YYYY-MM-DD", interval: "1d" },
  data: [DataPoint, DataPoint, ...]  // index 0 = startDate
}

Storage: { "<symbol>": DataSet, ... }
```

**Gap-fill rule:** Missing days → `[lastClose, lastClose, lastClose]`

**See:** `sources/source/marketstackmodule/README.md` for full architecture and API reference

### MarketStack Module Architecture

**Two retrieval models:**
- **Stocks: Pull model** — DataModule calls on-demand, fast (IMPLEMENTED)
- **Commodities: Push model** — Heartbeat fetches continuously (1 req/min limit), notifies DataModule (TODO)

**Stock exports (implemented):**
```
getStockAllHistory(ticker) → DataSet | null
getStockOlderHistory(ticker, olderThan) → DataSet | null
getStockNewerHistory(ticker, newerThan) → DataSet | null

DataSet: { meta: { startDate, endDate, interval, historyComplete }, data: [[h,l,c], ...] }
```

**Commodity exports (TODO):**
```
startCommodityHeartbeat(config)  # config: { commodities[], onData, onComplete }
stopCommodityHeartbeat()
```

**Implementation tasks:**
- [x] Stock functions: pagination, normalize, gap-fill, detect limits
- [ ] Commodity heartbeat: init, state management, round-robin, callbacks

### Priority 2: DataModule Implementation (In Progress)

**Architecture decided:**
```
Client Request → API Endpoint → DataModule → Response
                                    │
                                    ├─ Fresh? → return cached
                                    └─ Stale/missing? → fetch → return
```

**Key decisions:**
- Stocks: Pull model (active freshness management)
- Commodities: Push model (passive, return what heartbeat gathered)
- Freshness threshold: Configurable, default 7 days
- Stale → top-up with `getStockNewerHistory()`
- Missing → full fetch with `getStockAllHistory()`

**Implementation tasks:**
- [x] `initialize(config)` - setup storage, configure threshold
- [x] `getStockData(symbol)` - freshness check, fetch if needed, return
- [x] `getCommodityData(name)` - return stored data (no fetch)
- [x] Storage integration
- [x] Freshness threshold configuration

**See:** `sources/source/datamodule/README.md`

### Later: Client-Facing API
- HTTP/HTTPS server module
- API routes for data queries
- Token-based access control
- Change startup from "special mission" to "listen for requests"

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
