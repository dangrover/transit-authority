//
//  GameState.m
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//
//

#import "GameState.h"
#import "Utilities.h"
#import "NSDate+Helper.h"
#import "HKTMXTiledMap.h"
#import "Utilities.h"
#import "GameLedger.h"
#import "PointOfInterest.h"
#import "NSCoding-Macros.h"

NSString *GameStateNotification_AccomplishedGoal = @"GameStateNotification_AccomplishedGoal";
NSString *GameStateNotification_CheckedGoals = @"GameStateNotification_CheckedGoals";
NSString *GameStateNotification_IssuedBond = @"GameStateNotification_IssuedBond";
NSString *GameStateNotification_HourChanged = @"GameStateNotification_HourChanged";
NSString *GameStateNotification_StationBuilt = @"GameStateNotification_StationBuilt";

#define LEDGER_COALESCE_INTERVAL (SECONDS_PER_HOUR)   // How often to compress ledger entries for efficiency
#define EVALUATE_GOALS_FREQUENCY SECONDS_PER_MINUTE*10 // How often to evaluate the scenario goals
#define LOG_RIDERSHIP_FREQUENCY SECONDS_PER_MINUTE*30  // How often to log ridership numbers to the ledger


typedef struct{
    unsigned reject_trip_no_dest;
    unsigned reject_trip_too_long;
    unsigned reject_decided_to_walk;
    unsigned entered_station;
} TripGenerationTally;

static inline TripGenerationTally TripGenerationTallyCreate(){
    return (TripGenerationTally){0,0,0,0};
}

static inline TripGenerationTally TripGenerationTallyAdd(TripGenerationTally a, TripGenerationTally b){
    return (TripGenerationTally){
        a.reject_trip_no_dest + b.reject_trip_no_dest,
        a.reject_trip_too_long + b.reject_trip_too_long,
        a.reject_decided_to_walk + b.reject_decided_to_walk,
        a.entered_station + b.entered_station};
}


@interface GameState()
@property(strong, readwrite) GameScenario *originalScenario;
@property(strong, readwrite) GameLedger *ledger;
@property(strong, readwrite) GameMap *map;
@property(assign, readwrite) double proportionOfMapServedByStations;
@property(assign, readwrite) double proportionOfPopulationServedByStations;
@property(assign, readwrite) NSTimeInterval currentDate;
@property(assign, readwrite) struct tm currentDateComponents;
@property(assign, readwrite) float currentCash;
@end

@interface Station()
@property(strong, nonatomic, readwrite) PointOfInterest *connectedPOI;
@end

#pragma mark -

@implementation GameState{
    BOOL _regeneratingRoutes;
    unsigned _ticksSinceGeneratingDemand;
    NSMutableArray *_commercialTileDestPool;
    NSMutableArray *_residentialTileDestPool;
    NSMutableArray *_commercialPOIDestPoolByHour; // POIs that residents will make trips to
    NSMutableArray *_residentialPOIDestPoolByHour; // POIs that commercial passengers will make trips to
    
    NSTimeInterval _averageWaitTimeForPassengerDecisionFunction;
    
    NSTimeInterval _lastCoalesce;
    NSTimeInterval _lastBondPayment;
    NSTimeInterval _lastSubsidyPayment;
    NSTimeInterval _lastMaintenencePayment;
    NSTimeInterval _lastLogRidershipNumbers;
    unsigned _tickIncrement; // number of ticks we're incrementing this cycle
    CGPoint _startPoint; // where we pan the camera to start with
    
    NSMutableDictionary *_stationsById;
    NSMutableDictionary *_tracks;
    NSMutableSet *_outstandingBonds;
    NSMutableDictionary *_linesByColor;
    NSMutableDictionary *_poisWithoutStations;
    NSMutableDictionary *_stationsByConnectedPOI;
    
    NSMutableArray *_goalsMet;
    NSTimeInterval _lastGoalEvaluation;
    ScenarioGoal *_easiestUnmetGoal;
    unsigned _lastHour;
}

- (id) initWithScenario:(GameScenario *)theScenario{
    if(self = [super init]){
        self.originalScenario = theScenario;
        self.currentCash = theScenario.startingCash;
        
        time_t startTimestamp = [theScenario.startingDate timeIntervalSince1970];
        self.currentDate = startTimestamp;
        self.currentDateComponents = *gmtime(&startTimestamp);
        
    
        self.map = [[GameMap alloc] initWithMapAtPath:theScenario.tmxMapPath];
        
        self.ledger = [[GameLedger alloc] init];
        
        _ticksSinceGeneratingDemand = 0;
        _lastCoalesce = self.currentDate;
        
        _stationsById = [NSMutableDictionary dictionary];
        _tracks = [NSMutableDictionary dictionary];
        
        self.assignedTrains = [NSMutableDictionary dictionary];
        self.unassignedTrains = [NSMutableDictionary dictionary];
        _linesByColor = [NSMutableDictionary dictionary];
        _outstandingBonds = [NSMutableSet set];
        _goalsMet = [NSMutableArray array];
        
        _poisWithoutStations = [NSMutableDictionary dictionary];
        for(PointOfInterest *p in self.originalScenario.pointsOfInterest){
            _poisWithoutStations[p.identifier] = p;
        }
        _stationsByConnectedPOI = [NSMutableDictionary dictionary];
        
        [self _createTileDestinationIndex];
        
        // You start the game with a line and a free train
        Line *freeLine = [self addLineWithColor:LineColor_Blue];
        Train *freeTrain = [[Train alloc] init];
        freeTrain.line = freeLine;
        self.assignedTrains[freeTrain.UUID] = freeTrain;
        
        // set up subsidies
        self.dailyFederalSubsidy = [self recommendedDailySubsidy:YES];
        self.dailyLocalSubsidy = [self recommendedDailySubsidy:NO];
        self.lastFedLobbyTime = INT_MIN;
        self.lastLocalLobbyTime = INT_MIN;
        
        // Keep track of the cash balance in the ledger any time something happens
        [self addObserver:self forKeyPath:@"currentCash" options:NSKeyValueObservingOptionInitial context:nil];
    }
    
    return self;
}

- (void) dealloc{
    [self removeObserver:self forKeyPath:@"currentCash"];
}

- (void) observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if([keyPath isEqual:@"currentCash"]){
        [self.ledger recordDatum:@(self.currentCash)
                          forKey:GameLedger_Finance_Balance
                          atDate:self.currentDate];
    }
}

#pragma mark -

- (CGPoint) startPosition{
    return _startPoint;
}

- (NSDictionary *) lines{
    return _linesByColor;
}

#pragma mark - Loop

- (void) incrementTime:(int)numberOfTicks{
    @synchronized(self){
        // Update the time
        if((self.currentDateComponents.tm_hour < GAME_END_NIGHT_HOUR) || (self.currentDateComponents.tm_hour > GAME_START_NIGHT_HOUR)){
            _tickIncrement = numberOfTicks*4; // time passes 4x as quickly at night
        }else{
            _tickIncrement = numberOfTicks;
        }
        
        self.currentDate += _tickIncrement*TICK_IN_GAME_SECONDS;
        time_t timestamp = self.currentDate;
        self.currentDateComponents = *gmtime(&timestamp);

        if(self.currentDateComponents.tm_hour != _lastHour){
            [[NSNotificationCenter defaultCenter] postNotificationName:GameStateNotification_HourChanged object:self];
        }
        _lastHour = self.currentDateComponents.tm_hour;
        
        if(_regeneratingRoutes) return;
        
        // MOVE THE TRAINS AROUND
        // Also board, unboard passengers
        [self _runTrains:_tickIncrement];
        
        // GENERATE DEMAND AT STATIONS
        _ticksSinceGeneratingDemand += _tickIncrement;
        if(_ticksSinceGeneratingDemand >= GAME_TICKS_BETWEEN_DEMAND_GENERATION){
            [self _generateDemandAtStations];
            _ticksSinceGeneratingDemand = 0;
        }

        // BOND PAYMENTS
        if((self.currentDate - _lastBondPayment) > BOND_PAYMENT_INTERVAL){
            [self _deductBondPayments];
            _lastBondPayment = self.currentDate;
        }
        
        // SUBSIDY PAYMENTS
        if((self.currentDate - _lastSubsidyPayment) > SUBSIDY_PAYMENT_INTERVAL){
            [self _depositSubsidyPayment];
            _lastSubsidyPayment = self.currentDate;
        }
        
        // TRAIN MAINTENENCE AND OPERATION COSTS
        if((self.currentDate - _lastMaintenencePayment) > GAME_MAINTENENCE_DEDUCTION_INTERVAL){
            [self _deductTrainMaintenence];
            _lastMaintenencePayment = self.currentDate;
        }
        
        // LOG RIDERSHIP NUMBERS
        if((self.currentDate - _lastLogRidershipNumbers) > LOG_RIDERSHIP_FREQUENCY){
            [self _logRidership];
            _lastLogRidershipNumbers = _currentDate;
        }
        
        // EVALUATE SCENARIO GOALS
        if((self.currentDate - _lastGoalEvaluation) > EVALUATE_GOALS_FREQUENCY){
            [self _evaluateGoals];
            _lastGoalEvaluation = _currentDate;
        }
        
        // COALESCE STATS TO SAVE TIME/MEMORY
        if((self.currentDateComponents.tm_min == 0) && ((self.currentDate - _lastCoalesce) > LEDGER_COALESCE_INTERVAL)){
            _lastCoalesce = self.currentDate;
            [self.ledger coalesceGivenTime:self.currentDate];
        }
            
    }
}

- (void) _runTrains:(unsigned)numberOfTicks{
    for(Train *t in self.assignedTrains.allValues){
        //NSLog(@"running train %@",t);
        if(t.currentRoute){
            if(t.state == TrainState_MovingOnTrack){
                if(t.currentChunkPosition < 1){ // advance further on the track
                    
                    RouteChunk *currentChunk = t.currentRoute.routeChunks[t.currentRouteChunk];
                    double chunkTileLength = [currentChunk.trackSegment distanceInTiles];

                    
                    CGFloat closestTrainAheadTileDistance = [self tileDistanceOfClosestTrainAheadOnSegment:t];
                    CGFloat stationTileDistance = (1 - t.currentChunkPosition) * chunkTileLength;
                    
                    // our acceleration and brakes are less effective the longer the train
                    double accelMultiplier = 1.0 - (GAME_ACCEL_MULT_PER_CAR*(double)t.line.numberOfCars);
                    
                    double brakingDistanceInTiles = ((t.speed/(fabs(GAME_TRAIN_BRAKE_ACCELERATION_TPT*accelMultiplier) + GAME_TRAIN_FRICTION))*t.speed) + GAME_TRAIN_DISTANCE_TO_STAY_FROM_STOPPED_TRAIN_AHEAD;
                    double slowdownDistanceInTiles = ((t.speed - GAME_TRAIN_STATION_APPROACH_SPEED_TPT)/(fabs(GAME_TRAIN_BRAKE_ACCELERATION_TPT*accelMultiplier)+GAME_TRAIN_FRICTION))*t.speed;
                    
                    if(closestTrainAheadTileDistance <= brakingDistanceInTiles){
                        if(t.speed > 0){
                            t.acceleration = GAME_TRAIN_BRAKE_ACCELERATION_TPT;
                        }else{
                            t.acceleration = 0;
                        }
                    }else if((t.speed) > 0 && (stationTileDistance <= slowdownDistanceInTiles)){
                        if(t.speed > GAME_TRAIN_STATION_APPROACH_SPEED_TPT){
                            t.acceleration = GAME_TRAIN_BRAKE_ACCELERATION_TPT;
                        }else if (t.speed < GAME_TRAIN_STATION_APPROACH_SPEED_TPT){
                            t.acceleration = GAME_TRAIN_ENGINE_ACCELERATION_TPT;
                        }
                    }
                    else{
                        if((t.speed < GAME_TRAIN_MAX_SPEED_TPT) && ((GAME_TRAIN_MAX_SPEED_TPT - t.speed) > GAME_TRAIN_SPEED_DIFF_THESHOLD)){
                            t.acceleration = GAME_TRAIN_ENGINE_ACCELERATION_TPT;
                        }else{
                            t.acceleration = 0;
                        }
                    }
                    
                    double progressIncrement = numberOfTicks*t.speed / chunkTileLength;
                    t.currentChunkPosition = MIN(1, t.currentChunkPosition + progressIncrement);
                    
                    t.speed = MAX(0,t.speed + (t.acceleration*numberOfTicks*accelMultiplier) - (GAME_TRAIN_FRICTION*numberOfTicks));
                }
                else{
                    // Okay, we're stopped in the next station (but at the end of our current chunk)
                    // Unload passengers who want to get off here.
                    t.currentChunkPosition = 1;
                    t.state = TrainState_StoppedInStation;
                    
                    Station *stationWereStoppedIn = ((RouteChunk *)t.currentRoute.routeChunks[t.currentRouteChunk]).destination;
                    int gettingOff = [self unloadPassengersOnTrain:t atStation:stationWereStoppedIn];
                    //NSLog(@"%d passengers getting off here", gettingOff);
                    t.timeToWait = gettingOff * GAME_PASSENGER_BOARDING_TIME_IN_GAME_SECONDS;
                    
                }
            }
            else if(t.state == TrainState_StoppedInStation){
                // lastStateChange marks when the train stopped
                // timeToWait is the time to unload all passengers
                if(self.currentDate >= (t.lastStateChange + t.timeToWait)){
                    
                    Station *stationWereStoppedIn = ((RouteChunk *)t.currentRoute.routeChunks[t.currentRouteChunk]).destination;
                    t.currentRouteChunk = (t.currentRouteChunk + 1) % t.currentRoute.routeChunks.count;
                    t.currentChunkPosition = 0;
                    t.state = TrainState_FinishedBoarding;
                    t.lastStateChange = self.currentDate;
                    
                    // Board everyone who wants to get on here when all passengers are off.
                    // This is slightly unrealistic as it may take several minutes for passengers to board, and in this time more passengers could have arrived. We ignore them.
                    int boarding = [self boardPassengersOnTrain:t atStation:stationWereStoppedIn];
                    //NSLog(@"%d passengers getting on here", boarding);
                    int onOffloadTime = t.timeToWait + boarding * GAME_PASSENGER_BOARDING_TIME_IN_GAME_SECONDS;
                    t.timeToWait = max(onOffloadTime, GAME_STATION_BOARDING_TIME_IN_GAME_SECONDS);
                    
                    if (t.timeToWait > GAME_STATION_BOARDING_TIME_IN_GAME_SECONDS)
                    {
                        NSLog(@"The regular stop time was not enough to off/onload all passengers so I'm stopping a total of %d game seconds.", t.timeToWait);
                    }
                    
                    [self pruneImpatientPassengersAtStation:stationWereStoppedIn];
                }
            }
            else if(t.state == TrainState_FinishedBoarding){
                // lastStateChange still marks when the train stopped
                // timeToWait is the time to unload and board all passengers,
                // plus extra time if this is still less than the minimum station stopping time
                if(self.currentDate >= (t.lastStateChange + t.timeToWait)){
                    
                    // We've been stopped here long enough to let everyone off and on
                    t.state = TrainState_MovingOnTrack;
                }
            }
        }
    }
}

/// Put passengers in all the stations based on how much demand there ought to be
- (void) _generateDemandAtStations{
    
    // Keep some statistics while we do this.
    unsigned totalTilesCovered = 0;
    unsigned totalPopulationServed = 0;
    
    BOOL alreadyCounted[(int)self.map.map.mapSize.width][(int)self.map.map.mapSize.height];
    memset(alreadyCounted, 0, (int)self.map.map.mapSize.width*(int)self.map.map.mapSize.height * sizeof(BOOL));
    
    _averageWaitTimeForPassengerDecisionFunction = [[self.ledger getAggregate:Stat_Average
                                                                       forKey:GameLedger_TrainWaitTime
                                                           forRollingInterval:SECONDS_PER_HOUR*4
                                                                       ending:self.currentDate
                                                                  interpolate:Interpolation_None] doubleValue];
    
    //NSLog(@"Generating demand. Average wait=%f",_averageWaitTimeForPassengerDecisionFunction);
    
    TripGenerationTally tripsThisCycle = TripGenerationTallyCreate();
    
    for(Station *originStation in _stationsById.allValues){
        CGPoint loc = originStation.tileCoordinate;
        
        TripGenerationTally thisStationTally = TripGenerationTallyCreate();
        
        // FIRST GENERATE DEMAND FROM THE TILES SURROUNDING THE STATION
        for(int x = loc.x - GAME_STATION_WALK_RADIUS_TILES; x < loc.x + (GAME_STATION_WALK_RADIUS_TILES * 2); x++){
            for(int y = loc.y - GAME_STATION_WALK_RADIUS_TILES; y < loc.y + (GAME_STATION_WALK_RADIUS_TILES * 2); y++){
                CGPoint passengerLoc = CGPointMake(x, y);
                float distance = PointDistance(passengerLoc, originStation.tileCoordinate);
                
                if(![self.map tileCoordinateIsInBounds:passengerLoc]){
                    continue; // If this is off the map, skip it.
                }else if(distance > GAME_STATION_CAR_RADIUS_TILES){
                    continue; // Can't get to this station
                }else if(alreadyCounted[x][y]){
                    continue;
                }
                
                BOOL drivingToOrigin = (distance > GAME_STATION_WALK_RADIUS_TILES);
                int resDensity = [self.map residentialDensityAt:passengerLoc];
                int comDensity = [self.map commercialDensityAt:passengerLoc];
                
                // Record that we handled this square
                alreadyCounted[x][y] = YES;
                totalTilesCovered++;
                totalPopulationServed += comDensity + resDensity;
                
                unsigned hour = self.currentDateComponents.tm_hour;
                int resTrips = ceil(resDensity * RES_TILE_ODDS_OF_DEMAND_GEN_BY_HOUR[hour]);
                int comTrips = ceil(comDensity * COM_TILE_ODDS_OF_DEMAND_GEN_BY_HOUR[hour]);
                //NSLog(@"Generating %d res trips (%d density, %f odds) and %d commercial",resTrips,resDensity, RES_TILE_ODDS_OF_DEMAND_GEN_BY_HOUR[hour], comTrips, comDensity, COM_TILE_ODDS_OF_DEMAND_GEN_BY_HOUR[hour]);
                
                // If this is far enough to need to drive to the station, check to see
                // if we have parking. If we don't, only allow demand to be generated here some of the time.
                if(drivingToOrigin){
                    BOOL needsParking = (arc4random_uniform(10) > 2);
                    if(needsParking && ![originStation.upgrades containsObject:StationUpgrade_ParkingLot]){
                        continue;
                    }
                }
                
                TripGenerationTally resTripOutcomes = [self _generateTrips:resTrips
                                                                   ofType:PassengerType_ResToCom
                                                               fromOrigin:passengerLoc
                                                                  station:originStation
                                                          drivingToOrigin:drivingToOrigin];
                TripGenerationTally comTripOutcomes = [self _generateTrips:comTrips
                                                                   ofType:PassengerType_ComToRes
                                                               fromOrigin:passengerLoc
                                                                  station:originStation
                                                          drivingToOrigin:drivingToOrigin];
                
                thisStationTally = TripGenerationTallyAdd(thisStationTally,
                                                          TripGenerationTallyAdd(comTripOutcomes,
                                                                                 resTripOutcomes));
            }
        }
        
        // NEXT, GENERATE DEMAND FROM ANY ASSOCIATED POI FOR THE STATION
        if(originStation.links.count && originStation.connectedPOI){
            PointOfInterest *poi = originStation.connectedPOI;
            if(poi.emitCom){
                unsigned numTrips = floor(poi.emitCom.strength * [poi.emitCom.weightByHour[self.currentDateComponents.tm_hour] floatValue]);
                //NSLog(@"emitting %d ->res trips for the poi %@",numTrips, poi.name);
                TripGenerationTally poiComTripOutcomes = [self _generateTrips:numTrips
                                                                   ofType:PassengerType_ComToRes
                                                               fromOrigin:poi.location
                                                                  station:originStation
                                                          drivingToOrigin:NO];
                
                thisStationTally = TripGenerationTallyAdd(thisStationTally, poiComTripOutcomes);
            }
            
            if(poi.emitRes){
                unsigned numTrips = floor(poi.emitRes.strength * [poi.emitRes.weightByHour[self.currentDateComponents.tm_hour] floatValue]);
                //NSLog(@"emitting %d ->com trips for the poi %@",numTrips, poi.name);
                TripGenerationTally poiComTripOutcomes = [self _generateTrips:numTrips
                                                                       ofType:PassengerType_ResToCom
                                                                   fromOrigin:poi.location
                                                                      station:originStation
                                                              drivingToOrigin:NO];
                
                thisStationTally = TripGenerationTallyAdd(thisStationTally, poiComTripOutcomes);
            }
        }
        
        tripsThisCycle = TripGenerationTallyAdd(tripsThisCycle, thisStationTally);
    }
    
    if(tripsThisCycle.reject_trip_no_dest){
        [self.ledger recordEventWithKey:GameLedger_Reject_NoDestStation
                                  count:tripsThisCycle.reject_trip_no_dest
                                 atDate:self.currentDate];
    }
    
    if(tripsThisCycle.reject_trip_no_dest){
        [self.ledger recordEventWithKey:GameLedger_Reject_NoDestStation
                                  count:tripsThisCycle.reject_trip_no_dest
                                 atDate:self.currentDate];
    }
    
    if(tripsThisCycle.reject_trip_too_long){
        [self.ledger recordEventWithKey:GameLedger_Reject_TooLong
                                  count:tripsThisCycle.reject_trip_too_long
                                 atDate:self.currentDate];
    }
    
    
    
    // TABULATE COVERAGE STATISTICS
    double newPropOfMap = (double)totalTilesCovered / ((self.map.size.width*self.map.size.height));
    double newPropOfPop = (double)totalPopulationServed / (double)self.map.totalPopulation;
    
    if(newPropOfMap != self.proportionOfMapServedByStations){
         [self.ledger recordDatum:@(self.proportionOfMapServedByStations)
                           forKey:GameLedger_MapServedProportion
                           atDate:self.currentDate];
    }
    
    if(newPropOfPop != self.proportionOfPopulationServedByStations){
        [self.ledger recordDatum:@(self.proportionOfPopulationServedByStations)
                          forKey:GameLedger_PopulationServedProportion
                          atDate:self.currentDate];
    }
    
    self.proportionOfMapServedByStations = newPropOfMap;
    self.proportionOfPopulationServedByStations = newPropOfPop;
}

- (TripGenerationTally) _generateTrips:(unsigned)total ofType:(PassengerType)type fromOrigin:(CGPoint)origin station:(Station *)originStation drivingToOrigin:(BOOL)drivingToOrigin{
    
    TripGenerationTally tally = TripGenerationTallyCreate();
    
    NSArray *poiDestPool;
    NSArray *tileDestPool;
    if(type == PassengerType_ComToRes){
        tileDestPool = _residentialTileDestPool;
        poiDestPool = _residentialPOIDestPoolByHour[self.currentDateComponents.tm_hour];
    }else{
        tileDestPool = _commercialTileDestPool;
        poiDestPool = _commercialPOIDestPoolByHour[self.currentDateComponents.tm_hour];
    }
    
    
    unsigned transfersAllowedForTrip = drivingToOrigin ? (GAME_PASSENGER_TRANSFERS_ALLOWED-1) : GAME_PASSENGER_TRANSFERS_ALLOWED;
    
    for(unsigned i = 0; i < total; i++){
        // Decide if we're going with a tile destination or a POI destination
        unsigned allDestsCount = poiDestPool.count + tileDestPool.count;
        unsigned chosenDest = arc4random_uniform(allDestsCount);
        
        Station *chosenDestStation = nil;
        CGPoint finalDestTileCoord;
        if(chosenDest >= tileDestPool.count){
            // We are going to a POI dest with a pre-determined destination station
            chosenDestStation = poiDestPool[chosenDest - tileDestPool.count];
            finalDestTileCoord = chosenDestStation.tileCoordinate;
            
            // make sure we can get there on our current network
            // (even though at this point we know there's a station and it *is* connected)
            PassengerRouteInfo i = [self passengerRouteInfoForOrigin:originStation
                                                         destination:chosenDestStation
                                                        maxTransfers:transfersAllowedForTrip];
            if(!i.routeExists){
                tally.reject_trip_no_dest++; // TODO not quite the right header to tally this under
                continue;
            }
            
            //NSLog(@"Trying to generate demand TO the POI %@",chosenDestStation.connectedPOI);
        }
        else{
            // We are going with a tile dest where we have to decide the station
            finalDestTileCoord = ((NSValue *)[tileDestPool objectAtIndex:chosenDest]).CGPointValue;
            
            
            
            NSArray *stationsNearDest = [self _stationsWithinDistance:GAME_STATION_WALK_RADIUS_TILES
                                                                   of:finalDestTileCoord
                                                            excluding:originStation];
            
            NSArray *possibleDestStations = [self _filterStations:stationsNearDest
                                             toThoseReachableFrom:originStation
                                                        transfers:transfersAllowedForTrip];
        
            if(possibleDestStations.count == 0){
                tally.reject_trip_no_dest++;
                continue;
            }
        
            chosenDestStation = [possibleDestStations randomObject];
        }
        
        
        if(PointDistance(origin, finalDestTileCoord) < GAME_STATION_WALK_RADIUS_TILES){
            tally.reject_decided_to_walk++;
            continue; // skip this, too close, let's just walk.
        }
        
        
        PassengerRouteInfo route = [self passengerRouteInfoForOrigin:originStation
                                                         destination:chosenDestStation
                                                        maxTransfers:GAME_PASSENGER_TRANSFERS_ALLOWED];
        
        NSAssert(route.routeExists, @"route should exist");
        
        NSTimeInterval timeToDriveWholeTrip = [self _expectedTimeForDrivingBetweenPointA:origin pointB:finalDestTileCoord];
        
        NSTimeInterval timeToTakeTransit =   (_averageWaitTimeForPassengerDecisionFunction * (1 + (route.minTransfersNeeded*0.8)))
        + (route.totalTrackCovered/GAME_TRAIN_MAX_SPEED_TPT*TICK_IN_GAME_SECONDS)
        + (route.totalStationsVisited * 5);
        
        // Decide how much longer we're willing to wait for a train than driving
        int whichAllowance = arc4random_uniform(sizeof(GAME_DECISION_TIME_RATIO_ALLOWANCES)/sizeof(float));
        float ratioAllowance = GAME_DECISION_TIME_RATIO_ALLOWANCES[whichAllowance];
        
        if((timeToTakeTransit / timeToDriveWholeTrip) < ratioAllowance){ // Okay it would be quick enough to take the train.
            [self addPassengerWaitingAtStation:originStation
                                      boundFor:chosenDestStation
                                      transfer:NO];
            tally.entered_station++;
        }else{ // It's going to take too long to take transit instead of drive
            //NSLog(@"%@->%@. car=%f, transit=%f, allowance=%0.2fX",NSStringFromCGPoint(originStation.tileCoordinate), NSStringFromCGPoint(dest), timeToDriveWholeTrip, timeToTakeTransit,ratioAllowance);
            tally.reject_trip_too_long++;
        }
    }
    
    return tally;
}

- (void) forceGoalEvaluate{
    _lastGoalEvaluation = 0; // This will make it get hit on the next clock tick. 
}

// Evaluate the goals in the scenario.
- (void) _evaluateGoals{
    NSArray *tiers = self.originalScenario.goalGroups;
    for(unsigned t = 0; t < SCENARIO_GOAL_TIERS; t++){
        for(unsigned g = 0; g < SCENARIO_GOALS_PER_TIER; g++){
            if((t<tiers.count) && (g < ((NSArray *)tiers[t]).count)){
                ScenarioGoal *goal = tiers[t][g];
                GoalEvaluationResult res = [goal evaluateAgainstState:self];
                goal.lastEvaluationResult = res;
                
                if(![_goalsMet containsObject:goal] && res.isMet){// hooray
                    [_goalsMet addObject:goal];
                    _easiestUnmetGoal = nil; // force us to re-evaluate this.
                    [[NSNotificationCenter defaultCenter] postNotificationName:GameStateNotification_AccomplishedGoal
                                                                        object:self
                                                                      userInfo:@{@"goal":goal}];
                }
            }
        }
    }
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GameStateNotification_CheckedGoals object:self];
}

- (ScenarioGoal *) easiestUnmetGoal{
    if(!_easiestUnmetGoal){
        for(unsigned t = 0; t < SCENARIO_GOAL_TIERS; t++){
            for(unsigned g = 0; g < SCENARIO_GOALS_PER_TIER; g++){
                ScenarioGoal *goal = self.originalScenario.goalGroups[t][g];
                if(![self.goalsMet containsObject:goal]){
                    _easiestUnmetGoal = goal;
                    break;
                }
            }
            if(_easiestUnmetGoal) break;
        }
    }
    
    return _easiestUnmetGoal;
}

- (void) _deductTrainMaintenence{
    float totalPaidNow = 0;
    for(Train *t in self.assignedTrains.allValues){
        if(!t.currentRoute) continue; // if the train doesn't have a route yet, don't charge for it
        
        float totalMaintenence = GAME_TRAIN_MAINTENENCE_PER_DAY + (GAME_TRAIN_CAR_MAINTENENCE_PER_DAY*t.line.numberOfCars);
        float forNow = totalMaintenence * ((float)GAME_MAINTENENCE_DEDUCTION_INTERVAL/(float)SECONDS_PER_DAY);
        
        totalPaidNow += forNow;
    }
    
    if(totalPaidNow){
        self.currentCash -= totalPaidNow;
        
        [self.ledger recordDatum:@(totalPaidNow)
                          forKey:GameLedger_Finance_Expense_Maintenence
                          atDate:self.currentDate];
    }
}

- (void) _deductBondPayments{
    NSMutableSet *allPaidOff = [NSMutableSet set];
    for(Bond *b in self.outstandingBonds){
        float toPay = [b paymentForInterval:BOND_PAYMENT_INTERVAL];
        float paid = toPay;
        if(toPay >= b.amountRemaining){
            paid = b.amountRemaining;
            [allPaidOff addObject:b];
        }
        
        self.currentCash -= paid;
        b.amountRemaining -= paid;
        
        [self.ledger recordDatum:@(paid)
                          forKey:GameLedger_Finance_Expense_DebtService
                          atDate:self.currentDate];
    }
    
    [_outstandingBonds minusSet:allPaidOff];
}


- (void) _depositSubsidyPayment{
    float proportion = ((float)SUBSIDY_PAYMENT_INTERVAL/(float)SECONDS_PER_DAY);
    float localAmt = self.dailyLocalSubsidy * proportion;
    float fedAmt = self.dailyFederalSubsidy * proportion;
    float totalAmt = localAmt + fedAmt;
    
    self.currentCash += totalAmt;
    
    [self.ledger recordDatum:@(totalAmt)
                      forKey:GameLedger_Finance_Income_Subsidy
                      atDate:self.currentDate];
}

- (void) _logRidership{
    [self.ledger recordDatum:@(self.proportionOfTripsMadeViaSystem)
                      forKey:GameLedger_TripsMadeOnSystemProportion
                      atDate:self.currentDate];
}

#pragma mark -


- (NSArray *) _filterStations:(NSArray *)possibleStations toThoseReachableFrom:(Station *)origin transfers:(unsigned)allowedTransfers{
    return [possibleStations filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(Station *d, NSDictionary *bindings) {
        PassengerRouteInfo i = [self passengerRouteInfoForOrigin:origin destination:d maxTransfers:allowedTransfers];
        return i.routeExists;
    }]];
}


- (void) _createTileDestinationIndex{
    
    // TILES
    _commercialTileDestPool = [NSMutableArray array];
    _residentialTileDestPool = [NSMutableArray array];
    
    //NSLog(@"Making dest index for %@",NSStringFromCGSize(self.map.size));
    
    // make a density-weighted index of possible destination tiles in each class
    for(unsigned x = 0; x < self.map.size.width; x++){
        for(unsigned y = 0; y < self.map.size.height; y++){
            CGPoint p = CGPointMake(x, y);
            NSValue *pValue = [NSValue valueWithCGPoint:p];
            
            int resDensity = [self.map residentialDensityAt:p];
            for(unsigned i = 1; i <= resDensity; i++){
                [_residentialTileDestPool addObject:pValue];
            }
            
            int comDensity = [self.map commercialDensityAt:p];
            
            //NSLog(@"res dens=%d, comDens=%d",resDensity, comDensity);
            for(unsigned i = 1; i <= comDensity; i++){
                [_commercialTileDestPool addObject:pValue];
            }
        }
    }
    
    
}

- (void) _createPOIDestinationIndex{
    // POIs: We have a pool of POIs that can attract demand. When it happens, we have to double-check
    // that a station has been built for the given POI.
    
    NSMutableArray *newResPOIDestPoolByHour = [NSMutableArray arrayWithCapacity:HOURS_PER_DAY];
    NSMutableArray *newComPOIDestPoolByHour = [NSMutableArray arrayWithCapacity:HOURS_PER_DAY];
    
    for(unsigned h = 0; h < HOURS_PER_DAY; h++){
        NSMutableArray *comForThisHour = [NSMutableArray array];
        NSMutableArray *resForThisHour = [NSMutableArray array];
        
        for(PointOfInterest *poi in self.originalScenario.pointsOfInterest){
            Station *s = _stationsByConnectedPOI[poi.identifier];
            if(!s || !s.links.count) continue; // if we don't have a station, or the station isn't connected, skip it.
            
            if(poi.attractCom){
                unsigned trips = ceil((float)poi.attractCom.strength * [poi.attractCom.weightByHour[h] floatValue]);
                for(unsigned i = 0; i < trips; i++){
                    [comForThisHour addObject:s];
                }
            }
            
            if(poi.attractRes){
                unsigned trips = ceil((float)poi.attractRes.strength * [poi.attractRes.weightByHour[h] floatValue]);
                for(unsigned i = 0; i < trips; i++){
                    [resForThisHour addObject:s];
                }
            }
        }
        
        [newResPOIDestPoolByHour addObject:resForThisHour];
        [newComPOIDestPoolByHour addObject:comForThisHour];
    }
    
    _residentialPOIDestPoolByHour = newResPOIDestPoolByHour;
    _commercialPOIDestPoolByHour = newComPOIDestPoolByHour;
}

- (float) tileDistanceOfClosestTrainAheadOnSegment:(Train *)t{
    RouteChunk *ourChunk = t.currentRoute.routeChunks[t.currentRouteChunk];
    TrackSegment *ourSegment = ourChunk.trackSegment;
    
    float lowestSoFar = INT_MAX;
    Train *lowestTrain = nil;
    for(Train *otherTrain in self.assignedTrains.allValues){
        if(otherTrain.currentRoute){
            RouteChunk *theirChunk = otherTrain.currentRoute.routeChunks[otherTrain.currentRouteChunk];
            TrackSegment *theirSegment = theirChunk.trackSegment;
            if((theirSegment == ourSegment)
               && (theirChunk.backwards == ourChunk.backwards)
               && (otherTrain.currentChunkPosition > t.currentChunkPosition)){
                CGFloat segmentLength = theirSegment.distanceInTiles;
                CGFloat distanceApart = (otherTrain.currentChunkPosition - t.currentChunkPosition) * segmentLength;
                if(distanceApart < lowestSoFar){
                    lowestSoFar = distanceApart;
                    lowestTrain = otherTrain;
                }
            }
        }
    }
    
    if(lowestTrain){
        return MAX(0,lowestSoFar - (lowestTrain.line.numberOfCars * GAME_TRAIN_DISTANCE_NEEDED_PER_CAR));
    }else{
        return lowestSoFar; // we return INT MAX if there's plenty of room to keep going
    }
}


#pragma mark - Tracks

- (NSDictionary *) trackSegments{
    return _tracks;
}

- (float)trackSegmentCostBetween:(CGPoint)tileA tile:(CGPoint)tileB {
    // Calculate the amount of track needed in three dimensions, so tracks between different elevations cost more. Unrealistically, this assumes a straight line.
    // For now we'll say that one unit of elevation (can be 0-3) is the same distance as 5 tiles.
    int elevationA = [self.map elevationAt:tileA] * 5;
    int elevationB = [self.map elevationAt:tileB] * 5;
    
    // Add an extra cost to build a bridge under a track.
    float distanceOverWater = [self.map waterPartBetweenTile:tileA andTile:tileB];
    
    CGFloat distanceInTiles = PointDistance3D(tileA, tileB, elevationA, elevationB);
    return distanceInTiles * GAME_TRACK_COST_PER_TILE + distanceOverWater * GAME_BRIDGE_COST_PER_TILE;
}

- (TrackSegment *) buildTrackSegmentBetween:(Station *)stationA second:(Station *)stationB{
    NSAssert(stationA != stationB, @"Can't link a station to itself");
    NSAssert(!stationA.links[stationB.UUID], @"Already linked");
    NSAssert(!stationB.links[stationA.UUID], @"Already linked");
    
    CGFloat cost = [self trackSegmentCostBetween:stationA.tileCoordinate tile:stationB.tileCoordinate];
    
    TrackSegment *seg = [[TrackSegment alloc] init];
    seg.startStation = stationA;
    seg.endStation = stationB;
    seg.built = self.currentDate;
    
    self.currentCash -= cost;
    
    [self.ledger recordDatum:@(cost)
                      forKey:GameLedger_Finance_Expense_Construction
                      atDate:self.currentDate];
    
    _tracks[seg.UUID] = seg;
    stationA.links[stationB.UUID] = seg;
    stationB.links[stationA.UUID] = seg;
    
    return seg;
}

- (void) removeTrackSegment:(TrackSegment *)theSegment{
    NSAssert(_tracks[theSegment.UUID], @"Can't remove a track we don't have.");
    
    [self willChangeValueForKey:@"tracks"];
    
    @synchronized(self){
        NSArray *linesOnceOnThisTrack = theSegment.lines.allValues;

        for(Line *l in linesOnceOnThisTrack){
            // Remove this segment from the lines' list of segments
            [l removeFromSegment:theSegment];
        }
      
        // Remove the track from its connecting stations' "links"
        NSArray *stationsToDisconnectFrom = @[theSegment.startStation, theSegment.endStation];
        for(Station *s in stationsToDisconnectFrom){
            NSArray *keys = s.links.allKeys;
            for(NSString *key in keys){
                if(s.links[key] == theSegment)[s.links removeObjectForKey:key];
            }
        }
        
        // Remove the track from the main dict
        [_tracks removeObjectForKey:theSegment.UUID];

        // Re-color the lines if needed, move the trains to the new route.
        for(Line *l in linesOnceOnThisTrack){
            [self _recolorLineIfInvalid:l];
        }
        
        [self _moveAllTrainsToCurrentPreferredRoutes];
    }
    
    [self didChangeValueForKey:@"tracks"];
}

// If we've mangled a line so that it is non-contiguous, chop off part of it so that it is
// valid again. Regenerate its preferredRoute too.
- (void) _recolorLineIfInvalid:(Line *)l{
    NSArray *allRemainingSegments = l.segmentsServed;
    NSOrderedSet *terms = [GameState terminiForSegments:allRemainingSegments line:l];
    
    if(l.segmentsServed.count == 0){
        // There aren't even any segments. Nothing to do here.
        l.preferredRoute = nil;
        return;
    }
    else if((terms.count == 0) || (terms.count == 2)){
        // This is actually a valid line. We don't need to recolor.
        // We'll just give it a new route and bail out.
        l.preferredRoute = [GameState routeForLine:l];
        return;
    }
    
    NSAssert((terms.count >= 3), @"Shouldn't be re-arranging this line");
    Station *newOrigin = terms[0];
    Station *newDest = terms[1];
    TrainRoute *newRoute = [GameState _routeForLine:l betweenTermini:[NSOrderedSet orderedSetWithObjects:newOrigin, newDest, nil]];
    
    // Un-color all the segments that didn't make it into our new route.
    NSOrderedSet *segmentsThatWeKept = [newRoute segmentsInRoute];
    for(TrackSegment *seg in allRemainingSegments){
        if(![segmentsThatWeKept containsObject:seg]){
            [l removeFromSegment:seg];
        }
    }
    
    l.preferredRoute = newRoute;
}

#pragma mark - Stations

- (NSDictionary *) stations{
    return _stationsById;
}

- (Station *) buildNewStationAt:(CGPoint)tileCoords{
    Station *station = [[Station alloc] init];
    station.tileCoordinate = tileCoords;
    station.built = self.currentDate;
    
    // One example of use for elevation layer: Make stations more expensive at higher elevations.
    // NSLog(@"Station at elevation %d costs %f", elevation, cost);
    int elevation = [self.map elevationAt:tileCoords];
    float cost = GAME_STATION_COST + elevation * 3000;
    self.currentCash -= cost;
        
    [self willChangeValueForKey:@"stations"];
    [_stationsById setObject:station forKey:station.UUID];
    [self didChangeValueForKey:@"stations"];
    
    [self.ledger recordDatum:@(cost)
                      forKey:GameLedger_Finance_Expense_Construction
                      atDate:self.currentDate];
    
    [self.ledger recordDatum:@(_stationsById.count)
                      forKey:GameLedger_NumberOfStations
                      atDate:self.currentDate];
    
    [[NSNotificationCenter defaultCenter] postNotificationName:GameStateNotification_StationBuilt object:self];
    
    return station;
}

- (Station *) buildNewStationForPOI:(PointOfInterest *)poi{
    [self willChangeValueForKey:@"poisWithoutStations"];
    [self willChangeValueForKey:@"stationsByConnectedPOI"];
    
    Station *s = [self buildNewStationAt:poi.location];
    s.connectedPOI = poi;
    
    [_poisWithoutStations removeObjectForKey:poi.identifier];
    _stationsByConnectedPOI[poi.identifier] = s;
    
    [self _createPOIDestinationIndex];
    
    [self didChangeValueForKey:@"poisWithoutStations"];
    [self didChangeValueForKey:@"stationsByConnectedPOI"];
    
    return s;
}

- (void) destoryStation:(Station *)theStation{
    NSAssert(_stationsById[theStation.UUID], @"we don't seem to have this station");
    
    [self willChangeValueForKey:@"stations"];
    [self willChangeValueForKey:@"tracks"];
    [self willChangeValueForKey:@"poisWithoutStations"];
    [self willChangeValueForKey:@"stationsByConnectedPOI"];
    
    @synchronized(self){
        NSOrderedSet *linesWeServed = theStation.lines;
        
        // destroy the track segments that connect to us.
        for(NSString *key in theStation.links){
            TrackSegment *segToDestroy = theStation.links[key];
            NSArray *segLines = segToDestroy.lines.allValues;
            for(Line *l in segLines){
                [l removeFromSegment:segToDestroy];
            }
            [_tracks removeObjectForKey:segToDestroy.UUID];
        }
        
        // Vaporize all the people waiting inside us
        for(NSString *destID in theStation.passengersByDestination.allKeys){
            NSArray *waiting = theStation.passengersByDestination[destID];
            RecyclePassengers(waiting);
            [theStation.passengersByDestination removeObjectForKey:destID];
        }
        
        // Remove the station from the master list
        [_stationsById removeObjectForKey:theStation.UUID];
        
        
        // If the station had a POI, put the placeholder back so it could be rebuilt
        if(theStation.connectedPOI){
            _poisWithoutStations[theStation.connectedPOI.identifier] = theStation.connectedPOI;
            [_stationsByConnectedPOI removeObjectForKey:theStation.connectedPOI.identifier];
            [self _createPOIDestinationIndex]; // Make sure we're not generating/attracting demand here
        }
        
        // Recolor any invalid lines, and move the trains over
        for(Line *l in linesWeServed){
            [self _recolorLineIfInvalid:l];
        }
        
        [self _moveAllTrainsToCurrentPreferredRoutes];
    }
    
    [self.ledger recordDatum:@(_stationsById.count)
                      forKey:GameLedger_NumberOfStations
                      atDate:self.currentDate];
    
    [self didChangeValueForKey:@"stations"];
    [self didChangeValueForKey:@"tracks"];
    [self didChangeValueForKey:@"poisWithoutStations"];
    [self didChangeValueForKey:@"stationsByConnectedPOI"];
}

#pragma mark - POI

- (NSDictionary *) poisWithoutStations{
    return _poisWithoutStations;
}

- (NSDictionary *) stationsByConnectedPOI{
    return _stationsByConnectedPOI;
}

#pragma mark -

- (NSArray *) _stationsWithinDistance:(float)distanceInTiles of:(CGPoint)thePoint excluding:(Station *)excludedStation{
    CGRect bound = CGRectMake(thePoint.x - distanceInTiles,
                              thePoint.y - distanceInTiles,
                              distanceInTiles*2,
                              distanceInTiles*2);
    
    NSArray *matching = [_stationsById.allValues filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(Station *s, NSDictionary *bindings) {
        return ((s != excludedStation) && CGRectContainsPoint(bound, s.tileCoordinate));
    }]];
    
    return matching;
}

- (NSTimeInterval) _expectedTimeForDrivingBetweenPointA:(CGPoint)pointA pointB:(CGPoint)pointB{
    CGFloat totalTiles = fabsf(pointA.x - pointB.x) + fabsf(pointA.y - pointB.y);
    // TODO take into account water
    NSTimeInterval actualDrivingTime = ceil(totalTiles/(GAME_CAR_AVERAGE_SPEED_TPT*TICK_IN_GAME_SECONDS));
    NSTimeInterval originUnparkTime = GAME_CAR_PARKING_TIME_BASE + (GAME_CAR_PARKING_TIME_PER_DENSITY_UNIT * [self.map totalDensityAt:pointA]);
    NSTimeInterval destParkTime = GAME_CAR_PARKING_TIME_BASE + (GAME_CAR_PARKING_TIME_PER_DENSITY_UNIT * [self.map totalDensityAt:pointB]);
    
    return originUnparkTime + actualDrivingTime + destParkTime;
}

// Recalculate the train paths after making significant changes to the map.
- (void) regenerateAllTrainRoutes{
    if(_regeneratingRoutes) return;
    
    _regeneratingRoutes = YES;

    for(Line *l in _linesByColor.allValues){
        if (l.segmentsServed.count == 0){
            NSLog(@"Not making a train for route with color %d",l.color);
            
            // Remove all the trains and put them in unassigned
            // TODO
            continue;
        }
        
        TrainRoute *newRoute = [GameState routeForLine:l];
        l.preferredRoute = newRoute;
    }
    
    [self _moveAllTrainsToCurrentPreferredRoutes];

    _regeneratingRoutes = NO;
}

// Reset the train locations after making significant changes to the map.
- (void) _moveAllTrainsToCurrentPreferredRoutes{
    [self willChangeValueForKey:@"assignedTrains"];
    
    NSArray *assignedTrainIds = [self.assignedTrains allKeys];
    
    for(NSString *trainID in assignedTrainIds){
        Train *t = _assignedTrains[trainID];
        if(t.line.preferredRoute){
            [self moveTrain:t toRoute:t.line.preferredRoute];
        }else{
            _unassignedTrains[trainID] = t;
            [_assignedTrains removeObjectForKey:trainID];
        }
    }
    
    [self didChangeValueForKey:@"assignedTrains"];
}

- (void) moveTrain:(Train *)train toRoute:(TrainRoute *)newRoute{
    TrainRoute *oldRoute = train.currentRoute;
    unsigned oldChunkIndex = train.currentRouteChunk;
    RouteChunk *oldChunk = train.currentRoute.routeChunks[oldChunkIndex];
    
    if(oldRoute == newRoute) return;
    
    unsigned newChunkIndex = NSNotFound;
    for(unsigned i = 0; i < newRoute.routeChunks.count; i++){
        RouteChunk *newChunk = newRoute.routeChunks[i];
        if((newChunk.origin == oldChunk.origin) && (newChunk.destination == oldChunk.destination)){
            newChunkIndex = i;
            break;
        }
    }
    
    if(newChunkIndex != NSNotFound){
        train.currentRouteChunk = newChunkIndex;
    }else{
        train.currentRouteChunk = 0;
        train.currentChunkPosition = 1;
        train.state = TrainState_StoppedInStation;
    }
    
    train.currentRoute = newRoute;
    train.lastStateChange = self.currentDate;
}

// Construct a train route which visits all of the stations on the line.
+ (TrainRoute *) routeForLine:(Line *)line{
    // Figure out the termini
    //NSOrderedSet *stations = [GameState _stationsServedBySegments:line.segmentsServed];
    NSOrderedSet *termini = [GameState terminiForSegments:line.segmentsServed line:line];
    NSAssert((termini.count == 0) || (termini.count == 2), @"invalid termini");
   
    return [GameState _routeForLine:line betweenTermini:termini];
}

// Construct a train route which visits all of the stations on the line, given the termini.
+ (TrainRoute *) _routeForLine:(Line *)line betweenTermini:(NSOrderedSet *)termini{
    
    TrainRoute *theRoute = [[TrainRoute alloc] init];
    theRoute.line = line;
    
    /// TODO this could obviously be generalized
    
    if(termini.count == 2){
        // Easy, we just follow it from A to B, then back.
        theRoute.isCircular = NO;
        Station *startStation = termini[0];
        Station *turnaroundStation = termini[1];
        
        Station *currentStation = startStation;
        NSMutableArray *linksFollowed = [NSMutableArray array];
        
        while(currentStation != turnaroundStation){
            NSSet *segmentsWithThisLine = [currentStation linksForLine:line];
            TrackSegment *segmentToFollow = nil;
            for(TrackSegment *t in segmentsWithThisLine){
                if(![linksFollowed containsObject:t]){
                    segmentToFollow = t;
                    break;
                }
            }
            NSAssert(segmentToFollow != nil, @"should have found a segment to follow here");
            
            RouteChunk *chunk = [[RouteChunk alloc] init];
            chunk.trackSegment = segmentToFollow;
            if(segmentToFollow.startStation == currentStation){
                chunk.backwards = NO;
                currentStation = segmentToFollow.endStation;
            }else{
                chunk.backwards = YES;
                currentStation = segmentToFollow.startStation;
            }
            [theRoute.routeChunks addObject:chunk];
            [linksFollowed addObject:segmentToFollow];
        }
        
        // okay, let's head back
        for(int i = theRoute.routeChunks.count - 1; i >= 0; i--){
            RouteChunk *chunk = theRoute.routeChunks[i];
            RouteChunk *reversedVersion = [[RouteChunk alloc] init];
            reversedVersion.trackSegment = chunk.trackSegment;
            reversedVersion.backwards = !chunk.backwards;
            [theRoute.routeChunks addObject:reversedVersion];
        }
    }
    else if(termini.count == 0){
        // Circular path. We have to pick a station that's on the line, and try to get back to it.
        // we're just going to go until we can't add any links we haven't visited
        theRoute.isCircular = YES;
        
        Station *startStation = ((TrackSegment *)line.segmentsServed[0]).startStation;
        
        NSMutableSet *linksFollowed = [NSMutableSet set];
        Station *currentStation = startStation;
        do{
            NSSet *segmentsWithThisLine = [currentStation linksForLine:line];
            TrackSegment *segmentToFollow = nil;
            for(TrackSegment *t in segmentsWithThisLine){
                if(![linksFollowed containsObject:t]){
                    segmentToFollow = t;
                    break;
                }
            }
            NSAssert(segmentToFollow != nil, @"should have found a segment to follow here");
            
            RouteChunk *chunk = [[RouteChunk alloc] init];
            chunk.trackSegment = segmentToFollow;
            if(segmentToFollow.startStation == currentStation){
                chunk.backwards = NO;
                currentStation = segmentToFollow.endStation;
            }else{
                chunk.backwards = YES;
                currentStation = segmentToFollow.startStation;
            }
            [theRoute.routeChunks addObject:chunk];
            [linksFollowed addObject:segmentToFollow];
            
        }while(currentStation != startStation);
    }
    
    
    return theRoute;
}

// Given track segments, return all stations connected to them.
+ (NSOrderedSet *) _stationsServedBySegments:(NSArray *)segments{
    NSMutableOrderedSet *stations = [[NSMutableOrderedSet alloc] initWithCapacity:segments.count];
    for(TrackSegment *seg in segments){
        [stations addObject:seg.startStation];
        [stations addObject:seg.endStation];
    }
    return stations;
}

// Given track segments, return the the termini, the stations connected only to one other station on the line.
+ (NSOrderedSet *) terminiForSegments:(NSArray *)segments line:(Line *)theLine{
    NSOrderedSet *stations = [GameState _stationsServedBySegments:segments];
    
    NSMutableOrderedSet *terms = [[NSMutableOrderedSet alloc] init];
    for(Station *s in stations){
        // a station is a terminus for a line if it has only one segment leading out of it
        // which has that line running on it
        int linksWithThisLine = 0;
        for(TrackSegment *seg in [s.links allValues]){
            if(seg.lines[@(theLine.color)]) linksWithThisLine++;
        }
        
        if(linksWithThisLine == 1) [terms addObject:s];
    }
    
    return terms;
}

// Given track segments and a train line, plus one additional segment, return the termini of the new line.
+ (NSOrderedSet *) terminiForSegments:(NSArray *)segments line:(Line *)theLine ifSegmentWereAddedToLine:(TrackSegment *)prospect{
    NSArray *allSegs = [segments arrayByAddingObject:prospect];
    NSOrderedSet *stations = [GameState _stationsServedBySegments:allSegs];
    
    NSMutableOrderedSet *terms = [[NSMutableOrderedSet alloc] init];
    for(Station *s in stations){
        // a station is a terminus for a line if it has only one segment leading out of it
        // which has that line running on it
        int linksWithThisLine = 0;
        NSSet *prospectiveLinks = [NSSet setWithArray:s.links.allValues];
        if((s == prospect.startStation) || (s == prospect.endStation)){
            prospectiveLinks = [prospectiveLinks setByAddingObject:prospect];
        }
        for(TrackSegment *seg in prospectiveLinks){
            if((seg == prospect) || (seg.lines[@(theLine.color)])){
                linksWithThisLine++;
            }
        }
        
        if(linksWithThisLine == 1) [terms addObject:s];
    }
    
    return terms;
}

// Given track segments and a train line, minus one segment to exclude, return the termini of the new line.
+ (NSOrderedSet *) terminiForSegments:(NSArray *)segments line:(Line *)theLine ifSegmentWereRemovedFromLine:(TrackSegment *)prospect{
    NSMutableArray *newSegs = [NSMutableArray arrayWithArray:segments];
    [newSegs removeObject:prospect];
    NSOrderedSet *stations = [GameState _stationsServedBySegments:newSegs];
    
    NSMutableOrderedSet *terms = [[NSMutableOrderedSet alloc] init];
    for(Station *s in stations){
        int linksWithThisLine = 0;
        for(TrackSegment *seg in [s.links allValues]){
            if(seg.lines[@(theLine.color)] && (seg!= prospect)) linksWithThisLine++;
        }
        
        if(linksWithThisLine == 1) [terms addObject:s];
    }
    
    return terms;
}

// When adding segments to lines, enforce the constraint that lines must have two or zero termini.
- (BOOL) line:(Line *)line canAddSegment:(TrackSegment *)seg{
    NSOrderedSet *wouldBeTermini = [GameState terminiForSegments:line.segmentsServed line:line ifSegmentWereAddedToLine:seg];
    return ((wouldBeTermini.count == 2) || (wouldBeTermini.count == 0));
}

// When removing segments from lines, enforce the constraint that lines must have two or zero termini.
- (BOOL) line:(Line *)line canRemoveSegment:(TrackSegment *)seg{
    NSOrderedSet *wouldBeTermini = [GameState terminiForSegments:line.segmentsServed line:line ifSegmentWereRemovedFromLine:seg];
    return ((wouldBeTermini.count == 2) || (wouldBeTermini.count == 0));
}

// Construct a route from point A to point B using all the lines available, transferring if necessary.
- (PassengerRouteInfo) passengerRouteInfoForOrigin:(Station *)origin destination:(Station *)dest maxTransfers:(unsigned)maxTransfers{
    NSAssert(origin != nil, @"origin should not be nil");
    NSAssert(origin != nil, @"destination should not be nil");
    
    // First, we'll check to see if they are on the same line.
    // If so, it's a straight shot with no transfers.
    Line *bestLineForStraightShot = nil;
    PassengerRouteInfo bestStraightShot;
    bestStraightShot.routeExists = NO;
    
    for(Line *l in origin.lines){
        if([dest.lines containsObject:l]){
            PassengerRouteInfo routeForThisLine = [l.preferredRoute passengerRouteFromStationA:origin toStationB:dest];
            NSAssert(l.preferredRoute, @"line should have a route");
            NSAssert(routeForThisLine.routeExists, @"should be able to reach a station on the same line");
            
            if(!bestLineForStraightShot || (routeForThisLine.totalStationsVisited < bestStraightShot.totalStationsVisited)){
                bestLineForStraightShot = l;
                bestStraightShot = routeForThisLine;
            }
        }
    }
    if(bestLineForStraightShot){
        return bestStraightShot;
    }
    
    
    // Otherwise, let's see if we can get there by transferring.
    PassengerRouteInfo info; // this will be our best route
    info.routeExists = NO;
    BOOL foundATransfer = NO;
    
    if(maxTransfers > 0){
        //NSLog(@"Looking at transfer options to get from %@->%@",origin, dest);
        // See if we can get there by taking any of the lines from origin and transferring
        NSOrderedSet *originLines = [origin lines];
        for(Line *l in originLines){
            NSOrderedSet *stations = l.stationsServed;
            for(Station *s in stations){
                if(s == origin) continue;
                
                PassengerRouteInfo routeFromProspectiveTransfer = [self passengerRouteInfoForOrigin:s destination:dest maxTransfers:maxTransfers - 1];
                
                if(!routeFromProspectiveTransfer.routeExists) continue;
                
                PassengerRouteInfo routeToTransfer = [l.preferredRoute passengerRouteFromStationA:origin toStationB:s];
                unsigned totalStationsIfWeTransferredHere = routeFromProspectiveTransfer.totalStationsVisited + routeToTransfer.totalStationsVisited - 1;
                
                // If this is the first transfer route we've looked at, OR it's better than the
                // others we've considered, let's use this one.
                if(!foundATransfer || (((routeFromProspectiveTransfer.minTransfersNeeded + 1) <= info.minTransfersNeeded)
                                       && (totalStationsIfWeTransferredHere <= info.totalStationsVisited))){
                    
                    
                    info.routeExists = YES;
                    info.minTransfersNeeded = routeFromProspectiveTransfer.minTransfersNeeded + 1;
                    
                    
                    info.totalTrackCovered = routeFromProspectiveTransfer.totalTrackCovered + routeToTransfer.totalTrackCovered;
                    info.totalStationsVisited = totalStationsIfWeTransferredHere;
                    
                    //NSLog(@"transfer total stations = %d to get to transfer (%@) + %d thereafter (%@->%@), maxtransfers=%d",routeToTransfer.totalStationsVisited,s,routeFromProspectiveTransfer.totalStationsVisited, s, dest, maxTransfers);
                    foundATransfer = YES;
                }
            }
      
        }
    }
    
    if(!foundATransfer){ // Otherwise, we're stuck. There is no route.
        info.routeExists = NO;
    }
    
    return info;
}

// Construct a route from a chunk on a train route to a destination station.
- (PassengerRouteInfo) passengerRouteForDestinationWithoutTurning:(Station *)dest onRoute:(TrainRoute *)route beginningWithChunk:(unsigned)startChunkIndex maxTransfers:(unsigned)maxTransfers{
    
    Station *firstStationWeCanConsider = ((RouteChunk *)route.routeChunks[startChunkIndex]).origin;
    
    if(route.isCircular){
        PassengerRouteInfo circleInfo = [route passengerRouteFromStationA:firstStationWeCanConsider toStationB:dest];
        return circleInfo;
    }
    
    // can we get to the destination moving in our current direction without getting to a line terminus first?
    NSOrderedSet *termini = [GameState terminiForSegments:route.line.segmentsServed line:route.line];
    
    PassengerRouteInfo notFound;
    notFound.routeExists = NO;
 
    PassengerRouteInfo transferRoute;
    transferRoute.routeExists = NO;
    transferRoute.minTransfersNeeded = 0;
    unsigned currentChunk = startChunkIndex;
    while(1){
        RouteChunk *chunk = route.routeChunks[currentChunk];
        if([chunk.destination isEqual:dest] || [chunk.origin isEqual:dest]){
            return [route passengerRouteFromStationA:chunk.origin toStationB:dest];
        }
        
        if(maxTransfers > 0){
            PassengerRouteInfo fromHere = [self passengerRouteInfoForOrigin:chunk.destination destination:dest maxTransfers:maxTransfers - 1];
            if(fromHere.routeExists){
                transferRoute = fromHere;
                transferRoute.minTransfersNeeded++;
            }
        }
        
        // They don't want to get off at this dest, and it's a termini.
        // So no, we've reached the end of the line (unless they could have transferred)
        if([termini containsObject:chunk.destination]){
            if(transferRoute.routeExists){
                return transferRoute;
            }else{ // Nope, we hit the end, and we didn't even find a way to transfer
                return notFound;
            }
        }
        
        // Next chunk
        currentChunk = (currentChunk + 1) % route.routeChunks.count;
    }
    
    return notFound;
}

- (Train *) buyNewTrain{
    Train *t = [[Train alloc] init];
    self.unassignedTrains[t.UUID] = t;
    self.currentCash -= GAME_TRAIN_COST;
    
    [self.ledger recordDatum:@(GAME_TRAIN_COST)
                      forKey:GameLedger_Finance_Expense_Trains
                      atDate:self.currentDate];
    
    [self.ledger recordDatum:@(self.assignedTrains.count)
                      forKey:GameLedger_NumberOfRunningTrains
                      atDate:self.currentDate];
    
    return t;
}


- (Line *) addLineWithColor:(LineColor)color{
    if(!_linesByColor[@(color)]){
        _linesByColor[@(color)] = [[Line alloc] initWithColor:color];
    }
    
    NSAssert(_linesByColor[@(color)], @"should have added line");
    return _linesByColor[@(color)];
}

- (void) removeLine:(Line *)theLine{
    // go around and remove it from all the tracks.
    for(TrackSegment *seg in _tracks.allValues){
        [seg.lines removeObjectForKey:@(theLine.color)];
    }
    
    // move all the trains
    NSArray *allAssignedTrains = [NSArray arrayWithArray:_assignedTrains.allValues];
    for(Train *t in allAssignedTrains){
        [_assignedTrains removeObjectForKey:t.UUID];
        _unassignedTrains[t.UUID] = t;
        t.line = nil;
        t.currentRoute = nil;
    }
 
    // remove the line itself
    [_linesByColor removeObjectForKey:@(theLine.color)];
    
    [self regenerateAllTrainRoutes];
}

- (NSSet *) trainsOnLine:(Line *)l{
    NSMutableSet *s = [NSMutableSet set];
    for(Train *t in self.assignedTrains.allValues){
        if(t.line == l){
            [s addObject:t];
        }
    }
    
    return s;
}


- (void) boardPassengersOnTrain:(Train *)t atStation:(Station *)origin boundFor:(Station *)dest{
    [origin willChangeValueForKey:@"totalPassengersWaiting"];
    [t willChangeValueForKey:@"totalPassengersOnBoard"];
    
    NSArray *peopleWhoWantToBoard = ((NSArray *)origin.passengersByDestination[dest.UUID]);
    int remainingCapacity = t.capacity - [t totalPassengersOnBoard];
    
    if(!t.passengersByDestination[dest.UUID]){
        t.passengersByDestination[dest.UUID] = [NSMutableArray array];
    }
    
    NSArray *willBoard = nil;
    if(peopleWhoWantToBoard.count <= remainingCapacity){
        willBoard = peopleWhoWantToBoard;
    }else{
        willBoard = [peopleWhoWantToBoard objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, remainingCapacity)]];
    }
    
    for(Passenger *p in willBoard){
        if(p.transfersMade == 0){
            p.boardedTrainTime = self.currentDate;
            double waitSec = (p.boardedTrainTime - p.enteredStationTime);
            [self.ledger recordDatum:@(waitSec)
                              forKey:GameLedger_TrainWaitTime
                              atDate:self.currentDate];
            
        }
    }
    
    [t.passengersByDestination[dest.UUID] addObjectsFromArray:willBoard];
    [origin.passengersByDestination[dest.UUID] removeObjectsInArray:willBoard];
    
    [origin didChangeValueForKey:@"totalPassengersWaiting"];
    [t didChangeValueForKey:@"totalPassengersOnBoard"];
}

- (int)unloadPassengersOnTrain:(Train *)t atStation:(Station *)stationWereStoppedIn
{
    [stationWereStoppedIn willChangeValueForKey:@"totalPassengersWaiting"];
    [t willChangeValueForKey:@"totalPassengersOnBoard"];
    
    // Now we have to let people off who have this station as their final dest.
    NSArray *peopleGettingOffHere = t.passengersByDestination[stationWereStoppedIn.UUID];
    if(peopleGettingOffHere.count){
        
        // take their fare as they exit
        float fareRecieved = GAME_DEFAULT_FARE * peopleGettingOffHere.count;
        self.currentCash += fareRecieved;
        [self.ledger recordDatum:@(fareRecieved)
                          forKey:GameLedger_Finance_Income_Fare
                          atDate:self.currentDate];
        
        //NSLog(@"%d people got off",peopleGettingOffHere.count);
        RecyclePassengers(peopleGettingOffHere);
        t.passengersByDestination[stationWereStoppedIn.UUID] = [NSMutableArray array];
    }
    
    NSOrderedSet *terms = [GameState terminiForSegments:t.currentRoute.line.segmentsServed line:t.currentRoute.line];
    if([terms containsObject:stationWereStoppedIn] && (t.totalPassengersOnBoard > 0)){
        NSLog(@"We are at a termini and there are %d people on board, even though we let everyone off",t.totalPassengersOnBoard);
    }
    
    // Let off any people who are gonna transfer at this station (if we have multiple lines)
    NSMutableArray *transferringHere = [NSMutableArray array];
    if(stationWereStoppedIn.lines.count > 1){
        NSArray *destIDs = t.passengersByDestination.allKeys;
        int considering = 0;
        int alreadyTransferedCount = 0;
        for(NSString *destUUID in destIDs){
            Station *destStation = _stationsById[destUUID];
            
            // If there are passengers going somewhere that isn't served by this route,
            // but *can* be reached via a transfer at this station, have them get off
            // and transfer here.
            
            if(![t.passengersByDestination[destUUID] count]){
                continue;
            }
            
            // Figure out what the passenger's route to their final destination would be
            // if A) they stayed on the train, and B) they got off here.
            // Compare the two and see which one is better.
            
            PassengerRouteInfo routeInfoForStayingOnTrain = [self passengerRouteForDestinationWithoutTurning:destStation onRoute:t.currentRoute beginningWithChunk:t.currentRouteChunk maxTransfers:0];
            
            if(routeInfoForStayingOnTrain.routeExists){
                // If the current train will take them to their destination
                // without a transfer, stay on the train!
                continue;
            }
            
            PassengerRouteInfo routeInfoForTransferHere = [self passengerRouteInfoForOrigin:stationWereStoppedIn
                                                                                destination:destStation
                                                                               maxTransfers:GAME_PASSENGER_TRANSFERS_ALLOWED];
            
            if(routeInfoForTransferHere.routeExists){
                NSArray *passengersWhoCouldGetOffToTransferHere = [t.passengersByDestination[destUUID] allObjects];
                
                for(Passenger *p in passengersWhoCouldGetOffToTransferHere){
                    considering++;
                    if(routeInfoForTransferHere.minTransfersNeeded <= (GAME_PASSENGER_TRANSFERS_ALLOWED - p.transfersMade)){
                        [transferringHere addObject:p];
                        [t.passengersByDestination[destUUID] removeObject:p];
                        [self addPassengerWaitingAtStation:stationWereStoppedIn boundFor:destStation transfer:YES];
                    }else{
                        //     NSLog(@"can't transfer here, already made %d/%d transfers, and the route would require %d",p.transfersMade, GAME_PASSENGER_TRANSFERS_ALLOWED, routeInfoForTransferHere.minTransfersNeeded);
                        alreadyTransferedCount++;
                    }
                }
            }
            
        }
        
        //NSLog(@"Transferring %d/%d. (%d already transferred)",transferringHere.count,considering, alreadyTransferedCount);
        RecyclePassengers(transferringHere);
    }
    
    [stationWereStoppedIn didChangeValueForKey:@"totalPassengersWaiting"];
    [t didChangeValueForKey:@"totalPassengersOnBoard"];
    
    return peopleGettingOffHere.count + transferringHere.count;
}

- (int)boardPassengersOnTrain:(Train *)t atStation:(Station *)stationWereStoppedIn
{
    int totalBoarding = 0;
    NSArray *byDest = [stationWereStoppedIn.passengersByDestination allKeys];
    for(NSString *destStationUUID in byDest){
        Station *destStation = _stationsById[destStationUUID];
        if(!destStation) continue; // Station no longer exists.
        
        if(destStation == stationWereStoppedIn) continue;
        if(((NSArray *)stationWereStoppedIn.passengersByDestination[destStationUUID]).count == 0) continue;
        
        unsigned transfersNeeded = 0;
        
        NSAssert(t.currentRoute, @"train should have a route");
        
        
        PassengerRouteInfo routeInfoForTakingThisTrain = [self passengerRouteForDestinationWithoutTurning:destStation onRoute:t.currentRoute beginningWithChunk:t.currentRouteChunk maxTransfers:GAME_PASSENGER_TRANSFERS_ALLOWED];
        
        PassengerRouteInfo routeInfoForThisStation = [self passengerRouteInfoForOrigin:stationWereStoppedIn destination:destStation maxTransfers:GAME_PASSENGER_TRANSFERS_ALLOWED];
        
        // They might be waiting because the route was changed since they got in there
        // NSAssert(routeInfoForThisStation.routeExists, @"should not wait in a station where no route exists");
        
        // Let's consider getting on this train
        
        // If this train would require a transfer, but we know there are non-transfer routes from this station,
        // reject it.
        
        if((routeInfoForThisStation.minTransfersNeeded < routeInfoForTakingThisTrain.minTransfersNeeded)){
            //NSLog(@"REJECTING A TRAIN FOR A MORE DIRECT ROUTE");
            continue;
        }else{
            int capacityLeftOnTrain = t.capacity - t.totalPassengersOnBoard;
            int peopleWhoWantToGetOn = [stationWereStoppedIn.passengersByDestination[destStationUUID] count];
            int peopleAbleToGetOn = MIN(capacityLeftOnTrain, peopleWhoWantToGetOn);
            totalBoarding += peopleAbleToGetOn;
            
            [self.ledger recordEventWithKey:GameLedger_BoardTrain
                                      count:peopleAbleToGetOn
                                     atDate:self.currentDate];
            
            if(transfersNeeded){
                NSLog(@"Boarding passengers %d on a train that they will have to transfer off of %d times",peopleAbleToGetOn, transfersNeeded);
            }
            
            [self boardPassengersOnTrain:t
                               atStation:stationWereStoppedIn
                                boundFor:destStation];
        }
    }
    return totalBoarding;
}

- (void)pruneImpatientPassengersAtStation:(Station *)stationWereStoppedIn
{
    // Now let's prune the passengers who didn't get on this train and have been waiting too long
    [stationWereStoppedIn willChangeValueForKey:@"totalPassengersWaiting"];
    unsigned totalGiveUpWaitings = 0;
    for(NSString *destUUID in stationWereStoppedIn.passengersByDestination.allKeys){
        NSMutableArray *passengers = stationWereStoppedIn.passengersByDestination[destUUID];
        NSMutableArray *toRemove = [NSMutableArray array];
        for(Passenger *p in passengers){
            if((self.currentDate - p.enteredStationTime) > GAME_PASSENGER_MAX_WAIT){
                [toRemove addObject:p];
            }
        }
        
        if(toRemove.count){
            totalGiveUpWaitings += toRemove.count;
            [passengers removeObjectsInArray:toRemove];
            //NSLog(@"%d passengers gave up", toRemove.count);
            RecyclePassengers(toRemove);
        }
    }
    if(totalGiveUpWaitings){
        [self.ledger recordDatum:@(GAME_PASSENGER_MAX_WAIT)
                          forKey:GameLedger_TrainWaitTime
                           count:totalGiveUpWaitings
                          atDate:self.currentDate];
        
        [self.ledger recordEventWithKey:GameLedger_Reject_GiveUp
                                  count:totalGiveUpWaitings
                                 atDate:self.currentDate];
    }
    [stationWereStoppedIn didChangeValueForKey:@"totalPassengersWaiting"];
}

- (Passenger *) addPassengerWaitingAtStation:(Station *)origin boundFor:(Station *)dest transfer:(BOOL)isTransfer{
    [origin willChangeValueForKey:@"totalPassengersWaiting"];
    
    Passenger *p = GetNewPassenger();
    p.finalDestination = dest;
    
    if(!origin.passengersByDestination[dest.UUID]){
        origin.passengersByDestination[dest.UUID] = [NSMutableArray arrayWithObject:p];
    }else{
        [origin.passengersByDestination[dest.UUID] addObject:p];
    }
    
    if(isTransfer){
        p.transfersMade += 1;
        [self.ledger recordEventWithKey:GameLedger_Transfer count:1 atDate:self.currentDate];
    }else{
        p.transfersMade = 0;
    }
    
    p.enteredStationTime = self.currentDate;
    p.origin = origin;
    
    [origin didChangeValueForKey:@"totalPassengersWaiting"];
    
    return p;
}

- (double) proportionOfTripsMadeViaSystem{
    double totalBoardings = [[self.ledger getAggregate:Stat_Count
                                                forKey:GameLedger_BoardTrain
                                    forRollingInterval:SECONDS_PER_HOUR*HOURS_PER_DAY
                                                ending:self.currentDate
                                           interpolate:Interpolation_None] doubleValue];
    
    double totalRejects = [[self.ledger getAggregate:Stat_Count
                                              forKey:GameLedger_Prefix_Reject
                                  forRollingInterval:SECONDS_PER_HOUR*HOURS_PER_DAY
                                              ending:self.currentDate
                                         interpolate:Interpolation_None] doubleValue];
    
    double proportionOfDebatedTripsMadeOnSystem =  totalBoardings / (totalBoardings + totalRejects);
    if(isnan(proportionOfDebatedTripsMadeOnSystem)) proportionOfDebatedTripsMadeOnSystem = 0;
    
    //NSLog(@"calculating system trips. boardings=%f, rejects=%f, pop=%f. FINAL=%f",totalBoardings, totalRejects, self.proportionOfPopulationServedByStations,proportionOfDebatedTripsMadeOnSystem * self.proportionOfPopulationServedByStations);
    return proportionOfDebatedTripsMadeOnSystem * self.proportionOfPopulationServedByStations;
}

#pragma mark - Bonds

- (BOOL) issueBond:(Bond *)theBond{
    self.currentCash += theBond.principal;
    theBond.dateIssued = self.currentDate;
    theBond.amountRemaining = theBond.originalTotal;
    [_outstandingBonds addObject:theBond];
    [[NSNotificationCenter defaultCenter] postNotificationName:GameStateNotification_IssuedBond object:self];
    return YES;
}

#pragma mark - Subsidies


- (CGFloat) recommendedDailySubsidy:(BOOL)federal{
    int numTrains = self.assignedTrains.count;
    int numStations = self.stations.count;
    double propPopServed = self.proportionOfMapServedByStations;
    double propTripsMade = self.proportionOfTripsMadeViaSystem;
    double avgWait = [[self.ledger getAggregate:Stat_Average forKey:GameLedger_TrainWaitTime forRollingInterval:SECONDS_PER_DAY * 2 ending:self.currentDate interpolate:Interpolation_None] doubleValue];
    
    float maximum;
    if(federal){
        maximum = (numStations * 300) + (numTrains * GAME_TRAIN_MAINTENENCE_PER_DAY * 0.5) + 2000;
    }else{
        maximum = (numStations * 100) + (numTrains * GAME_TRAIN_MAINTENENCE_PER_DAY * 1.5) + 3000;
    }
    
    double waitPenalty = 0;
    if(avgWait > 12*SECONDS_PER_MINUTE){
        waitPenalty = MIN(1, (avgWait - (12 * SECONDS_PER_MINUTE)) / (12 * SECONDS_PER_MINUTE));
    }
    
    double systemScore = MIN(1, (propTripsMade + 0.02) / 0.2); // 20% is pretty good
    double popScore = MIN(1, (propPopServed + 0.05));
    double randomScore = (double)arc4random() / ARC4RANDOM_MAX;
    
    double totalScore = (popScore*0.4) + (systemScore * 0.45) + (randomScore * 0.05);
    totalScore *= (1.0 - waitPenalty*0.4);
    
    NSLog(@"max=%f, system score = %f, pop score = %f, random = %f, wait penalty = %f",maximum,systemScore,popScore,randomScore, waitPenalty);
    
    return maximum*totalScore;
}

#pragma mark - Upgrades


- (float) costForUpgrade:(NSString *)upgradeIdentifier forStation:(Station *)station{
    if([upgradeIdentifier isEqualToString:StationUpgrade_ParkingLot]){
        int totalDensity = 0;
        for(unsigned x = station.tileCoordinate.x - GAME_STATION_CAR_RADIUS_TILES;
            x < station.tileCoordinate.x + (GAME_STATION_CAR_RADIUS_TILES*2);
            x++){
            for(unsigned y = station.tileCoordinate.y - GAME_STATION_CAR_RADIUS_TILES;
                y < station.tileCoordinate.y + (GAME_STATION_CAR_RADIUS_TILES*2);
                y++){
                CGPoint p = CGPointMake(x, y);
                float distance = PointDistance(p, station.tileCoordinate);
                if(distance <= GAME_STATION_WALK_RADIUS_TILES){
                    int r = [self.map residentialDensityAt:p];
                    int c = [self.map residentialDensityAt:p];
                    
                    // Give them a break if it's only 1 density unit here.
                    if(r > 1) totalDensity += r;
                    if(c > 1) totalDensity += c;
                }
            }
        }
        
        return MAX(GAME_UPGRADE_PARKING_MIN_COST,
                   GAME_UPGRADE_PARKING_COST_PER_DENSITY_UNIT_IN_RADIUS*totalDensity);
    }
    else if([upgradeIdentifier isEqual:StationUpgrade_LongPlatform]){
        return GAME_UPRGRADE_LONG_PLATFORM_COST;
    }
    else if([upgradeIdentifier isEqual:StationUpgrade_Accessible]){
        return GAME_UPGRADE_ACCESSIBLE_COST;
    }
    
    return 0;
}

- (void) purchaseUpgrade:(NSString *)upgradeIdentifier forStation:(Station *)station{
    float cost = [self costForUpgrade:upgradeIdentifier forStation:station];
    [station addUpgrade:upgradeIdentifier];
    
    self.currentCash -= cost;
    
    [self.ledger recordDatum:@(cost)
                      forKey:GameLedger_Finance_Expense_Construction
                      atDate:self.currentDate];
    
}

- (NSArray *) allAvailableUpgrades{
    return @[StationUpgrade_ParkingLot, StationUpgrade_LongPlatform, StationUpgrade_Accessible];
}

#pragma mark - Serialization

- (void)encodeWithCoder:(NSCoder *)encoder {
    encodeObject(_originalScenario);
    //encodeObject(_ledger);
    //encodeObject(_map);
    
    encodeDouble(_currentDate);
    encodeInt(_currentDateComponents.tm_hour);
    encodeInt(_currentDateComponents.tm_min);
    encodeFloat(_currentCash);
    
    encodeFloat(_dailyLocalSubsidy);
    encodeFloat(_dailyFederalSubsidy);
    encodeDouble(_lastLocalLobbyTime);
    encodeDouble(_lastFedLobbyTime);
}

- (id)initWithCoder:(NSCoder *)decoder {
    NSLog(@"Decoding Scenario");
    decodeObject(_originalScenario);
    //_originalScenario = [[GameScenario alloc] initWithJSON:[[NSBundle mainBundle] pathForResource:@"boston" ofType:@"json"]];
    NSLog(@"Scenario decoded: %@", _originalScenario);
    if (self = [self initWithScenario:_originalScenario])
    {
        // _map is initialized already.
        NSLog(@"Game State initialized");
        
        // We can work on the ledger later.
        //decodeObject(_ledger);
        
        decodeDouble(_currentDate);
        //decodeInt(_currentDateComponents.tm_hour);
        //decodeInt(_currentDateComponents.tm_min);
        decodeFloat(_currentCash);
        
        decodeFloat(_dailyLocalSubsidy);
        decodeFloat(_dailyFederalSubsidy);
        decodeDouble(_lastLocalLobbyTime);
        decodeDouble(_lastFedLobbyTime);

        return self;
    }
    return nil;
}

@end

