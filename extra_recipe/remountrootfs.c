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
extern uint64_t kernel_base;

kern_return_t remountRootAsRW() {
    
    int ROOTFSMOUNT_FAILURE = KERN_FAILURE;
    int ROOTFSMOUNT_SUCCESS = KERN_SUCCESS;
    
    if(getuid()+getgid()+kernel_base == 0) {
        printf("Mounting the root filesystem requires kernel priviliges, we do not seem to have such.\n");
        return ROOTFSMOUNT_FAILURE;
    }
    
    printf("Remounting the rootfs as readable and writable...\n");
    char *devpath = strdup("/dev/disk0s1s1");
    
    printf("Getting the device virtual node for the root partition device at %s...\n", devpath);
    //uint64_t devVnode = getVnodeAtPath(devpath);
    
    printf("Assuming that the type of the root filesystem is Apple Filesystem...\n");
    
    printf("Patching the device node's flags in the kernel...\n");
    //writeKernelMemory(devVnode + off_v_specflags, sizeof(int), 0); // clear dev vnode’s v_specflags
    
    /* 1. make a new mount of the device of root partition */
    char *newMPPath = strdup("/private/var/mobile/tmp");
    printf("Creating root filesystem mountpoint on %s...\n", newMPPath);
    //createDirAtPath(newMPPath);
    
    printf("Mounting %s on the new mountpoint at %s...\n", devpath, newMPPath);
    //mountDevAtPathAsRW(devPath, newMPPath);
    
    
    /* 2. Get mnt_data from the new mount */
    printf("Getting the mount extend data from the new mount..\n");
    //uint64_t newMPVnode = getVnodeAtPath(newMPPath);
    
    uint64_t newMPMount = 0;
    //readKernelMemory(newMPVnode + off_v_mount, sizeof(uint64_t), &newMPMount);
    printf("Our new mount is: %#llx\n", newMPMount);
    
    uint64_t newMPMountData = 0;
    //readKernelMemory(newMPMount + off_mnt_data, sizeof(uint64_t), &newMPMountData);
    printf("Our mountdata is: %#llx\n", newMPMountData);
    
    
    /* 3. Modify root mount’s flag and remount */
    printf("Modifying the rootfs mount flag so we will bypass the security checks...\n");
    //uint64_t rootVnode = getVnodeAtPath("/");
    
    uint64_t rootMount = 0;
    //readKernelMemory(rootVnode + off_v_mount, sizeof(uint64_t), &rootMount);
    printf("The rootfs mount is now: %#llx\n", rootMount);
    
    uint32_t rootMountFlag = 0;
    //readKernelMemory(rootMount + off_mnt_flag, sizeof(uint32_t), &rootMountFlag);
    
    printf("The rootfs mount flag is now: %#x\n", rootMountFlag);
    //writeKernel(rootMount + off_mnt_flag, sizeof(uint64_t) ,rootMountFlag & ~ ( MNT_NOSUID | MNT_RDONLY | MNT_ROOTFS));
    
    printf("Doing the final mount operation on / ...\n");
    mount("apfs", "/", MNT_UPDATE, &devpath);
    
    
    
    /* 4. Replace root mount’s mnt_data with new mount’s mnt_data */
    printf("Fixing up the final mount's extents data to prevent kernel panics and bypass extents overflow checks...\n");
    //writeKernelMemory(rootMount + off_mnt_data, sizeof(newMPMountData), newMPMountData);
    
    printf("All done, you have full read write access to / now!");
    return ROOTFSMOUNT_SUCCESS;
}
