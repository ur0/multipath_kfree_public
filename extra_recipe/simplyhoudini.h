//
//  takenfromhoudini.h
//  The following code comes from Houdini by Abraham Masri, it may be slightly altered to fit this WIP.
//  Please do not add any Objective-C types here
//

#ifndef takenfromhoudini_h
#define takenfromhoudini_h
#include <mach/mach.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <dirent.h>
#include <sys/stat.h>

//Common Paths
#define INSTALLED_APPS_PATH "/private/var/containers/Bundle/Application"
#define APPS_DATA_PATH "/private/var/mobile/Containers/Data/Application"
#define KERNELCACHE_PATH "/System/Library/Caches/com.apple.kernelcaches/kernelcache"
#define DYLD_SHARED_CACHES_PATH "/System/Library/Caches/com.apple.dyld_shared_caches/"
#define BOOT_UUID_PATH "/var/????"
#define SYSTEM_VERSION_PLIST_PATH "/System/Library/CoreServices/com.apple.systemversion.plist"

//Generic variables and definitions
#define ROOT_UID 0
#define WHEEL_GID 0
#define MOBILE_UID 501
#define MOBILE_GID 501


//Data Structures
typedef struct app_dir {
    struct app_dir* next;
    char root_path[150];
    char app_path[190];
    char jdylib_path[210];
    char *display_name;
    char *identifier;
    char *executable;
    boolean_t valid;
    
} app_dir_t;

//Management functions
void clear_files_for_path(char *);
void apps_control_init(mach_port_t);
void read_apps_data_dir(void);
void list_applications_installed(void);

//Tweak function
kern_return_t change_icon_badge_color(const char *color_raw, const char *size_type);

#endif /* takenfromhoudini_h */
