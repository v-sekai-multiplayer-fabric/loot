#ifndef INVENTORY_DELTA_SINK_H
#define INVENTORY_DELTA_SINK_H
#include <stdint.h>
/* Driven port. The loot core pushes the inventory change to persist; the
   progression hexagon's adapter applies it behind a commit_sink. */
typedef struct inventory_delta_sink {
  void *ctx;
  void (*add_item)(void *ctx, uint32_t requester, uint32_t item, int32_t qty);
} inventory_delta_sink;
#endif
