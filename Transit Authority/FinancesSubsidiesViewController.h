//
//  FinancesSubsidiesViewController.h
//  Transit Authority
//
//  Created by Dan Grover on 7/17/13.
//
//

#import <UIKit/UIKit.h>
#import "TAModal.h"

@class GameState;

@interface FinancesSubsidiesViewController : TAModal{
    IBOutlet UILabel *localSubsidyLabel;
    IBOutlet UILabel *federalSubsidyLabel;
    IBOutlet UILabel *totalSubsidyLabel;
    
    IBOutlet UILabel *fedLobbyWaitLabel;
    IBOutlet UILabel *localLobbyWaitLabel;
    IBOutlet UIButton *fedLobbyButton;
    IBOutlet UIButton *localLobbyButton;
}

- (id) initWithState:(GameState *)state;

@property(strong, readonly) GameState *gameState;

- (IBAction)lobbyLocal:(id)sender;
- (IBAction)lobbyFed:(id)sender;


- (IBAction)back:(id)sender;

@end
