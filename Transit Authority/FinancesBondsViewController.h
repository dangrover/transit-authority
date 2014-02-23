//
//  FinancesBondsViewController.h
//  Transit Authority
//
//  Created by Dan Grover on 7/17/13.
//
//

#import <UIKit/UIKit.h>
#import "TAModal.h"

@class GameState;

@interface FinancesBondsViewController : TAModal{
    IBOutlet UISegmentedControl *principalSegmentedControl;
    IBOutlet UILabel *rateLabel;
    IBOutlet UILabel *paymentLabel;
    
    IBOutlet UITableView *existingBonds;
    IBOutlet UIButton *issueButton;
}

- (id) initWithState:(GameState *)state;

@property(strong, readonly) GameState *gameState;

- (IBAction) back:(id)sender;

- (IBAction) newPrincipal:(id)sender;
- (IBAction) issue:(id)sender;


@end
