//
//  offsets.m
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/2/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <sys/utsname.h>
#include <sys/sysctl.h>
#include "offsets.h"
int hasOffsets = 0;
ExploitOffsets offsets = {
};




ExploitOffsets init_offsets_iPhone81_11_3_1() {
    ExploitOffsets offsets = {0};
    offsets.metaclass = 0xfffffff0074c5410;
    offsets.rootvnode = 0xfffffff0075d5088;
    offsets.copyin = 0xfffffff0071a7090;
    offsets.copyout = 0xfffffff0071a72b4;
    offsets.kernel_task = 0xfffffff0075d5048;
    offsets.kernel_map = 0xfffffff0075d5050;
    offsets.allproc = 0xFFFFFFF00777FC68;
    offsets.kernproc = 0xfffffff0075d50a0;
    return offsets;
}

void init_offsets() {
    size_t size = 32;
    char build_id[size];
    memset(build_id, 0, size);
    int err = sysctlbyname("kern.osversion", build_id, &size, NULL, 0);
    if (err == -1) {
        printf("failed to detect version (sysctlbyname failed\n");
        return;
    }
    printf("build_id: %s\n", build_id);
    
    struct utsname u = {0};
    uname(&u);
    
    printf("sysname: %s\n", u.sysname);
    printf("nodename: %s\n", u.nodename);
    printf("release: %s\n", u.release);
    printf("version: %s\n", u.version);
    printf("machine: %s\n", u.machine);
    
    // set the offsets
    
    if (strcmp(build_id, "15E302") == 0) {
        offsets = init_offsets_iPhone81_11_3_1();
    } else {
        printf("unknown kernel build. If this is iOS 11 it might still be able to get tfp0, trying anyway\n");
        hasOffsets = 0;
        return;
    }
}

















