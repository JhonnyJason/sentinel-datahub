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
- `sources/source/tradovatemodule/tradovatemodule.coffee` - Tradovate API client (disabled)

### Module Registry
- `sources/source/allmodules/allmodules.coffee` - Exports all modules

### Storage Layer
- `sources/source/storagemodule/storagemodule.coffee` - Public API (TODO: wire up)
- `sources/source/statecachemodule/statecachemodule.coffee` - LRU cache layer
- `sources/source/statesavermodule/statesavermodule.coffee` - File I/O with backup

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

## Current Quirks

1. **Tradovate disabled**: In `tradovatemodule.coffee:31` there's an early `return` that skips initialization

2. **Special mission mode**: Currently `startupmodule.serviceStartup()` runs `mrktStack.executeSpecialMission()` which is a one-shot data dump (not a persistent service)

3. **Bugsnitch disabled**: In `bugsnitch.coffee:27` there's an early `return` that skips initialization

4. **No HTTP server**: The service currently has no way to receive requests

5. **Storage layer not wired up**: statecachemodule/statesavermodule exist but aren't integrated into standard init pattern

## Storage Layer Status

**Architecture:**
```
storagemodule (public API) → statecachemodule (LRU cache) → statesavermodule (file I/O)
```

**Issues to fix:**
- [ ] statecachemodule:4 - log label says "statesavermodule" (typo)
- [ ] statecachemodule - missing `toJson` helper function (will crash)
- [ ] storagemodule - empty, needs to wire up statecachemodule
- [ ] Need `list()` function to enumerate stored states

**Initialization mismatch:**
- statecachemodule.initialize(options) expects `{basePath, maxCacheSize, defaultState}`
- Standard pattern passes `cfg` module
- configmodule already has `persistentStateOptions` (lines 50-53)
- storagemodule should bridge: `statecache.initialize(cfg.persistentStateOptions)`

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

### MarketStack Module Architecture (Planned)

**Two retrieval models:**
- **Stocks: Pull model** — DataModule calls on-demand, fast
- **Commodities: Push model** — Heartbeat fetches continuously (1 req/min limit), notifies DataModule

**Stock exports:**
```
getStockAllHistory(ticker) → Result
getStockOlderHistory(ticker, olderThan) → Result
getStockNewerHistory(ticker, newerThan) → Result

Result: { dataSet, reachedHistoryStart, reachedPlanLimit }
```

**Commodity exports:**
```
startCommodityHeartbeat(config)  # config: { commodities[], onData, onComplete }
stopCommodityHeartbeat()
```

**Implementation tasks:**
- [ ] Stock functions: pagination, normalize, gap-fill, detect limits
- [ ] Commodity heartbeat: init, state management, round-robin, callbacks
- [ ] Shared: normalizeStockResponse, normalizeCommodityResponse, gapFill

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
- [ ] `initialize(config)` - setup storage, configure threshold
- [ ] `getStockData(symbol)` - freshness check, fetch if needed, return
- [ ] `getCommodityData(name)` - return stored data (no fetch)
- [ ] Storage integration with `cached-persistentstate`
- [ ] Freshness threshold configuration

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
