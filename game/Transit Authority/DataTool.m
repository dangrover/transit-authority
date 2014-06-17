//
//  DataTool.m
//  Transit Authority
//
//  Created by Dan Grover on 9/9/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "DataTool.h"
#import "MainGameScene.h"
#import "StatsDetailViewController.h"

@implementation DataTool{
    UIViewController *_chosenVC;
}

- (id) init{
    if (self = [super init]){
        [[UINib nibWithNibName:@"DataToolUI" bundle:nil] instantiateWithOwner:self options:nil];
        self.navController.viewControllers = @[mainVC];
        self.navController.view.frame = mainVC.view.frame;
        self.navController.view.backgroundColor = [UIColor clearColor];
        
        mainVC.view.backgroundColor = [UIColor clearColor];
    }
    return self;
}

- (BOOL) showsHelpText{
    return NO;
}

- (void) started{
    paneChooser.selectedSegmentIndex = 0;
    [self newPane:paneChooser];
}


- (void) finished{
    [_chosenVC viewWillDisappear:NO];
    _chosenVC = nil;
}


- (BOOL) allowsPanning{
    return YES;
}

- (IBAction)newPane:(id)sender{
    [self _showVC:(paneChooser.selectedSegmentIndex == 0) ? statsVC : layersVC];
}

- (void) _showVC:(UIViewController *)newVC{
    if(_chosenVC){
        [_chosenVC.view removeFromSuperview];
        _chosenVC = nil;
    }
    
    _chosenVC = newVC;
    [_chosenVC viewWillAppear:NO];
    [mainVC.view addSubview:_chosenVC.view];
    
    _chosenVC.view.frame = CGRectMake(0, 39, self.viewController.view.frame.size.width, self.viewController.view.frame.size.height);
    _chosenVC.view.backgroundColor = [UIColor clearColor];
    [_chosenVC viewDidAppear:NO];
}

@end

#pragma mark -

@implementation DataToolLayersViewController

- (void) viewWillAppear:(BOOL)animated{
    [popLayerSwitch setOn:self.parent.parent.showPopulationHeatmap animated:NO];
}

- (IBAction) popLayerChanged:(id)sender{
    self.parent.parent.showPopulationHeatmap = popLayerSwitch.on;
}

@end

#pragma mark -

@implementation DataToolStatsViewController{
    NSTimer *_refreshTimer;
}

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    _refreshTimer = [NSTimer scheduledTimerWithTimeInterval:2
                                                     target:self
                                                   selector:@selector(_updateDisplay)
                                                   userInfo:nil
                                                    repeats:YES];
    [self _updateDisplay];
}

- (void) viewWillDisappear:(BOOL)animated{
    NSLog(@"stats view got view will disappear");
    [_refreshTimer invalidate];
    _refreshTimer = nil;
    [super viewWillDisappear:animated];
}


- (void) _updateDisplay{
    if(![_refreshTimer isValid]) return;
    GameState *state = self.parent.parent.gameState;
 
    float servedByStations = state.proportionOfPopulationServedByStations;
    
    percentTripsMadeLabel.text = [NSString stringWithFormat:@"%.1f%%",state.proportionOfTripsMadeViaSystem * 100];
    popServedLabel.text = [NSString stringWithFormat:@"%.1f%%",servedByStations * 100];
    //trainsCount.text = [NSString stringWithFormat:@"%d",self.state.assignedTrains.count];
    //stationsCount.text = [NSString stringWithFormat:@"%d",self.state.stations.count];
    
    NSNumber *wait = [state.ledger getAggregate:Stat_Average
                                         forKey:GameLedger_TrainWaitTime
                             forRollingInterval:SECONDS_PER_DAY
                                         ending:state.currentDate
                                    interpolate:Interpolation_None];
    
    waitTimeLabel.text = [NSString stringWithFormat:@"%dm",(int)ceil([wait doubleValue]/60)];
    
    
    int trips = [[state.ledger getAggregate:Stat_Count
                                     forKey:GameLedger_BoardTrain
                         forRollingInterval:SECONDS_PER_DAY
                                     ending:state.currentDate
                                interpolate:Interpolation_None] intValue];
    
    if(trips < 1000){
        dailyRidersLabel.text = [NSString stringWithFormat:@"%d",trips];
    }else{
        dailyRidersLabel.text = [NSString stringWithFormat:@"%dK",trips/1000];
    }
}


- (IBAction)showRidershipDetail:(id)sender{
    [self.parent.navController pushViewController:self.parent.ridershipBreakdownVC animated:YES];
}


- (IBAction)showCoverageDetail:(id)sender{
    StatDisplay *d = [[StatDisplay alloc] init];
    d.title = @"Coverage";
    d.type = Stat_SingleValue;
    d.key = GameLedger_PopulationServedProportion;
    d.yMultiplier = @(100);
    d.yFormatter = [[NSNumberFormatter alloc] init];
    d.yFormatter.positiveSuffix = @"%";
    d.interpolate = Interpolation_ForwardFill;
    
    StatsDetailViewController *detailVC = [[StatsDetailViewController alloc] initWithState:self.parent.parent.gameState displayDescription:d];
    [self.parent.navController pushViewController:detailVC animated:YES];
}

- (IBAction)showTripsPerDayDetail:(id)sender{
    StatDisplay *d = [[StatDisplay alloc] init];
    d.title = @"Riders";
    d.type = Stat_Count;
    d.key = GameLedger_BoardTrain;
    
    StatsDetailViewController *detailVC = [[StatsDetailViewController alloc] initWithState:self.parent.parent.gameState displayDescription:d];
    [self.parent.navController pushViewController:detailVC animated:YES];
}

- (IBAction)showWaitDetail:(id)sender{
    NSLog(@"Showing wait detail on %@, %@",self.parent, self.parent.navController);
    StatDisplay *d = [[StatDisplay alloc] init];
    d.title = @"Wait Times";
    d.type = Stat_Average;
    d.key = GameLedger_TrainWaitTime;
    d.yMultiplier = [[NSDecimalNumber alloc] initWithDouble:1.0/60.0]; // display in minutes
    d.yFormatter = [[NSNumberFormatter alloc] init];
    d.yFormatter.positiveSuffix = @"m";
    StatsDetailViewController *detailVC = [[StatsDetailViewController alloc] initWithState:self.parent.parent.gameState displayDescription:d];
    [self.parent.navController pushViewController:detailVC animated:YES];
}

@end


#pragma mark -

@implementation DataToolRidershipBreakdownViewController

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self _updateDisplay];
}

- (void) _updateDisplay{
    GameState *state = self.parent.parent.gameState;
    NSTimeInterval currentDate = state.currentDate;
    
   // float servedByStationsProportion = state.proportionOfPopulationServedByStations;
    
    int allTakeTrains = [[state.ledger getAggregate:Stat_Count
                                             forKey:GameLedger_BoardTrain
                                 forRollingInterval:SECONDS_PER_DAY
                                             ending:currentDate
                                        interpolate:Interpolation_None] intValue];
    // reasons for not taking the train
    int allRejects = [[state.ledger getAggregate:Stat_Count
                                               forKey:GameLedger_Prefix_Reject
                                   forRollingInterval:SECONDS_PER_DAY
                                               ending:currentDate
                                          interpolate:Interpolation_None] intValue];
    
    int gaveUp = [[state.ledger getAggregate:Stat_Count
                                           forKey:GameLedger_Reject_GiveUp
                               forRollingInterval:SECONDS_PER_DAY
                                           ending:currentDate
                                      interpolate:Interpolation_None] intValue];
    
    int noDest = [[state.ledger getAggregate:Stat_Count
                                           forKey:GameLedger_Reject_NoDestStation
                               forRollingInterval:SECONDS_PER_DAY
                                           ending:currentDate
                                      interpolate:Interpolation_None] intValue];
    
    int walk = [[state.ledger getAggregate:Stat_Count
                                         forKey:GameLedger_Reject_Walked
                             forRollingInterval:SECONDS_PER_DAY
                                         ending:currentDate
                                    interpolate:Interpolation_None] intValue];
    
    int tooLong = [[state.ledger getAggregate:Stat_Count
                                            forKey:GameLedger_Reject_TooLong
                                forRollingInterval:SECONDS_PER_DAY
                                            ending:currentDate
                                       interpolate:Interpolation_None] intValue];
    
    
    NSLog(@"%d total rejects, %d gave up, %d noDest, %d walk, %d toolong", allRejects, gaveUp, noDest, walk, tooLong);
    
    int totalTripsPossibleFromOriginStations = allRejects + allTakeTrains;
    
    
    //float rejectProportion = ((float)allRejects/(float)totalTripsPossibleFromOriginStations);
    float noDestProportion = ((float)noDest/(float)totalTripsPossibleFromOriginStations);
    float tooLongProportion = ((float)tooLong/(float)totalTripsPossibleFromOriginStations);
    float gaveUpProportion = ((float)gaveUp/(float)totalTripsPossibleFromOriginStations);
    float walkProportion = ((float)walk/(float)totalTripsPossibleFromOriginStations);
    
  //  tookTrainLabel.text = [NSString stringWithFormat:@"%.1f%%",takeTrainProportion*100];
    //didntTakeTrainLabel.text = [NSString stringWithFormat:@"%.1f%%",rejectProportion*100];
    
    noDestStationLabel.text = [NSString stringWithFormat:@"%.1f%%",noDestProportion*100];
   // noOriginStationLabel.text = [NSString stringWithFormat:@"%.1f%%",noOriginProportion*100];
    gaveUpLabel.text = [NSString stringWithFormat:@"%.1f%%",gaveUpProportion*100];
    walkedLabel.text = [NSString stringWithFormat:@"%.1f%%",walkProportion*100];
    tooLongLabel.text = [NSString stringWithFormat:@"%.1f%%",tooLongProportion*100];
}

- (IBAction)back:(id)sender{
    [self.parent.navController popViewControllerAnimated:YES];
}

@end
