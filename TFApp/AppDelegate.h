//
//  AppDelegate.h
//  TFApp
//
//  Created by Victor on 9/16/13.
//  Copyright (c) 2013 Victor. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CameraView.h"
#import "FOFTableController.h"
#import "DyfocusUITabBarController.h"


@interface AppDelegate : UIResponder <UIApplicationDelegate> {

    CameraView *cameraViewController;
    UINavigationController *cameraNavigationController;
    FOFTableController *featuredPictureController;
}

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic, retain) DyfocusUITabBarController *tabBarController;

-(void)goBackToLastController;

@end
