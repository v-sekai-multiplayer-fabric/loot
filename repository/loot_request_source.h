#ifndef LOOT_REQUEST_SOURCE_H
#define LOOT_REQUEST_SOURCE_H
#include <stdint.h>
/* Driving port. The loot core pulls loot requests from an adapter (combat on a
   kill, or a recorded fixture). A request is (requester id, receipt timestamp). */
typedef struct { uint32_t requester; uint64_t receipt_ts; } loot_request;
typedef struct loot_request_source {
  void *ctx;
  int (*poll)(void *ctx, loot_request *out); /* 1 = produced a request, 0 = none */
} loot_request_source;
#endif
