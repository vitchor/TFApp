//
//  FOFTableNavigationController.h
//  DyFocus
//
//  Created by Victor on 1/27/13.
//  Copyright (c) 2013 dyfocus. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "FOFTableController.h"

@interface FOFTableNavigationController : UINavigationController {
    
    FOFTableController *tableController;
    FOFTableController *trendingTableController;
    
    UISegmentedControl *segmentedControl;

    NSString *refreshTrendingUrl;
    
    BOOL isFirstTimeLoading;
}

-(id) initWithFOFArray:(NSArray *)FOFArray andUrl:(NSString *)refreshUrl;
-(id) initWithTopRatedFOFArray:(NSArray *)topRatedFOFArray andTopRatedUrl:(NSString *)refreshTopRatedUrl andTrendingFOFArray:(NSArray *)trendingFOFArray andTrendingUrl:(NSString *)refreshTrendingUrl;

-(void) setSegmentedControlHidden:(BOOL)hidden;
-(void) enableSegmentedControl:(BOOL)enable;

@property(nonatomic, retain) FOFTableController *tableController;
@property(nonatomic, retain) FOFTableController *trendingTableController;

@end
