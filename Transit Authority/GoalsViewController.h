//
//  GoalsViewController.h
//  Transit Authority
//
//  Created by Dan Grover on 8/13/13.
//
//

#import <UIKit/UIKit.h>
#import "GameState.h"
#import "TAModal.h"

@protocol GoalsDelegate;

@interface GoalsViewController : TAModal{
    IBOutlet UILabel *tier1goal1Caption;
    IBOutlet UIImageView *tier1goal1Check;
    IBOutlet UILabel *tier1goal1Status;
    IBOutlet UILabel *tier1goal2Caption;
    IBOutlet UIImageView *tier1goal2Check;
    IBOutlet UILabel *tier1goal2Status;
    
    IBOutlet UILabel *tier2goal1Caption;
    IBOutlet UIImageView *tier2goal1Check;
    IBOutlet UILabel *tier2goal1Status;
    IBOutlet UILabel *tier2goal2Caption;
    IBOutlet UIImageView *tier2goal2Check;
    IBOutlet UILabel *tier2goal2Status;
    
    IBOutlet UILabel *tier3goal1Caption;
    IBOutlet UIImageView *tier3goal1Check;
    IBOutlet UILabel *tier3goal1Status;
    IBOutlet UILabel *tier3goal2Caption;
    IBOutlet UIImageView *tier3goal2Check;
    IBOutlet UILabel *tier3goal2Status;
}

- (id) initWithGameState:(GameState *)state;

@property(strong, readonly) GameState *state;
@property(assign) NSObject<GoalsDelegate> *delegate;

- (IBAction)back:(id)sender;

@end

@protocol GoalsDelegate <NSObject>
- (void) goalsFinished:(GoalsViewController *)aGoalsVC;
@end