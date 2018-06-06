//
//  kmem.h
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/5/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#ifndef kmem_h
#define kmem_h

#include <stdio.h>
int __readKernelMemory(uint64_t Address, uint64_t Len, void **To);
int __writeKernelMemory(uint64_t Address, uint64_t Len, void *From);
extern mach_port_t tfp0;
void wk32(uint64_t kaddr, uint32_t val);
void wk64(uint64_t kaddr, uint64_t val);
#endif /* kmem_h */
