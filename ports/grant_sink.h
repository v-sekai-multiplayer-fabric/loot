#ifndef GRANT_SINK_H
#define GRANT_SINK_H
#include <stdint.h>
/* Driven port. The loot core pushes a grant or a rejection per requester. */
typedef struct grant_sink {
  void *ctx;
  void (*grant)(void *ctx, uint32_t requester, uint32_t item);
  void (*reject)(void *ctx, uint32_t requester);
} grant_sink;
#endif
