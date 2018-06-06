//
//  jailbreak.h
//  multipath_kfree
//
//  Created by John Åkerblom on 6/1/18.
//

#ifndef jailbreak_h
#define jailbreak_h
#include "multipath_kfree.h"

//Exploit options
#define MP_SOCK_COUNT 0x10
#define FIRST_PORTS_COUNT 100 //may be more stable with 200
#define REFILL_PORTS_COUNT 100 //may be more stable with 200
#define TOOLAZY_PORTS_COUNT 1000
#define REFILL_USERCLIENTS_COUNT 1000
#define MAX_PEEKS 30000

void jb_go(void);

#endif /* jailbreak_h */
