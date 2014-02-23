//
//  FinancesBondsViewController.m
//  Transit Authority
//
//  Created by Dan Grover on 7/17/13.
//
//

#import "FinancesBondsViewController.h"
#import "GameState.h"
#import "GameLedger.h"
#import "FinancesViewController.h"
#import "FinanceRowCell.h"
#import "Utilities.h"

@interface FinancesBondsViewController ()
@property(strong, readwrite) GameState *gameState;

@end

@implementation FinancesBondsViewController{
    Bond *_pendingBond;
    NSArray *_sortedExistingBonds;
}

- (id) initWithState:(GameState *)state{
    if(self = [super initWithNibName:@"FinancesBondsViewController" bundle:nil]){
        self.gameState = state;
    }
    return self;
}


- (void) viewDidLoad{
    
    [super viewDidLoad];
    
    [existingBonds registerNib:[UINib nibWithNibName:@"FinanceRowCell" bundle:nil] forCellReuseIdentifier:@"cell"];
}

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    
    issueButton.layer.borderColor = [issueButton.tintColor CGColor];
    issueButton.layer.borderWidth = 1;
    issueButton.layer.cornerRadius = 5;
    
    [self _updatePaymentInfo];
    [self _updateExistingList];
}

- (IBAction)back:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction) newPrincipal:(id)sender{
    [self _updatePaymentInfo];
}

- (IBAction) issue:(id)sender{
    [self.gameState issueBond:_pendingBond];
    [self _updatePaymentInfo];
    
    [self _updateExistingList];
    
    
   // FinancesViewController *f = self.navigationController.viewControllers[0];
    //[f.delegate financesFinished:f];
    
}

- (float) currentlyChosenPrincipal{
    float amounts[3] = {50, 100, 250};
    return amounts[principalSegmentedControl.selectedSegmentIndex] * 1000;
}


- (void) _updatePaymentInfo{
    int days = 15;
    
    _pendingBond = [[Bond alloc] init];
    _pendingBond.principal = [self currentlyChosenPrincipal];
    _pendingBond.rate = 0.03;
    _pendingBond.term = SECONDS_PER_DAY*days;
    
    rateLabel.text = [NSString stringWithFormat:@"%d%%", (int)(_pendingBond.rate * 100)];
    paymentLabel.text = [NSString stringWithFormat:@"Bond will be repaid at rate of %@/day for %d days",
                         FormatCurrency(@([_pendingBond paymentForInterval:SECONDS_PER_DAY])),
                         days];
}

- (void) _updateExistingList{
    _sortedExistingBonds = [[self.gameState.outstandingBonds allObjects] sortedArrayUsingDescriptors:@[[[NSSortDescriptor alloc] initWithKey:@"dateIssued" ascending:NO]]];
    
    [existingBonds reloadData];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _sortedExistingBonds.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    
    Bond *b = [_sortedExistingBonds objectAtIndex:indexPath.row];
    FinanceRowCell *c = [tableView dequeueReusableCellWithIdentifier:@"cell"];
    
    c.col1Label.text = FormatCurrency(@(b.amountRemaining));
    
    int daysLeft = ceil(((b.dateIssued + b.term) - self.gameState.currentDate) / SECONDS_PER_DAY);
    c.col2Label.text = [NSString stringWithFormat:@"%d %@", daysLeft, (daysLeft == 1) ? @"day" : @"days"];
    
    c.col3Label.text = [NSString stringWithFormat:@"%@/day",FormatCurrency(@([b paymentForInterval:SECONDS_PER_DAY]))];
    
    c.col1Label.font = c.col2Label.font = c.col3Label.font = [UIFont systemFontOfSize:12];
    c.narrow = YES;
    
    return c;
}

@end