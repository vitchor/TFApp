//
//  AppDelegate.m
//  TFApp
//
//  Created by Victor on 9/16/13.
//  Copyright (c) 2013 Victor. All rights reserved.
//

#import "AppDelegate.h"


@implementation AppDelegate

@synthesize tabBarController;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
    [[UIApplication sharedApplication] setStatusBarHidden:YES  withAnimation:UIStatusBarAnimationFade];
    
    self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
    // Override point for customization after application launch.
    self.window.backgroundColor = [UIColor whiteColor];
    [self.window makeKeyAndVisible];
    
    
    self.tabBarController =  [[DyfocusUITabBarController alloc] init];

    
    UITabBarItem *cameraTab = [[UITabBarItem alloc] initWithTitle:@"Shoot" image:[UIImage imageNamed:@"df_shoot_bw.png"] tag:3];
    
    UITabBarItem *featuredTab = [[UITabBarItem alloc] initWithTitle:@"Featured" image:[UIImage imageNamed:@"df_featured.png"] tag:2];
    
    
    CGRect screenBounds = [[UIScreen mainScreen] bounds];
    if (screenBounds.size.height == 568) {
        // code for 4-inch screen
        cameraViewController = [[CameraView alloc] initWithNibName:@"CameraView_5" bundle:nil];
    } else {
        // code for 3.5-inch screen
        cameraViewController = [[CameraView alloc] initWithNibName:@"CameraView" bundle:nil];
    }
    cameraViewController.hidesBottomBarWhenPushed = YES;
    cameraNavigationController = [[UINavigationController alloc] initWithRootViewController:cameraViewController];
    cameraNavigationController.hidesBottomBarWhenPushed = YES;
    
    featuredPictureController = [[FOFTableController alloc] init];
    
    [cameraNavigationController setTabBarItem:cameraTab];
    [featuredPictureController setTabBarItem:featuredTab];
    
    NSArray* controllers = [NSArray arrayWithObjects: featuredPictureController, cameraNavigationController, nil];
    self.tabBarController.viewControllers = controllers;
    
    //self.tabBarController.viewControllers = controllers;
    
    // Configure window
    
    self.window.rootViewController  = self.tabBarController;
    [self.window addSubview:self.tabBarController.view];

    return YES;
}

-(void)goBackToLastController {
    
    if (tabBarController.lastControllerIndex != -1) {
        [self.tabBarController setSelectedIndex:tabBarController.lastControllerIndex];
        tabBarController.selectedIndex =tabBarController.lastControllerIndex;
        [tabBarController setActualControllerIndex:tabBarController.lastControllerIndex];
        
    } else {
        [self.tabBarController setSelectedIndex:0];
        tabBarController.selectedIndex =0;
        [tabBarController setActualControllerIndex:0];
    }
    
    [self.tabBarController setSelectedIndex:tabBarController.lastControllerIndex];
    tabBarController.selectedIndex =tabBarController.lastControllerIndex;
    [tabBarController setActualControllerIndex:tabBarController.lastControllerIndex];
    
    NSLog(@"Going back to controller %d", tabBarController.lastControllerIndex);
    NSLog(@"Going back to controller %d", tabBarController.actualControllerIndex);
}


- (void)applicationWillResignActive:(UIApplication *)application
{
    // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later. 
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
}

@end
