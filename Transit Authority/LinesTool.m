//
//  LinesTool.m
//  Transit Authority
//
//  Created by Dan Grover on 6/25/13.
//
//

#import "LinesTool.h"
#import "GameState.h"
#import "MainGameScene.h"
#import "cocos2d.h"
#import "Utilities.h"
#import "PopoverView.h"

@interface LinesTool()<PopoverViewDelegate>
@end

@implementation LinesTool{
    Station *startStation;
    Station *endStation;
    PopoverView *popover;
    TrackSegment *selectedSegment;
}

- (id) init{
    if (self = [super init]){
        [[UINib nibWithNibName:@"LineToolUI" bundle:nil] instantiateWithOwner:self options:nil];
        navController.view.frame = CGRectMake(0, 0, 200, 160);
        navController.viewControllers = @[mainVC];
    }
    return self;
}

- (BOOL) showsHelpText{
    return NO;
}

- (BOOL) allowsPanning{
    return YES;
}



- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return self.parent.gameState.lines.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    static NSString *ident = @"line";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:ident];
    if(!cell){
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ident];
    }
    
    Line *line = self.parent.gameState.lines.allValues[indexPath.row];
    cell.textLabel.text = [Line nameForLineColor:line.color];
    cell.textLabel.textColor = [UIColor whiteColor];
    cell.textLabel.shadowColor = [UIColor blackColor];
    cell.textLabel.font = [UIFont fontWithName:@"Helvetica Nueue-Medium" size:12];
    cell.textLabel.shadowOffset = CGSizeMake(0, 1);
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{
    LineColor c = [self.parent.gameState.lines.allKeys[indexPath.row] intValue];
    //Line *line = self.parent->gameState.lines[@(c)];
    cell.backgroundColor = [Line uiColorForLineColor:c];
}


- (IBAction)newLine:(id)sender{
    NSLog(@"New line. nav=%@, vc=%@",navController, newLineViewController);
    [navController pushViewController:newLineViewController animated:YES];
}

- (void) makeNewLineWithColor:(LineColor)color{
    Line *l = [self.parent.gameState addLineWithColor:color];
    
    // The line should get an initial train, buy a new one if we have to.
    Train *trainForThisLine = nil;
    if(self.parent.gameState.unassignedTrains.count){
        trainForThisLine = [self.parent.gameState.unassignedTrains.allValues lastObject];
    }else{
        trainForThisLine = [self.parent.gameState buyNewTrain];
    }
    
    trainForThisLine.line = l;
    [self.parent.gameState.unassignedTrains removeObjectForKey:trainForThisLine.UUID];
    self.parent.gameState.assignedTrains[trainForThisLine.UUID] = trainForThisLine;
}

- (void) editLine:(Line *)l{
    editLineViewController.line = l;
    [navController pushViewController:editLineViewController animated:YES];
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    LineColor c = [self.parent.gameState.lines.allKeys[indexPath.row] intValue];
    Line *line = self.parent.gameState.lines[@(c)];
    [self editLine:line];
    return nil;
}

@end

#pragma mark -

@implementation  NewLineViewController{
    NSMutableArray *lineColorButtons;
    LineColor selectedColor;
}

- (void) viewWillAppear:(BOOL)animated{
    if(lineColorButtons){
        [lineColorButtons makeObjectsPerformSelector:@selector(removeFromSuperview)];
    }
    
    // make the color buttons
    CGFloat xCursor = 5;
    lineColorButtons = [NSMutableArray array];
    for(LineColor c = LineColor_Red; c <= LineColor_Max; c++){
        if([self.parent.parent.gameState.lines objectForKey:@(c)]){
            continue; // we already have this line
        }
        
        UIButton *colorButton = [[UIButton alloc] initWithFrame:CGRectMake(xCursor, 72, 34, 46)];
        colorButton.backgroundColor = [Line uiColorForLineColor:c];
        [colorButton setTitle:@"X" forState:UIControlStateSelected];
        [colorButton addTarget:self action:@selector(colorButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        colorButton.selected = NO;
        colorButton.tag = c;
    
        colorButton.layer.opacity = 1;
        colorButton.layer.borderColor = [[UIColor darkGrayColor] CGColor];
        colorButton.layer.borderWidth = 1;
        colorButton.layer.cornerRadius = 4;
    
        [lineColorButtons addObject:colorButton];
        [self.view addSubview:colorButton];
        
        xCursor += colorButton.frame.size.width + 2;
    }
    
    confirmButton.enabled = NO;
}


- (IBAction)colorButtonPressed:(UIButton *)sender{
    LineColor c = sender.tag;
    selectedColor = c;
    
    for(UIButton *b in lineColorButtons){
        b.selected = (b == sender);
    }
    
    [self confirm:nil];
}
 
- (IBAction)back:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction) confirm:(id)sender{
    [self.parent makeNewLineWithColor:selectedColor];
    [self.parent.tableView reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}

@end

#pragma mark -

@implementation EditLineViewController

- (void) viewWillAppear:(BOOL)animated{
    [self _updateDisplay];
    
}

- (IBAction)back:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

- (void) _updateDisplay{
    NSSet *trainsOnLine = [self.parent.parent.gameState trainsOnLine:self.line];
    
    titleLabel.text = [[Line nameForLineColor:self.line.color] uppercaseString];
    numberOfTrainsLabel.text = [NSString stringWithFormat:@"%d", trainsOnLine.count];
    trainLengthLabel.text = [NSString stringWithFormat:@"%d", self.line.numberOfCars];
    
    float costPerDay = trainsOnLine.count * (GAME_TRAIN_MAINTENENCE_PER_DAY + GAME_TRAIN_CAR_MAINTENENCE_PER_DAY*self.line.numberOfCars);
    costLabel.text = [NSString stringWithFormat:@"%@/hour",FormatCurrency(@(costPerDay/24))];
    [self _setupButtonsForTrainCount:trainsOnLine.count carsCount:self.line.numberOfCars];
}

- (BOOL) _allStationsHaveLongPlatform{
    NSOrderedSet *stations = self.line.stationsServed;
    for(Station *s in stations){
        if(![s.upgrades containsObject:StationUpgrade_LongPlatform]){
            return NO;
        }
    }
    return YES;
}
- (void) _setupButtonsForTrainCount:(int)trains carsCount:(int)cars{
    BOOL canAffordNewTrain = (self.parent.parent.gameState.unassignedTrains.count || (self.parent.parent.gameState.currentCash < GAME_TRAIN_COST));
    
    [trainsPlusMinus setEnabled:(trains > 0) forSegmentAtIndex:0];
    [trainsPlusMinus setEnabled:(canAffordNewTrain || (trains < GAME_MAX_TRAINS_PER_LINE)) forSegmentAtIndex:1];
    
    [carsPlusMinus setEnabled:(cars > 1) forSegmentAtIndex:0];
    [carsPlusMinus setEnabled:(cars < GAME_MAX_CARS_IN_TRAIN) forSegmentAtIndex:1];
}

- (IBAction) changeTrainLength:(UISegmentedControl *)sender{
    int delta = (sender.selectedSegmentIndex == 0) ? -1 : 1;
    int newAmount = self.line.numberOfCars + delta;
    
    if((newAmount > GAME_MAX_TRAIN_LENGTH_WITHOUT_LONG_PLATFORM) && (![self _allStationsHaveLongPlatform])){
        QuickAlert(@"Stations Need Upgrades", ([NSString stringWithFormat:@"To fit trains more than %d cars long, all the stations on this line need to be upgraded.",GAME_MAX_TRAIN_LENGTH_WITHOUT_LONG_PLATFORM]));
        return;
    }
    
    self.line.numberOfCars = newAmount;
    [self _updateDisplay];
}

- (IBAction) changeNumberOfTrains:(UISegmentedControl *)sender{
    GameState *gs = self.parent.parent.gameState;
    if(sender.selectedSegmentIndex == 1){
        // new train
        Train *trainToAdd = nil;
        if(gs.unassignedTrains.count){
            trainToAdd = [gs.unassignedTrains allValues][0];
            NSLog(@"Moved train from unassignedtrains %@",trainToAdd);
        }else{
            trainToAdd = [self.parent.parent.gameState buyNewTrain];
            NSLog(@"Bought new train");
        }
         
        [gs.unassignedTrains removeObjectForKey:trainToAdd.UUID];
        gs.assignedTrains[trainToAdd.UUID] = trainToAdd;

        trainToAdd.currentChunkPosition = 0;
        trainToAdd.state = TrainState_StoppedInStation;
        trainToAdd.line = self.line; // route will be assigned in regenerateAllRoutes
        [self.parent.parent.gameState regenerateAllTrainRoutes];
        if(trainToAdd.currentRoute.routeChunks.count){
            trainToAdd.currentRouteChunk = arc4random_uniform(trainToAdd.currentRoute.routeChunks.count);
        }
        
    }else{
        // get rid of a train
        Train *trainToRemove = nil;
        for(Train *t in gs.assignedTrains.allValues){
            if(t.line == self.line){
                trainToRemove = t;
                break;
            }
        }
        if(trainToRemove){
            gs.unassignedTrains[trainToRemove.UUID] = trainToRemove;
            [gs.assignedTrains removeObjectForKey:trainToRemove.UUID];
        }
        
        [self.parent.parent.gameState regenerateAllTrainRoutes];
    }
    
    [self _updateDisplay];
}

- (IBAction)deleteLine:(id)sender{
    [self.parent.parent.gameState removeLine:self.line];
    [self.parent.tableView reloadData];
    [self.navigationController popViewControllerAnimated:YES];
}

@end
