//
//  DataTool.h
//  Transit Authority
//
//  Created by Dan Grover on 9/9/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "GameTool.h"

@class DataToolLayersViewController, DataToolStatsViewController,DataToolRidershipBreakdownViewController;

@interface DataTool : GameTool{
    IBOutlet UISegmentedControl *paneChooser;
    IBOutlet DataToolStatsViewController *statsVC;
    IBOutlet DataToolLayersViewController *layersVC;
    
    IBOutlet UIViewController *mainVC;
}


@property(strong) IBOutlet UIViewController *viewController;
@property(strong) IBOutlet UINavigationController *navController;
@property(strong) IBOutlet DataToolRidershipBreakdownViewController *ridershipBreakdownVC;

- (IBAction)newPane:(id)sender;


@end


@interface DataToolLayersViewController : UIViewController{
    IBOutlet UISwitch *popLayerSwitch;
}

- (IBAction) popLayerChanged:(id)sender;

@property(assign) IBOutlet DataTool *parent;

@end

@interface DataToolStatsViewController : UIViewController{
    IBOutlet UILabel *percentTripsMadeLabel;
    IBOutlet UILabel *popServedLabel;
    IBOutlet UILabel *waitTimeLabel;
    IBOutlet UILabel *dailyRidersLabel;
}

@property(assign) IBOutlet DataTool *parent;

- (IBAction)showRidershipDetail:(id)sender;
- (IBAction)showCoverageDetail:(id)sender;
- (IBAction)showTripsPerDayDetail:(id)sender;
- (IBAction)showWaitDetail:(id)sender;

@end

#pragma mark -

@interface DataToolRidershipBreakdownViewController : UIViewController{
    IBOutlet UILabel *noOriginStationLabel;
    IBOutlet UILabel *noDestStationLabel;
    IBOutlet UILabel *tooLongLabel;
    IBOutlet UILabel *gaveUpLabel;
    IBOutlet UILabel *walkedLabel;
    IBOutlet UILabel *tookTrainLabel;
    IBOutlet UILabel *didntTakeTrainLabel;
}

@property(assign) IBOutlet DataTool *parent;

- (IBAction)back:(id)sender;

@end