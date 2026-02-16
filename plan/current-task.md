# Task 6
Implement - Adding split-factors into cached DataSet


## Details 
As readable in the datamodule/README.md the current dataformat only contains minimal meta information and the list of all the DataPoints. As Array of 3 values. Now the split-factors do cause problems.

When retrieving the data we combine all the split-factors together and multiply them with the HLC values to keep the real price dynamic stable across the splits.
Now when we add new Data or receive older Data we have effectively lost our awareness about the split-factors. E.g. When we add newer values, before we had a split factor of 20 and were at ~2000 the next values are at around 100 and we don't know what was the split factor at that point. So currently we simply experience a sharp drop from day to day to newer retrieved data.

Another issue is that even with the split-factor correction - or maybe because of how we do the split-factor correction - the data for Apple experience very strong day on day increase at 2-4 days in the whole long history. This we have needs to be investigated and fixed.

Ultimatively we need to:
- store the split factors in our meta data
- reliably correct the split factors in all edge-cases
- probably "recorrect" old data which donot know about their split-factors and are not perfectly corrected

## Approach
- Store `splitFactors` array in DataSet meta: `[{f: cumulativeFactor, end: "YYYY-MM-DD"}, ..., {f: currentFactor}]`
- Pass cumulative factor to `getStockNewerHistory` so appended data normalizes at the correct scale
- Legacy data without `splitFactors` → use `recorrectData(symbol)` to re-fetch and fix
- No separate `isSplitCorrected` flag needed — presence of `splitFactors` in meta is the signal

##  Sub-Tasks
- [x] Reflect on an implementation approach
- [x] Add splitFactors array to meta (normalizeEodResponse extracts split events)
- [x] Pass cumulative factor through getStockNewerHistory → normalizeEodResponse
- [x] Update appendDataSet / prependDataSet to merge splitFactors
- [x] Update getStockData / forceLoadNewestStockData to pass cumulative factor
- [x] Preserve splitFactors in sliceByYears
- [x] Add recorrectData export
- [ ] Build, test with a stock that has known splits (e.g. AAPL)
- [ ] Investigate the Apple anomaly (strong day-on-day increases at 2-4 dates)
