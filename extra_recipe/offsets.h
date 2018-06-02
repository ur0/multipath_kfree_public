//
//  offsets.h
//  extra_recipe_extra_extra_bug
//
//  Created by Sem Voigtländer on 6/2/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#ifndef offsets_h
#define offsets_h
#include <stdio.h>
typedef struct {
    uint64_t allproc;
    uint64_t kernproc;
    uint64_t realhost;
    uint64_t copyin;
    uint64_t copyout;
    uint64_t rootvnode;
    uint64_t kernel_task;
    uint64_t kernel_map;
    uint64_t osserializer_serialize;
    uint64_t metaclass;
    uint64_t AGXCommandQueue_vtable;
} ExploitOffsets;
void init_offsets(void);
extern ExploitOffsets offsets;
extern int hasOffsets;
//Defaults to 6S (N71AP iPhone8,1) 11.3.1
#endif /* offsets_h */
