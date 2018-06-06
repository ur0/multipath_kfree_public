//
//  generic.c
//  extra_recipe
//
//  Created by Sem Voigtländer on 6/5/18.
//  Copyright © 2018 Ian Beer. All rights reserved.
//

#include "generic.h"
#include <CoreFoundation/CoreFoundation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
char *bundle_path() {
  CFBundleRef mainBundle = CFBundleGetMainBundle();
  CFURLRef resourcesURL = CFBundleCopyResourcesDirectoryURL(mainBundle);
  int len = 4096;
  char *path = malloc(len);

  CFURLGetFileSystemRepresentation(resourcesURL, TRUE, (UInt8 *)path, len);
  return (char *)path;
}
