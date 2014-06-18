//
//  FinancesViewController.h
//  Transit Authority
//
//  Created by Dan Grover on 7/9/13.
//
//

#import <UIKit/UIKit.h>
#import "GameState.h"
#import "TAModal.h"

@protocol FinancesViewDelegate;

@interface FinancesViewController : TAModal{
    IBOutlet UITableView *tableView;
    IBOutlet UIView *summaryScreen;
    IBOutlet UINavigationController *navController;
}
- (id) initWithGameState:(GameState *)state;
- (IBAction)back:(id)sender;

@property(strong) GameState *state;
@property(assign) NSObject<FinancesViewDelegate> *delegate;

@end

#pragma mark -

@protocol FinancesViewDelegate <NSObject>
- (void) financesFinished:(FinancesViewController *)statsVC;
@end
