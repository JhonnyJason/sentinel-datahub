# Sentinel Datahub - Project Overview

## Purpose
A data aggregation service that acts as an intermediary between the **Sentinel Dashboard** (frontend) and **3rd party financial data APIs**. The goal is to provide a unified, token-protected API for the dashboard to consume.

## Tech Stack
- **Language**: CoffeeScript
- **Runtime**: Node.js
- **Build System**: Custom "thingy-build-system" + Webpack
- **State Management**: `cached-persistentstate` library

## Architecture

### Module Structure (`sources/source/`)
```
index/              - Entry point: initializes modules, runs startup
configmodule/       - Configuration loader (.config.json)
startupmodule/      - Service startup orchestration
datamodule/         - Central data layer: freshness management, storage
marketstackmodule/  - MarketStack API integration (stock market data)
dateutilsmodule/    - Shared date utilities (nextDay, prevDay, daysBetween, generateDateRange, isTradingDay, lastTradingDay)
livefeedmodule/     - Live price feed: in-memory latest prices, WebSocket subscriber notifications
tradovatemodule/    - Tradovate API integration (futures trading)
storagemodule/      - Persistent state with LRU cache
bugsnitch/          - Error reporting (Unix socket to bugsnitch service)
scimodule/          - HTTP API server (routes defined in accesssci.coffee, datasci.coffee)
scicore/            - SCI framework core (submodule)
accessmodule/       - Token-based access control with TTL
authmodule/         - Signature-based authentication (nonce replay protection)
earlyblockermodule/ - IP/origin blocking for abuse prevention
debugmodule/        - Debug utilities setup
allmodules/         - Module registry
```

### Startup Flow
1. `index` imports all modules via `allmodules`
2. Calls `initialize(cfg)` on each module that has it
3. Calls `startupmodule.serviceStartup()` to begin service logic

### External API Integrations

**MarketStack** (`marketstackmodule`):
- URL: `https://api.marketstack.com/v2`
- Status: **Redesigning** — see `sources/source/marketstackmodule/README.md`
- Architecture: Two models due to rate limits
  - Stocks: Pull model (on-demand), DataModule calls when needed
  - Commodities: Push model (heartbeat), continuous background fetching (1 req/min), notifies DataModule

**Tradovate** (`tradovatemodule`):
- URL: `https://live.tradovateapi.com/v1`
- Functions: OAuth token management, session keep-alive, product listing
- Status: **Disabled** (early `return` in `initialize`)

### Configuration
Read from `.config.json` in working directory:
- `secret`, `cid`, `name`, `password` - Tradovate credentials
- `mrktStackSecret` - MarketStack API key

## Current State (v0.1.0)
The service has a **functional client-facing API**:
- HTTP server via scicore framework
- Token-based access control (authCode with TTL)
- Signature-authenticated admin endpoints (grantAccess, revokeAccess)
- Data retrieval endpoint with optional time slicing (getData)
- Stock data: full pipeline working (fetch → cache → freshness → serve)
- Tradovate integration scaffolded but disabled
- Commodities/Forex: stubs in place, data retrieval TODO

## Implementation Roadmap

### Completed
1. **Data Retrieval** — MarketStack stock integration with pagination, gap-fill
2. **Data Management** — Storage layer with LRU cache, freshness strategies
3. **Client-Facing API** — HTTP server with token-based access control
4. **Live Data Heartbeat** — Intraday price fetching, pre-trading data top-up, WebSocket live feed, weekend awareness, pre-trade attempt limiter

### Remaining for v0.1.0
- [ ] End-to-end testing of the full flow
- [ ] Deployment configuration

### Future
- Holiday calendar for `isTradingDay` (currently weekends only)
- Commodity heartbeat (push model, 1 req/min rate limit)
- Forex data integration
- Preprocessed data endpoints

## Data Layer Design Decisions

### DataModule Architecture

Central data layer serving API endpoints. Manages freshness and coordinates with external APIs.

**Data Flow:**
```
Client Request → API Endpoint → DataModule → Response
                                    │
                                    ├─ Fresh? → return cached
                                    └─ Stale/missing? → fetch → store → return
```

**Freshness Strategy by Asset Type:**

| Asset | Model | Behavior |
|-------|-------|----------|
| Stocks | Pull (active) | Check freshness → top-up if stale → return |
| Commodities | Push (passive) | Return whatever heartbeat has gathered |

**Freshness threshold:** Configurable (default 7 days). For EOD data, defines max acceptable gap between last data point and today. Pattern analysis tolerates larger gaps.

**Fetch logic:**
- Stale data → `getStockNewerHistory()` to top-up missing range
- No data → `getStockAllHistory()` to fetch everything

### Uniform Data Format
All historical price data is normalized to an efficient array-based structure:

```
DataPoint: [high, low, close]  // array of 3 floats (trading day)
GapFillPoint: [lastClose]      // array of 1 float (non-trading day)

DataSet: {
  meta: { startDate: "YYYY-MM-DD", endDate: "YYYY-MM-DD", interval: "1d", version: N },
  data: [DataPoint|GapFillPoint, ...]  // index 0 = startDate
}

Storage: { "<symbol>": DataSet, ... }
```

**Design rationale:**
- Array format minimizes memory and JSON size (no repeated key strings)
- Symbol stored once per DataSet, not per DataPoint
- Date computed from index: `date = startDate + (index * interval)`
- Contiguous data guaranteed (no gaps)
- Non-trading days distinguishable by `dp.length === 1` (identifies holidays, not just weekends)

**Date handling convention:**
- All date arithmetic uses UTC midnight: `new Date(dateStr + "T00:00:00Z")`
- This ensures consistent day boundaries regardless of local timezone
- IMPORTANT: Never use `new Date(dateStr)` alone — it interprets as local time and causes off-by-one errors
- Use shared utilities from `dateutilsmodule`: `nextDay`, `prevDay`, `daysBetween`, `generateDateRange`, `isTradingDay`, `lastTradingDay`

**Symbol convention:** `{asset}/{quote_currency}` (lowercase quote currency)

### Gap-Fill Rule
If source data has missing days, fill with: `[lastClose]` (single element)

This ensures every index has a valid DataPoint, simplifying consumer code.
Non-trading days are distinguishable from trading days by array length: `dp.length === 1` vs `dp.length === 3`.

### Data Sources

| Asset Type | Source | Status |
|------------|--------|--------|
| Stocks | MarketStack `/eod` | **Working** |
| Commodities | MarketStack `/commoditieshistory` | Stub ready |
| Forex | Tradovate or histdata.com | Stub ready |

## Client API

### Authentication Architecture
```
Access Manager (external) ──signatureAuth──► grantAccess/revokeAccess
                                                    │
                                                    ▼
Dashboard Client ──────────authCode────────► getData
```

- **Admin endpoints**: Signature-authenticated (Ed25519), nonce replay protection
- **Data endpoints**: Simple authCode token with TTL

### API Endpoints

| Endpoint | Auth | Purpose |
|----------|------|---------|
| `grantAccess` | signature | Create/refresh access token with TTL |
| `revokeAccess` | signature | Revoke an access token |
| `getData` | authCode | Retrieve price data for a symbol |

### getData Parameters
```json
{
  "authCode": "hex32",
  "dataKey": "AAPL",
  "yearsBack": 2        // optional, omit for full history
}
```

### Security Layers
1. **earlyblockermodule** — Origin validation, IP blocking
2. **authmodule** — Signature verification, timestamp/nonce validation
3. **accessmodule** — Token validity check

### Normalization Rules
- **Stocks (OHLC):** Extract `high`, `low`, `close`
- **Commodities (single price):** Use price for all three: `[price, price, price]`

### API Constraints
- MarketStack commodities: **1 request per minute** rate limit
- MarketStack EOD: Max 1000 results per page, use pagination
- Commodities: Recommend 1 year per request for daily data

## Directory Structure
```
sources/            - Source code (CoffeeScript modules)
output/             - Build output (bundled service.js)
toolset/            - Build system tools
testing/            - Testing infrastructure (nginx, systemd, certs)
plan/               - Project planning documents
ai/context/         - AI context files (this overview, notes)
.build-config/      - Webpack configs
```

## Build & Run
```bash
pnpm install        # Install deps (runs initialize-thingy)
pnpm run build      # Build to output/
pnpm run test       # Build and run (cd output && node service.js)
pnpm run watch      # Development mode with file watching
```
