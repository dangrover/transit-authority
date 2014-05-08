//
//  GameState.h
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//
//

#import <Foundation/Foundation.h>
#import "GameScenario.h"
#import "GameMap.h"
#import "GameConstants.h"
#import "Routes.h"
#import "Passenger.h"
#import "Train.h"
#import "Infastructure.h"
#import "Bond.h"

extern NSString *GameStateNotification_CheckedGoals;
extern NSString *GameStateNotification_AccomplishedGoal;
extern NSString *GameStateNotification_IssuedBond;
extern NSString *GameStateNotification_StationBuilt;
extern NSString *GameStateNotification_HourChanged;
extern NSString *GameStateNotification_TrackUpdated;

@interface GameState : NSObject

- (id) initWithScenario:(GameScenario *)theScenario;

@property(strong, nonatomic, readonly) GameScenario *originalScenario;
@property(strong, nonatomic, readonly) GameLedger *ledger;
@property(strong, nonatomic, readonly) GameMap *map;

@property(assign, nonatomic, readonly) NSTimeInterval currentDate;
@property(assign, nonatomic, readonly) struct tm currentDateComponents;
@property(assign, nonatomic, readonly) float currentCash;

// GAME LOOP
- (void) incrementTime:(int)numberOfTicks;

// STATIONS
@property(strong, nonatomic, readonly) NSDictionary *stations; // station.UUID -> station
- (Station *) buildNewStationAt:(CGPoint)tileCoords;
- (Station *) buildNewStationForPOI:(PointOfInterest *)poi;
- (void) destoryStation:(Station *)theStation; // Destroys the station, along with all its tracks

// POIS
@property(strong, nonatomic, readonly) NSDictionary *poisWithoutStations;
@property(strong, nonatomic, readonly) NSDictionary *stationsByConnectedPOI;

// STATION UPGRADES
- (float) costForUpgrade:(NSString *)upgradeIdentifier forStation:(Station *)station;
- (void) purchaseUpgrade:(NSString *)upgradeIdentifier forStation:(Station *)station;
- (NSArray *) allAvailableUpgrades;

// TRACK SEGMENTS
@property(strong, nonatomic, readonly) NSDictionary *trackSegments; // track.UUID -> track
- (float)trackSegmentCostBetween:(CGPoint)tileA tile:(CGPoint)tileB;
- (TrackSegment *) buildTrackSegmentBetween:(Station *)stationA second:(Station *)stationB;
- (void) removeTrackSegment:(TrackSegment *)theSegment;

// TRAINS
@property(strong, nonatomic) NSMutableDictionary *assignedTrains;
@property(strong, nonatomic) NSMutableDictionary *unassignedTrains;
- (Train *) buyNewTrain;

// LINE
@property(strong, nonatomic, readonly) NSDictionary *lines; // color -> line
- (Line *) addLineWithColor:(LineColor)color;
- (void) removeLine:(Line *)theLine;
- (BOOL) line:(Line *)line canAddSegment:(TrackSegment *)seg; // can we add this segment to a line without making the network invalid?
- (BOOL) line:(Line *)line canRemoveSegment:(TrackSegment *)seg;
- (NSSet *) trainsOnLine:(Line *)l;

// PASSENGERS
- (Passenger *) addPassengerWaitingAtStation:(Station *)origin boundFor:(Station *)dest transfer:(BOOL)isTransfer;

// BONDS
@property(strong, nonatomic, readonly) NSSet *outstandingBonds;
- (BOOL) issueBond:(Bond *)theBond;

// SUBSIDIES
- (CGFloat) recommendedDailySubsidy:(BOOL)federal;
@property(assign, nonatomic) float dailyLocalSubsidy;
@property(assign, nonatomic) float dailyFederalSubsidy;
@property(assign, nonatomic) NSTimeInterval lastLocalLobbyTime;
@property(assign, nonatomic) NSTimeInterval lastFedLobbyTime;

// GOAL STATUS
@property(strong, nonatomic, readonly) NSArray *goalsMet; // array of index paths
- (ScenarioGoal *) easiestUnmetGoal;
- (void) forceGoalEvaluate; // Force the game state to re-evaluate goals on the next loop iter.

// ROUTING FUNCTIONS
- (void) regenerateAllTrainRoutes;
+ (TrainRoute *) routeForLine:(Line *)line;
+ (NSOrderedSet *) terminiForSegments:(NSArray *)segments line:(Line *)theLine;
+ (NSOrderedSet *) terminiForSegments:(NSArray *)segments line:(Line *)theLine ifSegmentWereAddedToLine:(TrackSegment *)prospect;
+ (NSOrderedSet *) terminiForSegments:(NSArray *)segments line:(Line *)theLine ifSegmentWereRemovedFromLine:(TrackSegment *)prospect;

- (PassengerRouteInfo) passengerRouteForDestinationWithoutTurning:(Station *)dest onRoute:(TrainRoute *)route beginningWithChunk:(unsigned)startChunkIndex maxTransfers:(unsigned)maxTransfers;

- (PassengerRouteInfo) passengerRouteInfoForOrigin:(Station *)origin destination:(Station *)dest maxTransfers:(unsigned)maxTransfers;

// STATISTICS
@property(assign, nonatomic, readonly) double proportionOfTripsMadeViaSystem;
@property(assign, nonatomic, readonly) double proportionOfMapServedByStations;
@property(assign, nonatomic, readonly) double proportionOfPopulationServedByStations;

@end