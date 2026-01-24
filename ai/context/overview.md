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
tradovatemodule/    - Tradovate API integration (futures trading)
marketstackmodule/  - MarketStack API integration (stock market data)
bugsnitch/          - Error reporting (Unix socket to bugsnitch service)
scimodule/          - (minimal - purpose unclear)
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
- Functions: `getAllSymbols()`, `getAllCurrencies()`, `getEndOfDayData()`
- Current use: Batch store symbols/currencies to JSON files

**Tradovate** (`tradovatemodule`):
- URL: `https://live.tradovateapi.com/v1`
- Functions: OAuth token management, session keep-alive, product listing
- Status: **Disabled** (early `return` in `initialize`)

### Configuration
Read from `.config.json` in working directory:
- `secret`, `cid`, `name`, `password` - Tradovate credentials
- `mrktStackSecret` - MarketStack API key

## Current State (v0.0.1)
The service is an **experimental shell** for API exploration:
- Can authenticate with MarketStack and dump symbols/currencies
- Tradovate integration scaffolded but disabled
- **No client-facing API yet** (no HTTP server)
- **No token-based access control yet**

## Implementation Roadmap

### Current Focus: Data Layer
1. **Data Retrieval** — Establish how we fetch data from external APIs
2. **Data Management** — Storage, caching, freshness strategies

### Later: Client Interface
3. Client-Facing Data API
4. Token-Based Access Control

## Data Layer Design Decisions

### Uniform Data Format
All historical price data is normalized to an efficient array-based structure:

```
DataPoint: [high, low, close]  // array of 3 floats

DataSet: {
  meta: { startDate: "YYYY-MM-DD", endDate: "YYYY-MM-DD", interval: "1d" },
  data: [DataPoint, DataPoint, ...]  // index 0 = startDate
}

Storage: { "<symbol>": DataSet, ... }
```

**Design rationale:**
- Array format minimizes memory and JSON size (no repeated key strings)
- Symbol stored once per DataSet, not per DataPoint
- Date computed from index: `date = startDate + (index * interval)`
- Contiguous data guaranteed (no gaps)

**Symbol convention:** `{asset}/{quote_currency}` (lowercase quote currency)

### Gap-Fill Rule
If source data has missing days, fill with: `[lastClose, lastClose, lastClose]`

This ensures every index has a valid DataPoint, simplifying consumer code.

### Data Sources

| Asset Type | Source | Status |
|------------|--------|--------|
| Stocks | MarketStack `/eod` | Planned |
| Commodities | MarketStack `/commoditieshistory` | Planned |
| Forex | Tradovate or histdata.com | Future |

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
