//
//  kmem.c
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/5/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#include "kmem.h"
#include "extra_recipe_utils.h"
#include <stdlib.h>

int __readKernelMemory(uint64_t Address, uint64_t Len, void **To) {
  void *mem = malloc(Len);
  kread(Address, mem, (int)Len);
  *To = mem;

  return (int)Len;
}

int __writeKernelMemory(uint64_t Address, uint64_t Len, void *From) {
  kwrite(Address, From, (int)Len);

  return (int)Len;
}
