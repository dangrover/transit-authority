//
//  FinancesViewController.m
//  Transit Authority
//
//  Created by Dan Grover on 7/9/13.
//
//

#import "FinancesViewController.h"
#import "FinanceRowCell.h"
#import "Utilities.h"
#import "FinancesSubsidiesViewController.h"
#import "FinancesBondsViewController.h"
#import "GameLedger.h"
#import "GameFontSupport.h"

static NSString *cellIdent = @"cell";

@interface FinancesViewController ()

@end

@implementation FinancesViewController{
    NSTimer *_reloadTimer;
}

- (id) initWithGameState:(GameState *)state{
    if(self = [super initWithNibName:@"FinancesViewController" bundle:nil]){
        self.state = state;
    }
    return self;
}

- (void) dealloc{
    [_reloadTimer invalidate];
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    [tableView registerNib:[UINib nibWithNibName:@"FinanceRowCell" bundle:nil] forCellReuseIdentifier:cellIdent];
    
    _reloadTimer = [NSTimer scheduledTimerWithTimeInterval:3 target:tableView selector:@selector(reloadData) userInfo:nil repeats:YES];
}

- (IBAction)back:(id)sender{
    [self.delegate financesFinished:self];
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    if(section == 0){
        return 2;
    }else{
        return 4;
    }
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    FinanceRowCell *c = [tableView dequeueReusableCellWithIdentifier:cellIdent];
    
    NSString *ledgerCat = nil;
    if(indexPath.section == 0){
        NSArray *headers = @[@"Fares", @"Subsidies"];
        NSArray *ledgerValues = @[GameLedger_Finance_Income_Fare,GameLedger_Finance_Income_Subsidy, [NSNull null], [NSNull null]];
        
        c.textLabel.text = headers[indexPath.row];
        ledgerCat = ledgerValues[indexPath.row];
        
    }else if (indexPath.section == 1){
        NSArray *headers = @[@"Construction", @"Equipment", @"Ops/Maintenence", @"Debt Service"];
        NSArray *ledgerValues = @[GameLedger_Finance_Expense_Construction, GameLedger_Finance_Expense_Trains, GameLedger_Finance_Expense_Maintenence, GameLedger_Finance_Expense_DebtService];
        
        c.textLabel.text = headers[indexPath.row];
        ledgerCat = ledgerValues[indexPath.row];
    }
    
    
    if(![ledgerCat isEqual:[NSNull null]]){
        NSNumber *todayNum = [self.state.ledger getAggregate:Stat_Sum forKey:ledgerCat forDay:self.state.currentDate];
        
        NSNumber *yesterdayNum = [self.state.ledger getAggregate:Stat_Sum forKey:ledgerCat forDay:self.state.currentDate - SECONDS_PER_DAY];
        
        NSNumber *maxNum = [self.state.ledger getAggregate:Stat_Sum
                                                    forKey:ledgerCat
                                                     start:INT_MIN
                                                       end:INT_MAX
                                               interpolate:NO];
        
        c.col1Label.text = FormatCurrency(todayNum);
        c.col2Label.text = FormatCurrency(yesterdayNum);
        c.col3Label.text = FormatCurrency(maxNum);
        
        if([ledgerCat isEqual:GameLedger_Finance_Expense_DebtService] || [ledgerCat isEqual:GameLedger_Finance_Income_Subsidy]){
            c.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        }
    }else{
        c.col1Label.text = @"-";
        c.col2Label.text = @"-";
        c.col3Label.text = @"-";
    }
    
    c.textLabel.font = [UIFont gameFontOfSize:14];
    
    return c;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 2;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section{
    if(section == 0){
        return @"REVENUES";
    }else{
        return @"EXPENSES";
    }
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    NSLog(@"will select row at index path %@",indexPath);
    return nil;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath{
    if(indexPath.section == 0){
        // subsidies
        [self.navigationController pushViewController:[[FinancesSubsidiesViewController alloc] initWithState:self.state]
                                             animated:YES];
    }else{
        // debt service
        [self.navigationController pushViewController:[[FinancesBondsViewController alloc] initWithState:self.state]
                                             animated:YES];
        
    }
}
@end
