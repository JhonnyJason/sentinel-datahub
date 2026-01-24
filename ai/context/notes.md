# Operational Notes

## Important Code Locations

### Entry Point
- `sources/source/index/index.coffee` - Service bootstrap

### Module Configuration
- `sources/source/configmodule/configmodule.coffee` - All config exports
- `.config.json` (gitignored) - Secrets and credentials

### Business Logic
- `sources/source/startupmodule/startupmodule.coffee` - Startup orchestration
- `sources/source/marketstackmodule/marketstackmodule.coffee` - MarketStack API client
- `sources/source/tradovatemodule/tradovatemodule.coffee` - Tradovate API client (disabled)

### Module Registry
- `sources/source/allmodules/allmodules.coffee` - Exports all modules

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

**MarketStack endpoints to use:**
- Stocks: `GET /eod?symbols=X&date_from=...&date_to=...`
- Commodities: `GET /commoditieshistory?commodity_name=X&date_from=...&date_to=...`

**See:** `sources/source/marketstackmodule/README.md` for full API reference

**Implementation tasks:**
- [ ] Implement `getStockEOD(symbols, dateFrom, dateTo)` with pagination
- [ ] Implement `getCommodityHistory(name, dateFrom, dateTo)` with rate limiting (1/min)
- [ ] Create normalizer functions: source response → DataSet with gap-filling
- [ ] Handle the different response structures (stocks = array, commodities = nested)

### Priority 2: Data Management
- How do we store, cache, and serve retrieved data?
- Data freshness and invalidation strategies
- Persistent storage vs in-memory caching

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
