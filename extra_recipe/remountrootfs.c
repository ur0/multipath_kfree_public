//
//  remountrootfs.c
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/2/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#include "remountrootfs.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <fcntl.h>
#include <dirent.h>
#include <sys/mount.h>
#include "offsets.h"
#include "extra_recipe_utils.h"
#include "QiLin.h"

void remountRootAsRW(){
    extern uint64_t kernel_base;
    char *devpath = strdup("/dev/disk0s1s1");
    
    //uint64_t devVnode = getVnodeAtPath(devpath);
    
    initQiLin(0x1337, kernel_base);
    //writeKernelMemory(devVnode + off_v_specflags, sizeof(int), 0); // clear dev vnode’s v_specflags
    
    
    
    /* 1. make a new mount of the device of root partition */
    
    char *newMPPath = strdup("/private/var/mobile/tmp");
    
    //createDirAtPath(newMPPath);
    
    
    //mountDevAtPathAsRW(devPath, newMPPath);
    
    
    
    /* 2. Get mnt_data from the new mount */
    
    //uint64_t newMPVnode = getVnodeAtPath(newMPPath);
    
    uint64_t newMPMount = 0;
    //readKernelMemory(newMPVnode + off_v_mount, sizeof(uint64_t), &newMPMount);
    
    uint64_t newMPMountData = 0;
    //readKernelMemory(newMPMount + off_mnt_data, sizeof(uint64_t), &newMPMountData);
    
    
    
    /* 3. Modify root mount’s flag and remount */
    
    //uint64_t rootVnode = getVnodeAtPath("/");
    
    uint64_t rootMount = 0;
    //readKernelMemory(rootVnode + off_v_mount, sizeof(uint64_t), &rootMount);
    
    uint32_t rootMountFlag = 0;
    //readKernelMemory(rootMount + off_mnt_flag, sizeof(uint32_t), &rootMountFlag);
    
    //writeKernel(rootMount + off_mnt_flag, sizeof(uint64_t) ,rootMountFlag & ~ ( MNT_NOSUID | MNT_RDONLY | MNT_ROOTFS));
    
    mount("apfs", "/", MNT_UPDATE, &devpath);
    
    
    
    /* 4. Replace root mount’s mnt_data with new mount’s mnt_data */
    
    //writeKernelMemory(rootMount + off_mnt_data, sizeof(newMPMountData), newMPMountData);
    
}
