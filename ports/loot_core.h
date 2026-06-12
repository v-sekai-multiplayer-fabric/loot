#ifndef LOOT_CORE_H
#define LOOT_CORE_H
#include <stdint.h>
/* Flat C ABI exported by the Lean core (core/, @[export]). The full reducer
   dispatches the SPIR-V kernel; this scalar entry is the smoke surface. */
uint32_t loot_roll_u32(uint32_t seed, uint32_t n_items);
#endif
