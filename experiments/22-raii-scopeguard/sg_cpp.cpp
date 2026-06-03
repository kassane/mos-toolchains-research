#include "scope.h"
// C++ RAII: destructors run in reverse construction order (LIFO).
namespace { struct Guard { char c; ~Guard(){ trace(c); } }; }
extern "C" void cpp_run(){ Guard g1{'1'}; Guard g2{'2'}; (void)g1; (void)g2; }
