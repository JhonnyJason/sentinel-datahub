# Task 4
Implement - add live-data-feed from HYG

## Details
For certain usecases - as we have for the symbol "HYG" for now - we need most recent data which are reasonably possible.

We shall define a list of Symbols in our configmodule for which we want to do "realtime" observations.
The marketstackmodule shall start an interval which fires every 1-20 minutes to retrieve the most recent data for these symbols.
We shall later create a livefeedmoule which holds the live-feed data from the specified symbols and would facilitate that the messages for data updates will be sent. From our heartbeat we simply would call the livefeedmodule and communicate the updates.

One hour before trading starts we shall retrieve the EOD data from the day before. At this time we assume that we should be able to receive it and add it into our set of stored historic data.

For all of this to run smoothly we need to rebuild our request-sending routine. We need a general request queue where all the requests have to go through and which is throttled to stay below the rate limit.

## Sub-Task
- [x] 4.0 Define the list of liveDataSymbols in the configfile and use it in the marketstackmodule
- [x] 4.1 Implement the liveDataHeartbeat
- [x] 4.2 Test the liveData retrieval and fix issues
- [x] 4.3 Upgrade to one throttled request queue
- [x] 4.3.1 Add request deduplication (URL coalescing) to the request queue
- [x] 4.4 Test and fix found issues