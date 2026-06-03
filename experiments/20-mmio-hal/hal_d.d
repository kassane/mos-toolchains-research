module hal_d;
import core.volatile : volatileStore;
// @system: raw MMIO pointer (honest under -preview=safer). Mirrors mos-hardware poke!.
extern(C) @system void d_poke(ubyte c){ volatileStore(cast(ubyte*)0xFFF9, c); }
