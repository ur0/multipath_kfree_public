//
//  takenfromhoudini.m
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/5/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#include "simplyhoudini.h"
#import "UIImage+private.h"
#include "generic.h"
#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/dirent.h>
#include <sys/stat.h>
#include <unistd.h>

NSMutableDictionary
    *all_apps; // contains list of apps taken from INSTALLED_APPS_DIR
NSMutableArray *all_apps_data; // contains list of apps (bundle data uuid) taken
                               // from APPS_DATA_PATH

NSString *get_houdini_dir_for_path(NSString *dir_name) {

  NSString *docDir = NSSearchPathForDirectoriesInDomains(
      NSDocumentDirectory, NSUserDomainMask, YES)[0];
  NSString *final_path = [docDir stringByAppendingPathComponent:dir_name];

  BOOL isDir;
  NSFileManager *fm = [NSFileManager defaultManager];
  if (![fm fileExistsAtPath:final_path isDirectory:&isDir]) {
    if ([fm createDirectoryAtPath:final_path
            withIntermediateDirectories:YES
                             attributes:nil
                                  error:nil])
      printf("[INFO]: created houdini dir with name: %s\n",
             [dir_name UTF8String]);
    else
      printf("[ERROR]: could not create dir with name: %s\n",
             [dir_name UTF8String]);
  }

  return final_path;
}

kern_return_t set_file_permissions(char *destination_path, int uid, int gid,
                                   int perm_num) {

  // Chown the destination
  int ret = chown(destination_path, uid, gid);

  if (ret == -1) {
    printf("[ERROR]: could not chown destination file: %s\n", destination_path);
    return KERN_FAILURE;
  }

  // Chmod the destination
  ret = chmod(destination_path, perm_num);

  if (ret == -1) {
    printf("[ERROR]: could not chmod destination file: %s\n", destination_path);
    return KERN_FAILURE;
  }

  return KERN_SUCCESS;
}

kern_return_t copy_file(char *source_path, char *destination_path, int uid,
                        int gid, int num_perm) {

  printf("[INFO]: deleting %s\n", destination_path);

  // unlink destination first
  unlink(destination_path);

  printf("[INFO]: copying files from (%s) to (%s)..\n", source_path,
         destination_path);

  size_t read_size, write_size;
  char buffer[100];

  int read_fd = open(source_path, O_RDONLY, 0);
  int write_fd = open(destination_path, O_RDWR | O_CREAT | O_APPEND, 0777);

  FILE *read_file = fdopen(read_fd, "r");
  FILE *write_file = fdopen(write_fd, "wb");

  if (read_file == NULL) {
    printf("[INFO]: can't copy. failed to read file from path: %s\n",
           source_path);
    return KERN_FAILURE;
  }

  if (write_file == NULL) {
    printf("[INFO]: can't copy. failed to write file with path: %s\n",
           destination_path);
    return KERN_FAILURE;
  }

  while (feof(read_file) == 0) {

    if ((read_size = fread(buffer, 1, 100, read_file)) != 100) {

      if (ferror(read_file) != 0) {
        printf("[ERROR]: could not read from: %s\n", source_path);
        return KERN_FAILURE;
      }
    }

    if ((write_size = fwrite(buffer, 1, read_size, write_file)) != read_size) {
      printf("[ERROR]: could not write to: %s\n", destination_path);
      return KERN_FAILURE;
    }
  }

  fclose(read_file);
  fclose(write_file);

  close(read_fd);
  close(write_fd);

  // Chown the destination
  kern_return_t ret =
      set_file_permissions(destination_path, uid, gid, num_perm);
  if (ret != KERN_SUCCESS) {
    return KERN_FAILURE;
  }

  return KERN_SUCCESS;
}

void change_resolution(int width, int height) {

  printf("[INFO]: changing resolution to (w: %d, h: %d)\n", width, height);

  NSMutableDictionary *iomobile_graphics_family_dict =
      [[NSMutableDictionary alloc] init];

  [iomobile_graphics_family_dict setObject:[NSNumber numberWithInteger:height]
                                    forKey:@"canvas_height"];
  [iomobile_graphics_family_dict setObject:[NSNumber numberWithInteger:width]
                                    forKey:@"canvas_width"];

  // output path
  NSString *output_path = [NSString
      stringWithFormat:@"%s/com.apple.iokit.IOMobileGraphicsFamily.plist",
                       bundle_path()];

  [iomobile_graphics_family_dict writeToFile:output_path atomically:YES];

  copy_file(strdup([output_path UTF8String]),
            "/var/mobile/Library/Preferences/"
            "com.apple.iokit.IOMobileGraphicsFamily.plist",
            0, 0, 01444);
}

char *get_current_wallpaper() {

  FILE *binary_file;
  long binary_size;
  void *binary_raw;

  int fd = open("/var/mobile/Library/SpringBoard/LockBackgroundThumbnail.jpg",
                O_RDONLY, 0);

  if (fd < 0)
    return nil;

  binary_file = fdopen(fd, "r");

  fseek(binary_file, 0, SEEK_END);
  binary_size = ftell(binary_file);
  rewind(binary_file);
  binary_raw = malloc(binary_size * (sizeof(void *)));
  fread(binary_raw, sizeof(char), binary_size, binary_file);

  close(fd);
  fclose(binary_file);
  return binary_raw;
}

void read_apps_root_dir() {

  DIR *mydir;
  struct dirent *myfile;

  int fd = open(INSTALLED_APPS_PATH, O_RDONLY, 0);

  if (fd < 0)
    return;

  mydir = fdopendir(fd);
  while ((myfile = readdir(mydir)) != NULL) {

    char *dir_name = myfile->d_name;

    // skip dirs that start with '.'
    if (strncmp(".", dir_name, 1) == 0 || myfile->d_type != DT_DIR) {
      continue;
    }

    NSString *app_uuid = [NSString stringWithFormat:@"%s", dir_name];
    NSString *full_path =
        [NSString stringWithFormat:@"%s/%@", INSTALLED_APPS_PATH, app_uuid];
    NSMutableDictionary *app_dict = [[NSMutableDictionary alloc]
        initWithObjectsAndKeys:app_uuid, @"uuid", full_path, @"full_path", nil];

    [all_apps setObject:app_dict forKey:app_uuid];
  }

  closedir(mydir);
  close(fd);
}

char *list_child_dirs(NSMutableDictionary *app_dict) {

  DIR *mydir;
  struct dirent *myfile;

  char *full_path = strdup([[app_dict objectForKey:@"full_path"] UTF8String]);
  int fd = open(full_path, O_RDONLY, 0);

  if (fd < 0)
    goto failed;

  mydir = fdopendir(fd);
  while ((myfile = readdir(mydir)) != NULL) {

    char *dir_name = myfile->d_name;
    char *ext = strrchr(dir_name, '.');
    if (ext && !strcmp(ext, ".app")) {

      printf("listing dir_name: %s\n", dir_name);
      [app_dict
          setObject:[NSString stringWithFormat:@"%s/%s", full_path, dir_name]
             forKey:@"app_path"];
      break;
    }
  }

  closedir(mydir);
  close(fd);

failed:
  return (char *)"";
}

/*
 *  Purpose: reads all apps along with their container_manager metadata
 *  then appends to all_apps_data
 */
void read_apps_data_dir() {

  if (all_apps_data == NULL) {
    all_apps_data = [[NSMutableArray alloc] init];
  }

  DIR *mydir;
  struct dirent *myfile;

  int fd = open(APPS_DATA_PATH, O_RDONLY, 0);

  if (fd < 0)
    return;

  mydir = fdopendir(fd);
  while ((myfile = readdir(mydir)) != NULL) {

    char *data_uuid = myfile->d_name;

    if (strcmp(data_uuid, ".") == 0 || strcmp(data_uuid, "..") == 0)
      continue;

    [all_apps_data addObject:[NSString stringWithFormat:@"%s", data_uuid]];
  }

  closedir(mydir);
  close(fd);
}

kern_return_t read_app_info(NSMutableDictionary *app_dict,
                            NSString *local_app_info_path) {

  FILE *info_file = NULL;
  long plist_size = 0;
  char *plist_contents = NULL;

  char *info_path = (char *)[[NSString
      stringWithFormat:@"%@/Info.plist", [app_dict objectForKey:@"app_path"]]
      UTF8String];
  int fd = open(info_path, O_RDONLY, 0);

  if (fd < 0)
    return KERN_FAILURE;

  info_file = fdopen(fd, "r");

  fseek(info_file, 0, SEEK_END);
  plist_size = ftell(info_file);
  rewind(info_file);
  plist_contents = malloc(plist_size * (sizeof(char)));
  fread(plist_contents, sizeof(char), plist_size, info_file);

  close(fd);
  fclose(info_file);

  NSString *plist_string = [NSString stringWithFormat:@"%s", plist_contents];
  NSData *data = [plist_string dataUsingEncoding:NSUTF8StringEncoding];

  NSError *error;
  NSPropertyListFormat format;
  NSDictionary *dict =
      [NSPropertyListSerialization propertyListWithData:data
                                                options:kNilOptions
                                                 format:&format
                                                  error:&error];

  // check if we're null or not
  if (dict == NULL) { // probably a binary plist

    NSString *local_info_path =
        [NSString stringWithFormat:@"%@/Info.plist", local_app_info_path];

    // try to copy the file to our dir then read it
    copy_file(info_path, strdup([local_info_path UTF8String]), MOBILE_UID,
              MOBILE_GID, 0755);

    dict = [NSDictionary dictionaryWithContentsOfFile:local_info_path];

    if (dict == NULL) {
      [app_dict setValue:@NO forKey:@"valid"];
      return KERN_FAILURE;
    }
  }

  // Some apps don't use "CFBundleDisplayName"
  if ([dict objectForKey:@"CFBundleDisplayName"] != nil) {
    [app_dict setObject:[dict objectForKey:@"CFBundleDisplayName"]
                 forKey:@"raw_display_name"];

  } else {

    if ([dict objectForKey:@"CFBundleName"] != nil) {
      [app_dict setObject:[dict objectForKey:@"CFBundleName"]
                   forKey:@"raw_display_name"];
    } else {
      [app_dict setValue:@NO forKey:@"valid"];
      return KERN_FAILURE;
    }
  }

  //    NSLog(@"%@", [app_dict objectForKey:@"raw_display_name"]);

  NSMutableArray *app_icons_list = [[NSMutableArray alloc] init];

  // Lookup Icon names
  if ([dict objectForKey:@"CFBundleIcons"] != nil) {

    NSDictionary *icons_dict = [dict objectForKey:@"CFBundleIcons"];
    if ([icons_dict objectForKey:@"CFBundlePrimaryIcon"] != nil) {

      NSDictionary *primary_icon_dict =
          [icons_dict objectForKey:@"CFBundlePrimaryIcon"];

      if ([primary_icon_dict objectForKey:@"CFBundleIconFiles"] != nil) {

        for (NSString *raw_icon in
             [primary_icon_dict valueForKeyPath:@"CFBundleIconFiles"]) {

          NSString *icon =
              [raw_icon stringByReplacingOccurrencesOfString:@".png"
                                                  withString:@""];

          // regular icon
          if (![app_icons_list containsObject:icon]) {
            //                        NSLog(@"[INFO]: adding icon: %@", icon);
            [app_icons_list addObject:icon];
          }

          // 2x icon
          NSString *_2xicon = [icon stringByAppendingString:@"@2x"];

          if (![app_icons_list containsObject:_2xicon]) {
            //                        NSLog(@"[INFO]: adding icon 2x: %@",
            //                        _2xicon);
            [app_icons_list addObject:_2xicon];
          }

          // 3x icon
          NSString *_3xicon = [icon stringByAppendingString:@"@3x"];
          if (![app_icons_list containsObject:_3xicon]) {
            //                        NSLog(@"[INFO]: adding icon 3x: %@",
            //                        _3xicon);
            [app_icons_list addObject:_3xicon];
          }
        }
      }
    }
  }

  if ([dict objectForKey:@"CFBundleIcons~ipad"] != nil) {

    NSDictionary *icons_dict = [dict objectForKey:@"CFBundleIcons~ipad"];
    if ([icons_dict objectForKey:@"CFBundlePrimaryIcon"] != nil) {

      NSDictionary *primary_icon_dict =
          [icons_dict objectForKey:@"CFBundlePrimaryIcon"];

      if ([primary_icon_dict objectForKey:@"CFBundleIconFiles"] != nil) {

        for (NSString *raw_icon in
             [primary_icon_dict valueForKeyPath:@"CFBundleIconFiles"]) {

          NSString *icon =
              [raw_icon stringByReplacingOccurrencesOfString:@".png"
                                                  withString:@""];

          // regular icon
          if (![app_icons_list containsObject:icon]) {
            //                        NSLog(@"[INFO]: adding icon: %@", icon);
            [app_icons_list addObject:icon];
          }

          // 2x icon
          NSString *_2xicon = [icon stringByAppendingString:@"@2x"];

          if (![app_icons_list containsObject:_2xicon]) {
            //                        NSLog(@"[INFO]: adding icon 2x: %@",
            //                        _2xicon);
            [app_icons_list addObject:_2xicon];
          }

          // 2x~ipad icon
          NSString *_2x_ipad_icon = [_2xicon stringByAppendingString:@"~ipad"];
          if (![app_icons_list containsObject:_2x_ipad_icon]) {
            //                        NSLog(@"[INFO]: adding icon 2x~ipad: %@",
            //                        _2x_ipad_icon);
            [app_icons_list addObject:_2x_ipad_icon];
          }

          // 3x icon
          NSString *_3xicon = [icon stringByAppendingString:@"@3x"];
          if (![app_icons_list containsObject:_3xicon]) {
            //                        NSLog(@"[INFO]: adding icon 3x: %@",
            //                        _3xicon);
            [app_icons_list addObject:_3xicon];
          }

          // 3x~ipad icon
          NSString *_3x_ipad_icon = [_3xicon stringByAppendingString:@"~ipad"];
          if (![app_icons_list containsObject:_3x_ipad_icon]) {
            //                        NSLog(@"[INFO]: adding icon 3x~ipad: %@",
            //                        _3x_ipad_icon);
            [app_icons_list addObject:_3x_ipad_icon];
          }
        }
      }
    }
  }

  //    [app_icons_list addObject:@"AppIcon40x40~ipad"];
  //    [app_icons_list addObject:@"AppIcon29x29~ipad"];
  //    [app_icons_list addObject:@"AppIcon76x76~ipad"];
  [app_dict setObject:app_icons_list forKey:@"icons"];
  //    NSLog(@"%@", app_icons_list);
  [app_dict setObject:[dict objectForKey:@"CFBundleIdentifier"]
               forKey:@"identifier"];
  [app_dict setObject:[dict objectForKey:@"CFBundleExecutable"]
               forKey:@"executable"];
  [app_dict setValue:@YES forKey:@"valid"];

  return KERN_SUCCESS;
}

/*
 *  Purpose: returns an image with a given radius/width/height
 */
UIImage *get_image_for_radius(int radius, int width, int height) {

  printf("[INFO]: image for width and height: %d %d\n", width, height);
  CGRect rect = CGRectMake(0, 0, width, height);
  UIGraphicsBeginImageContext(rect.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetFillColorWithColor(context, [[UIColor blackColor] CGColor]);
  CGContextFillRect(context, rect);
  UIImage *src_image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  CALayer *image_layer = [CALayer layer];
  image_layer.frame =
      CGRectMake(0, 0, src_image.size.width, src_image.size.height);
  image_layer.contents = (id)src_image.CGImage;

  image_layer.masksToBounds = YES;
  image_layer.cornerRadius = radius;

  UIGraphicsBeginImageContext(src_image.size);
  [image_layer renderInContext:UIGraphicsGetCurrentContext()];
  UIImage *rounded_image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return rounded_image;
}

/*
 *  Purpose: changes the radius of icons
 */
kern_return_t change_icons_shape(int radius) {

  printf("[INFO]: given radius: %d\n", radius);

  char *framework_path =
      "/System/Library/PrivateFrameworks/MobileIcons.framework";
  NSArray *icon_names = [[NSArray alloc]
      initWithObjects:
          @{ @"name" : @"AppIconMask@2x~iphone.png",
             @"size" : @120 },
          @{ @"name" : @"AppIconMask@3x~iphone.png",
             @"size" : @180 },
          @{ @"name" : @"AppIconMask@3x~ipad.png",
             @"size" : @152 },
          @{ @"name" : @"NotificationAppIconMask@2x.png",
             @"size" : @40 },
          @{ @"name" : @"NotificationAppIconMask@3x.png",
             @"size" : @60 },
          @{ @"name" : @"SpotlightAppIconMask@2x.png",
             @"size" : @80 },
          @{ @"name" : @"SpotlightAppIconMask@3x.png",
             @"size" : @120 },
          nil];

  //    // restore the originals first
  //    for(NSDictionary *icon_dict in icon_names) {
  //        NSString *icon_name = [icon_dict objectForKey:@"name"];
  //        copy_file(strdup([[NSString stringWithFormat:@"%s/bck_%@",
  //        framework_path, icon_name] UTF8String]), strdup([[NSString
  //        stringWithFormat:@"%s/%@", framework_path, icon_name] UTF8String]),
  //        ROOT_UID, WHEEL_GID, 0644);
  //    }

  for (NSDictionary *icon_dict in icon_names) {

    NSString *icon_name = [icon_dict objectForKey:@"name"];
    int icon_size = [[icon_dict objectForKey:@"size"] intValue];

    // fix radius for small icons (only if radius is big enough)
    if (icon_size < 100 && radius >= 10)
      radius /= 2;

    UIImage *converted_image =
        get_image_for_radius(radius, icon_size, icon_size);
    NSData *image_data = UIImagePNGRepresentation(converted_image);

    // save the image in our path then copy it
    NSString *saved_png_path = [[NSSearchPathForDirectoriesInDomains(
        NSDocumentDirectory, NSUserDomainMask, YES) firstObject]
        stringByAppendingString:@"/icon_mask.png"];
    [image_data writeToFile:saved_png_path atomically:YES];

    // copy the mask to each of the icon masks
    copy_file(strdup([saved_png_path UTF8String]),
              strdup([[NSString stringWithFormat:@"%s/%@", framework_path,
                                                 icon_name] UTF8String]),
              ROOT_UID, WHEEL_GID, 0644);
  }

  // profit??!

  return KERN_SUCCESS;
}

UIImage *change_image_tint_to(UIImage *src_image, UIColor *color) {

  CGRect rect = CGRectMake(0, 0, src_image.size.width, src_image.size.height);
  UIGraphicsBeginImageContext(rect.size);
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextClipToMask(context, rect, src_image.CGImage);
  CGContextSetFillColorWithColor(context, [color CGColor]);
  CGContextFillRect(context, rect);
  UIImage *colorized_image = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  return colorized_image;
}

/*
 *  Purpose: changes the color of icon badges
 */
kern_return_t change_icon_badge_color(const char *color_raw,
                                      const char *size_type) {

  UIImage *badge = NULL;
  NSString *file_name = NULL;

  if (strcmp("2x", size_type) == 0) {
    badge = get_image_for_radius(12, 24, 24);
    file_name = @"SBBadgeBG@2x.png";
  } else if (strcmp("3x", size_type) == 0) {
    badge = get_image_for_radius(24, 48, 48);
    file_name = @"SBBadgeBG@3x.png";
  }

  unsigned int rgb = 0;
  [[NSScanner
      scannerWithString:
          [[[NSString stringWithFormat:@"%s", color_raw] uppercaseString]
              stringByTrimmingCharactersInSet:
                  [[NSCharacterSet
                      characterSetWithCharactersInString:@"0123456789ABCDEF"]
                      invertedSet]]] scanHexInt:&rgb];

  UIColor *uiColor =
      [UIColor colorWithRed:((CGFloat)((rgb & 0xFF0000) >> 16)) / 255.0
                      green:((CGFloat)((rgb & 0xFF00) >> 8)) / 255.0
                       blue:((CGFloat)(rgb & 0xFF)) / 255.0
                      alpha:1.0];
  badge = change_image_tint_to(badge, uiColor);

  // iOS 11, save as png and copy to SpringBoard (EDIT: 11 now stores files in
  // Assets.car :( ) iOS 10, save as cpbitmap and copy to Caches
  //    if ([[[UIDevice currentDevice] systemVersion] containsString:@"11"]) {
  //
  //        NSString *saved_png_path = [NSString stringWithFormat:@"%@/%@",
  //        [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,
  //        NSUserDomainMask, YES) firstObject], file_name];
  //
  //        NSData *image_data = UIImagePNGRepresentation(badge);
  //        [image_data writeToFile:saved_png_path atomically:YES];
  //
  //
  //        copy_file(strdup([saved_png_path UTF8String]),
  //        strdup([[@"/System/Library/CoreServices/SpringBoard.app/"
  //        stringByAppendingString:file_name] UTF8String]), MOBILE_UID,
  //        MOBILE_GID, 0666);
  //
  //    } else {
  NSString *saved_cpbitmap_path =
      [NSString stringWithFormat:@"%@/SBIconBadgeView.BadgeBackground.cpbitmap",
                                 [NSSearchPathForDirectoriesInDomains(
                                     NSDocumentDirectory, NSUserDomainMask, YES)
                                     firstObject]];

  [badge writeToCPBitmapFile:saved_cpbitmap_path flags:1];

  copy_file(strdup([saved_cpbitmap_path UTF8String]),
            "/var/mobile/Library/Caches/MappedImageCache/Persistent/"
            "SBIconBadgeView.BadgeBackground.cpbitmap",
            MOBILE_UID, MOBILE_GID, 0666);
  //    }

  return KERN_SUCCESS;
}
