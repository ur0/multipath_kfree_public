//
//  AppDelegate.h
//  XNUFuzzer
//
//  Created by Sem Voigtländer on 5/19/18.
//  Copyright © 2018 Sem Voigtländer. All rights reserved.
//

#import <CoreData/CoreData.h>
#import <UIKit/UIKit.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property(strong, nonatomic) UIWindow *window;

@property(readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;

@end
