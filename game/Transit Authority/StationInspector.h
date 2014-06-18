//
//  StationInspector.h
//  Transit Authority
//
//  Created by Dan Grover on 7/13/13.
//
//

#import <UIKit/UIKit.h>
#import "GameState.h"

@class UpgradesViewController, StationStatsViewController, UpgradeDetailViewController;

@interface StationInspector : UIViewController{
    IBOutlet UpgradesViewController *upgradesVC;
    IBOutlet StationStatsViewController *statsVC;
    IBOutlet UpgradeDetailViewController *upgradeDetailVC;
}

- (id)initWithStation:(Station *)theStation gameState:(GameState *)theState;

@property(assign, readonly) Station *station;
@property(assign, readonly) GameState *state;

- (IBAction)showUpgrades:(id)sender;
- (IBAction)showStats:(id)sender;
- (IBAction)destroyStation:(id)sender;

- (IBAction)back:(id)sender;
@end


@interface UpgradesViewController : UIViewController{
    IBOutlet UITableView *tableView;
}

@property(assign) StationInspector *parent;

@end


@interface StationStatsViewController : UIViewController
@property(assign) StationInspector *parent;
@end

@interface UpgradeDetailViewController : UIViewController{
    
}

@property(strong) NSString *upgradeIdentifier;
@property(assign) StationInspector *parent;

@property(strong) IBOutlet UILabel *nameLabel;
@property(strong) IBOutlet UILabel *costLabel;
@property(strong) IBOutlet UILabel *descriptionLabel;

- (IBAction) upgrade:(id)sender;

@end