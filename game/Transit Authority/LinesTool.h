//
//  LinesTool.h
//  Transit Authority
//
//  Created by Dan Grover on 6/25/13.
//
//

#import "GameTool.h"
#import "GameState.h"

@class NewLineViewController, EditLineViewController;

@interface LinesTool : GameTool{
    IBOutlet UINavigationController *navController;
    IBOutlet NewLineViewController *newLineViewController;
    IBOutlet EditLineViewController *editLineViewController;
    IBOutlet UIViewController *mainVC;
}

- (IBAction) newLine:(id)sender;

@property(strong) IBOutlet UITableView *tableView;
@property(strong) IBOutlet UIViewController *viewController;

@end

#pragma mark -

@interface NewLineViewController : UIViewController{
    IBOutlet UIButton *confirmButton;
}
@property(assign) IBOutlet LinesTool *parent;
- (IBAction) back:(id)sender;
- (IBAction) confirm:(id)sender;
@end

#pragma mark -


@interface EditLineViewController : UIViewController{
    IBOutlet UILabel *titleLabel;
    IBOutlet UILabel *numberOfTrainsLabel;
    IBOutlet UILabel *trainLengthLabel;
    IBOutlet UISegmentedControl *trainsPlusMinus;
    IBOutlet UISegmentedControl *carsPlusMinus;
    IBOutlet UILabel *costLabel;
}

@property(strong) Line *line;
@property(assign) IBOutlet LinesTool *parent;

- (IBAction) back:(id)sender;
- (IBAction) changeTrainLength:(id)sender;
- (IBAction) changeNumberOfTrains:(id)sender;
- (IBAction) deleteLine:(id)sender;

@end