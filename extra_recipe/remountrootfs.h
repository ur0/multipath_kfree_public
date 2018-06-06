//
//  remountrootfs.h
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/2/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#ifndef remountrootfs_h
#define remountrootfs_h

#include <mach/mach.h>
#include <stdio.h>
kern_return_t remountRootAsRW(void);
#endif /* remountrootfs_h */
