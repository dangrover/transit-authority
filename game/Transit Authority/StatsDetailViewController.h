//
//  StatsDetailViewController.h
//  Transit Authority
//
//  Created by Dan Grover on 7/19/13.
//
//

#import <UIKit/UIKit.h>
#import "CPTGraphHostingView.h"
#import "GameLedger.h"

typedef enum {
    StatPeriod_Day,
    StatPeriod_Week,
    StatPeriod_Year,
    StatPeriod_AllTime
} StatPeriod;

@interface StatDisplay : NSObject
@property(strong) NSString *key;
@property(assign) GameStat type;
@property(assign) Interpolation interpolate;

@property(strong) NSString *title;
@property(strong) NSNumber *minY;
@property(strong) NSNumber *maxY;
@property(strong) NSNumber *yMultiplier;
@property(strong) NSNumberFormatter *yFormatter;
@end

@class GameState;
@interface StatsDetailViewController : UIViewController{
    IBOutlet UILabel *titleLabel;
    IBOutlet UISegmentedControl *timeWindow;
    IBOutlet CPTGraphHostingView *graphView;
}

- (id) initWithState:(GameState *)theGameState displayDescription:(StatDisplay *)theDisplay;

@property(strong, readonly) GameState *gameState;
@property(strong, readonly) StatDisplay *displayDescription;

- (IBAction)back:(id)sender;
- (IBAction)changedTimeWindow:(id)sender;

@end
