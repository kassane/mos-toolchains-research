module p_d;
extern(C):
struct Pkt { ubyte tag; uint val; ubyte flag; }   // D struct == C layout
uint d_read(const(Pkt)* p){ return p.val; }
ubyte d_size(){ return Pkt.sizeof; }
