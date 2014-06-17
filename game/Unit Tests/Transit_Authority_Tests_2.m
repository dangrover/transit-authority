//
//  TransitAuthorityTests.m
//  TransitAuthorityTests
//
//  Created by Dan Grover on 6/20/13.
//
//

#import <XCTest/XCTest.h>

#import "GameState.h"
#import "CCDirector.h"
#import "CCDirectorIOS.h"
#import "CCGLView.h"
#import "GameLedger.h"

@interface TransitAuthorityTests : XCTestCase

@end

@implementation TransitAuthorityTests{
    CCDirectorIOS *dir;
    CCGLView *glView;
}

- (void)setUp
{
  /*
    // We have to set up a context and everything just to get
    // Cocos2D to shut up and let us run tests.
	glView = [CCGLView viewWithFrame:CGRectZero
                         pixelFormat:kEAGLColorFormatRGB565	//kEAGLColorFormatRGBA8
                         depthFormat:0	//GL_DEPTH_COMPONENT24_OES
                  preserveBackbuffer:NO
                          sharegroup:nil
                       multiSampling:NO
                     numberOfSamples:0];
    
	dir = (CCDirectorIOS*) [CCDirector sharedDirector];
	[dir setDisplayStats:NO]; // Display FSP and SPF
    [dir setProjection:kCCDirectorProjection2D];
    [dir setAnimationInterval:1.0/60];
	[dir setView:glView]; // attach the openglView to the director
   */
	
}

- (void)tearDown
{
    // Tear-down code here.
    
}

- (void)testExample
{
    //  STFail(@"Unit tests are not implemented yet in TransitAuthorityTests");
}

+ (GameState *) exampleState{
    GameScenario *scenario = [[GameScenario alloc] init];
    scenario.cityName = @"Sticky-outy-ville";
    scenario.startingCash = 1000000;
    scenario.startingDate = [NSDate dateWithTimeIntervalSince1970:822128236];
    scenario.tmxMapPath = [[NSBundle mainBundle] pathForResource:@"sillysburg" ofType:@"tmx"];
    
    
    GameState *state = [[GameState alloc] initWithScenario:scenario];
    return state;
}

- (void) testFindTerminii{
    GameState *state = [TransitAuthorityTests exampleState];
    
    Line *redLine = [state addLineWithColor:LineColor_Red];
    XCTAssertNotNil(redLine, @"red line should exist");
    
    Station *northStation = [[Station alloc] init];
    northStation.name = @"North Station";
    
    Station *middleStation = [[Station alloc] init];
    middleStation.name = @"Middle Station";
    
    Station *southStation = [[Station alloc] init];
    southStation.name = @"South Station";
    
    TrackSegment *seg1 = [state buildTrackSegmentBetween:northStation second:middleStation];
    
    TrackSegment *seg2 = [state buildTrackSegmentBetween:middleStation second:southStation];
    
    XCTAssertTrue(southStation.links[middleStation.UUID] != nil, @"should be linked");
    XCTAssertTrue(middleStation.links[northStation.UUID] != nil, @"should be linked");
    XCTAssertTrue(northStation.links[southStation.UUID] == nil, @"should not be linked");
    
    [redLine applyToSegment:seg1];
    [redLine applyToSegment:seg2];
    
    NSLog(@"Red line segs served = %@",redLine.segmentsServed);
    
    XCTAssertTrue(redLine.segmentsServed.count > 0, @"should add to segments served");
    
    NSArray *terms = [GameState terminiForSegments:redLine.segmentsServed line:redLine];
    XCTAssertTrue([terms containsObject:northStation], @"wrong terminals");
    XCTAssertTrue([terms containsObject:southStation], @"wrong terminals");
    XCTAssertTrue(![terms containsObject:middleStation], @"wrong terminals");
    
    
}

- (void) testRouteFinding{
    GameState *state = [TransitAuthorityTests exampleState];
    Line *blueLine = [state addLineWithColor:LineColor_Blue];
    
    // make some test stations, link them with a single set of tracks
    // and make them all part of the blue line
    NSArray *testStationNames = @[@"A", @"B", @"C", @"D"];
    NSMutableArray *testStations = [NSMutableArray array];
    Station *lastStation;
    for(NSString *n in testStationNames){
        Station *s = [state buildNewStationAt:CGPointMake(10, 10)];
        s.name = n;
        
        if(lastStation){
            TrackSegment *track = [state buildTrackSegmentBetween:s second:lastStation];
            [blueLine applyToSegment:track];
        }
        lastStation = s;
        [testStations addObject:s];
    }
    
    NSLog(@"generated test network");
    XCTAssertTrue(state.stations.count == testStationNames.count, @"wrong number of stations");
    
    // now let's try to get a route that starts and ends in the same place.
    TrainRoute *route = [GameState routeForLine:blueLine];
    NSLog(@" straight route = %@", route);
    
    // let's make it circular and try to get a circular route now.
    TrackSegment *seg = [state buildTrackSegmentBetween:[testStations lastObject] second:testStations[0]];
    [blueLine applyToSegment:seg];
    
    TrainRoute *circularRoute = [GameState routeForLine:blueLine];
    NSLog(@" circular route = %@", circularRoute);
}

- (void) testGameLedgerStats{
    GameState *state = [TransitAuthorityTests exampleState];
    NSTimeInterval now = 0;
    
    NSNumber *count = [state.ledger getAggregate:Stat_Count forKey:@"derp" forRollingInterval:60 ending:now+1 interpolate:Interpolation_None];
    XCTAssertEqualObjects(count, @(0), @"wrong count, should be 0 initially");
    
    
    [state.ledger recordEventWithKey:@"derp" count:1 atDate:now];
    count = [state.ledger getAggregate:Stat_Count forKey:@"derp" forRollingInterval:60 ending:now+1 interpolate:Interpolation_None];
    XCTAssertEqualObjects(count, @(1), @"wrong count");
    
    count = [state.ledger getAggregate:Stat_Count forKey:@"derp" forRollingInterval:60 ending:now interpolate:Interpolation_None];
    XCTAssertEqualObjects(count, @(1), @"wrong count");
    
    [state.ledger recordEventWithKey:@"derp" count:1 atDate:now];
    XCTAssertEqualObjects([state.ledger getAggregate:Stat_Count forKey:@"derp" forRollingInterval:60 ending:now interpolate:Interpolation_None],
                          @(2),
                          @"wrong count");
    
    [state.ledger recordEventWithKey:@"derp2" count:1 atDate:now];
    
    XCTAssertEqualObjects([state.ledger getAggregate:Stat_Count forKey:@"derp" forRollingInterval:60 ending:now interpolate:Interpolation_None],
                          @(2),
                          @"wrong count");
    
    
    [state.ledger recordDatum:[[NSDecimalNumber alloc] initWithDouble:50] forKey:@"data" atDate:now];
    [state.ledger recordDatum:[[NSDecimalNumber alloc] initWithDouble:100] forKey:@"data" atDate:now];
    XCTAssertEqualObjects([state.ledger getAggregate:Stat_Count forKey:@"data" forRollingInterval:60 ending:now interpolate:Interpolation_None],
                          @(2),
                          @"wrong count");
    XCTAssertEqualObjects([state.ledger getAggregate:Stat_Sum forKey:@"data" forRollingInterval:60 ending:now interpolate:Interpolation_None],
                          @(150),
                          @"wrong sum");
    XCTAssertEqualObjects([state.ledger getAggregate:Stat_Average forKey:@"data" forRollingInterval:60 ending:now interpolate:Interpolation_None],
                          @(75),
                          @"wrong average");
    
    
    
    [state.ledger recordDatum:[[NSDecimalNumber alloc] initWithDouble:50] forKey:@"a" atDate:now ];
    [state.ledger recordDatum:[[NSDecimalNumber alloc] initWithDouble:50] forKey:@"a" atDate:now + 10];
    XCTAssertEqualObjects([state.ledger getAggregate:Stat_Sum forKey:@"a" forRollingInterval:60 ending:now interpolate:Interpolation_None],
                          @(50),
                          @"wrong sum");
    XCTAssertEqualObjects([state.ledger getAggregate:Stat_Sum forKey:@"a" forRollingInterval:60 ending:now+10 interpolate:Interpolation_None],
                          @(100),
                          @"wrong sum");
    
    XCTAssertEqualObjects([state.ledger getAggregate:Stat_Count forKey:@"a" forRollingInterval:60 ending:now+10 interpolate:Interpolation_None],
                          @(2),
                          @"wrong sum");
    
}

- (void) testPassengerDecisionFunctions{
    GameState *state = [TransitAuthorityTests exampleState];
   
    /*
     
         0  5   9
     _____________
    |
   0|    A      B
    |    l\   /m
   4|       C
    |      n|
   6|       D
    |     o/  \p
   9|    E      F
     
                    Z
     */
    
    Station *a = [state buildNewStationAt:CGPointMake(0, 0)];
    a.name = @"A";
    Station *b = [state buildNewStationAt:CGPointMake(9, 0)];
    b.name = @"B";
    Station *c = [state buildNewStationAt:CGPointMake(5, 4)];
    c.name = @"C";
    Station *d = [state buildNewStationAt:CGPointMake(5, 6)];
    d.name = @"D";
    Station *e = [state buildNewStationAt:CGPointMake(0, 9)];
    e.name = @"E";
    Station *f = [state buildNewStationAt:CGPointMake(9, 9)];
    f.name = @"F";
    Station *z = [state buildNewStationAt:CGPointMake(100, 100)];
    z.name = @"Z";
    
    TrackSegment *l = [state buildTrackSegmentBetween:a second:c];
    TrackSegment *m = [state buildTrackSegmentBetween:b second:c];
    
    TrackSegment *n = [state buildTrackSegmentBetween:c second:d];
    
    TrackSegment *o = [state buildTrackSegmentBetween:d second:e];
    TrackSegment *p = [state buildTrackSegmentBetween:d second:f];
    
    Line *redLine = [state addLineWithColor:LineColor_Red];
    Line *blueLine = [state addLineWithColor:LineColor_Blue];
    
    XCTAssertNotNil(redLine, @"should have created red line");
    XCTAssertNotNil(blueLine, @"should have created blue line");
    
    [redLine applyToSegment:l];
    [redLine applyToSegment:n];
    [redLine applyToSegment:o];
    [blueLine applyToSegment:m];
    [blueLine applyToSegment:n];
    [blueLine applyToSegment:p];
    
    [state regenerateAllTrainRoutes];
    
    
    
    XCTAssertTrue(redLine.segmentsServed.count == 3, @"should have 3 segs on red line");
    XCTAssertTrue(blueLine.segmentsServed.count == 3, @"should have 3 segs on blue line");
    XCTAssertTrue(l.lines.count == 1, @"should have one line on l");
    XCTAssertTrue(n.lines.count == 2, @"should have two lines on n");
    XCTAssertTrue(o.lines.count == 1, @"should have one line on o");
    
    XCTAssertTrue(a.lines.count == 1, @"should have one line on station a");
    XCTAssertTrue(b.lines.count == 1, @"should have one line on station b");
    XCTAssertTrue(c.lines.count == 2, @"should have two lines on station c");
    XCTAssertTrue(d.lines.count == 2, @"should have two lines on station d");
    
    NSLog(@"a lines = %@, b lines = %@, c lines = %@",a.lines, b.lines, c.lines);
    
    XCTAssertTrue([a.lines intersectsOrderedSet:c.lines], @"should have intersection between lines");
    XCTAssertTrue([c.lines intersectsOrderedSet:a.lines], @"should have intersection between lines");
    XCTAssertFalse([a.lines intersectsOrderedSet:b.lines], @"should not have intersection between lines");
    XCTAssertFalse([b.lines intersectsOrderedSet:a.lines], @"should not have intersection between lines");
    
    XCTAssertTrue(redLine.stationsServed.count == 4, @"red line should serve 4 stations");
    XCTAssertTrue(blueLine.stationsServed.count == 4, @"blue line should serve 4 stations");
    
    
    // now that the scenario is set up, try our routing functions
    
    // first, test route-finding within lines
    PassengerRouteInfo insideLine = [blueLine.preferredRoute passengerRouteFromStationA:c toStationB:b];
    XCTAssertTrue(insideLine.routeExists, @"should have route within blue line");
    XCTAssertTrue(insideLine.totalStationsVisited == 2, @"2 stations from a->b");
    
    insideLine = [blueLine.preferredRoute passengerRouteFromStationA:c toStationB:f];
    XCTAssertTrue(insideLine.routeExists, @"should have route within blue line for c->f");
    NSLog(@"visited %d stations from c->f on %@",insideLine.totalStationsVisited,blueLine.preferredRoute);
    XCTAssertTrue(insideLine.totalStationsVisited == 3, @"should visit 3 stations from c->f");
    
    
    
    // A->C
    PassengerRouteInfo i = [state passengerRouteInfoForOrigin:a destination:c maxTransfers:2];
    XCTAssertTrue(i.routeExists, @"should have a route");
    XCTAssertTrue(i.minTransfersNeeded == 0, @"should not need transfer");
    
    // A->B w/o transfers
    i = [state passengerRouteInfoForOrigin:a destination:b maxTransfers:0];
    XCTAssertFalse(i.routeExists, @"should not be able to get from A to B without a transfer");
    
    // A->B with transfers (should have to transfer at C)
    NSLog(@"WE ARE ABOUT TO GET THE A->B ROUTE");
    i = [state passengerRouteInfoForOrigin:a destination:b maxTransfers:2];
    XCTAssertTrue(i.routeExists, @"should have a route");
    XCTAssertTrue(i.minTransfersNeeded == 1, @"should need transfer");
    float expectedLength = [l distanceInTiles] + [m distanceInTiles];
    NSLog(@"a->b stations=%d, track=%f",i.totalStationsVisited,i.totalTrackCovered);
    XCTAssertTrue(i.totalStationsVisited == 3, @"stations visited with transfers");
    
    XCTAssertTrue(i.totalTrackCovered == expectedLength, @"track distance with transfers");
    
    // A->Z with transfers
    i = [state passengerRouteInfoForOrigin:a destination:z maxTransfers:2];
    XCTAssertFalse(i.routeExists, @"should not have a route");
    
    // A->E
    i = [state passengerRouteInfoForOrigin:a destination:e maxTransfers:2];
    XCTAssertTrue(i.routeExists, @"should have a route");
    XCTAssertTrue(i.minTransfersNeeded == 0, @"should not need a transfer for this");
    NSLog(@"total stations for a->e %d",i.totalStationsVisited);
    XCTAssertTrue(i.totalStationsVisited == 4, @"a->e is 4 stations");
    
    // A->F
    i = [state passengerRouteInfoForOrigin:a destination:f maxTransfers:2];
    XCTAssertTrue(i.routeExists, @"should have a route");
    XCTAssertTrue(i.minTransfersNeeded == 1, @"should need a transfer for this");
    NSLog(@"For a->f, visited %d stations",i.totalStationsVisited);
    XCTAssertTrue(i.totalStationsVisited == 4, @"should visit 4 stations a->f");
    // A->F
    i = [state passengerRouteInfoForOrigin:a destination:f maxTransfers:0];
    XCTAssertFalse(i.routeExists, @"should not have a route for this without transferring");
    
    // Okay that seems to work, now let's get trains running
    Train *redLineTrain = [state buyNewTrain];
    Train *blueLineTrain = [state buyNewTrain];
    redLineTrain.line = redLine;
    blueLineTrain.line = blueLine;
    state.unassignedTrains = [NSMutableDictionary dictionary];
    state.assignedTrains[redLineTrain.UUID] = redLineTrain;
    state.assignedTrains[blueLineTrain.UUID] = blueLineTrain;
    [state regenerateAllTrainRoutes];
   
    
    XCTAssertNotNil(redLineTrain, @"should have red line train");
    XCTAssertNotNil(blueLineTrain, @"should have blue line train");
    
    redLineTrain.currentRouteChunk = blueLineTrain.currentRouteChunk = 0;
    redLineTrain.currentChunkPosition = blueLineTrain.currentChunkPosition = 0;

    XCTAssertNotNil(redLineTrain.currentRoute, @"red line train should have route");
    XCTAssertNotNil(blueLineTrain.currentRoute, @"blue line train should have route");
    
    XCTAssertTrue(((RouteChunk *)redLineTrain.currentRoute.routeChunks[0]).origin == a, @"red line should start at e");
    XCTAssertTrue(((RouteChunk *)redLineTrain.currentRoute.routeChunks[0]).destination == c, @"red line route");
    XCTAssertTrue(((RouteChunk *)redLineTrain.currentRoute.routeChunks[1]).origin == c, @"red line route");
     XCTAssertTrue(((RouteChunk *)redLineTrain.currentRoute.routeChunks[1]).destination == d, @"red line route");
    
    XCTAssertTrue(((RouteChunk *)blueLineTrain.currentRoute.routeChunks[0]).origin == b, @"blue line should start at b");
    
    XCTAssertTrue(redLineTrain.currentRoute.routeChunks.count == 6, @"wrong route length");
    XCTAssertTrue(blueLineTrain.currentRoute.routeChunks.count == 6, @"wrong route length");
    
    // test that people are getting off at the right times
    
    // let's follow the red line
    // A->C, C->D, D->E, E->D, D->C, C->A
    // red line train is waiting in the station
    redLineTrain.currentRouteChunk = 0;
    redLineTrain.state = TrainState_StoppedInStation;
    i = [state passengerRouteForDestinationWithoutTurning:c onRoute:redLineTrain.currentRoute beginningWithChunk:0 maxTransfers:0];
    XCTAssertTrue(i.routeExists, @"passengerRouteInfoForTrainWithoutTurning");
    XCTAssertTrue(i.minTransfersNeeded == 0, @"passengerRouteInfoForTrainWithoutTurning");
    
    i = [state passengerRouteForDestinationWithoutTurning:d onRoute:redLineTrain.currentRoute beginningWithChunk:0 maxTransfers:0];
    
    XCTAssertTrue(i.routeExists, @"passengerRouteInfoForTrainWithoutTurning");
    XCTAssertTrue(i.minTransfersNeeded == 0, @"passengerRouteInfoForTrainWithoutTurning");
    
    // move along
    i = [state passengerRouteForDestinationWithoutTurning:a onRoute:redLineTrain.currentRoute beginningWithChunk:1 maxTransfers:0];
    XCTAssertFalse(i.routeExists, @"passengerRouteInfoForTrainWithoutTurning");
    
    i = [state passengerRouteForDestinationWithoutTurning:d onRoute:redLineTrain.currentRoute beginningWithChunk:1 maxTransfers:0];;
    XCTAssertTrue(i.routeExists, @"passengerRouteInfoForTrainWithoutTurning");
    
}

- (void) testRouteFindingWithinLine{
    GameState *state = [TransitAuthorityTests exampleState];
    Line *blueLine = [state addLineWithColor:LineColor_Blue];
    
    Station *a = [state buildNewStationAt:CGPointMake(0, 0)];
    a.name = @"a";
    Station *b = [state buildNewStationAt:CGPointMake(0, 3)];
    b.name = @"b";
    Station *c = [state buildNewStationAt:CGPointMake(0, 10)];
    c.name = @"c";
    TrackSegment *x = [state buildTrackSegmentBetween:c second:b];
    TrackSegment *y = [state buildTrackSegmentBetween:b second:a];
    
    [blueLine applyToSegment:x];
    [blueLine applyToSegment:y];
    
    [state regenerateAllTrainRoutes];
    
    NSAssert(blueLine.segmentsServed.count==2, @"should have two segments");
    
    TrainRoute *r = blueLine.preferredRoute;
    
    NSLog(@"preferred route = %@",r);
    
    PassengerRouteInfo info = [r passengerRouteFromStationA:a toStationB:b];
    NSLog(@"a->b = %d, %@",info.totalStationsVisited,blueLine.preferredRoute);
    
    NSAssert(info.routeExists, @"should exist");
    NSAssert(info.totalStationsVisited == 2, @"should be 2 stations from a->b");
    NSAssert(info.totalTrackCovered == 3, @"tile distance");
    
    info = [r passengerRouteFromStationA:a toStationB:c];
    NSLog(@"a->c = %d",info.totalStationsVisited);
    NSAssert(info.routeExists, @"should exist");
    NSAssert(info.totalStationsVisited == 3, @"should be 2 stations from a->c");
    NSAssert(info.totalTrackCovered == 10, @"tile distance");
    
    info = [r passengerRouteFromStationA:c toStationB:a];
    NSAssert(info.routeExists, @"should exist");
    NSAssert(info.totalStationsVisited == 3, @"should be 2 stations from c->a");
    NSAssert(info.totalTrackCovered == 10, @"tile distance");
}


@end
