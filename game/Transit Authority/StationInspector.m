//
//  StationInspector.m
//  Transit Authority
//
//  Created by Dan Grover on 7/13/13.
//
//

#import "StationInspector.h"
#import "Utilities.h"

static NSDictionary *upgradeInfo;

@interface StationInspector ()
@property(assign, readwrite) Station *station;
@property(assign, readwrite) GameState *state;
@end

@implementation StationInspector

- (id)initWithStation:(Station *)theStation gameState:(GameState *)theState{
    if (self = [super initWithNibName:@"StationInspector" bundle:nil]) {
        self.station = theStation;
        self.state = theState;
        
        upgradeInfo = @{StationUpgrade_Accessible: @{@"name":@"Accessible",
                                                      @"description": @"Allows the disabled to use the station and increases fed. subsidies."},
                         StationUpgrade_ParkingLot: @{@"name":@"Parking",
                                                      @"description": @"Increases coverage. In dense areas, costs more and affects less."},
                         StationUpgrade_LongPlatform: @{@"name":@"Long Platforms",
                                                        @"description": @"Allows station to fit longer trains."}};
    }
    
    return self;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    upgradesVC.parent = upgradeDetailVC.parent = self;
}

- (IBAction)showUpgrades:(id)sender{
    [self.navigationController pushViewController:upgradesVC animated:YES];
}

- (IBAction)showStats:(id)sender{
    [self.navigationController pushViewController:statsVC animated:YES];
}

- (IBAction)back:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) showUpgradeDetail:(NSString *)upgradeIdent{
    upgradeDetailVC.upgradeIdentifier = upgradeIdent;
    [self.navigationController pushViewController:upgradeDetailVC animated:YES];
}

- (IBAction)destroyStation:(id)sender{
    [self.state destoryStation:self.station];
    
}

@end

@implementation StationStatsViewController



@end

static NSString *upgradeCellIdent = @"upgradeCell";

@interface UpgradeCell : UITableViewCell

@end

@implementation UpgradeCell

- (void) layoutSubviews{
    [super layoutSubviews];
    self.imageView.frame = CGRectMake(4, 4, 24, 20);
    self.textLabel.frame = CGRectMake(32, 4, 120, 24 - 4);
    
    self.textLabel.font = [UIFont boldSystemFontOfSize:12];
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
}

@end

@implementation UpgradesViewController{
    NSArray *_availableUpgrades;
}
- (void) viewDidLoad{
    
    [tableView registerClass:[UpgradeCell class] forCellReuseIdentifier:upgradeCellIdent];
}

- (void) viewWillAppear:(BOOL)animated{
    NSArray *all = [self.parent.state allAvailableUpgrades];
    NSMutableArray *availableHere = [NSMutableArray array];
    for(NSString *ident in all){
        if(![self.parent.station.upgrades containsObject:ident]){
            [availableHere addObject:ident];
        }
    }
    _availableUpgrades = availableHere;
    [tableView reloadData];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return _availableUpgrades.count;
}

- (UITableViewCell *)tableView:(UITableView *)aTableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    UpgradeCell *cell = [tableView dequeueReusableCellWithIdentifier:upgradeCellIdent];
    if(!cell){
        cell = [[UpgradeCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:upgradeCellIdent];
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }
    
    NSString *upgradeIdent = _availableUpgrades[indexPath.row];

    cell.imageView.image = [UIImage imageNamed:[NSString stringWithFormat:@"upgrade-%@",upgradeIdent]];
    cell.textLabel.text = upgradeInfo[upgradeIdent][@"name"];

    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    [self.parent showUpgradeDetail:_availableUpgrades[indexPath.row]];
    return nil;
}

@end

@implementation UpgradeDetailViewController

- (void) viewWillAppear:(BOOL)animated{
    self.nameLabel.text = upgradeInfo[self.upgradeIdentifier][@"name"];
    self.descriptionLabel.text = upgradeInfo[self.upgradeIdentifier][@"description"];
    self.costLabel.text = FormatCurrency(@([self.parent.state costForUpgrade:self.upgradeIdentifier forStation:self.parent.station]));
    
    [super viewWillAppear:animated];

}

- (IBAction)upgrade:(id)sender{
    [self.parent.state purchaseUpgrade:self.upgradeIdentifier forStation:self.parent.station];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

@end
