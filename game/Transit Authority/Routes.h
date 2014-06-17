//
//  Routes.h
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameObject.h"
#import "Infastructure.h"

typedef struct{
    BOOL routeExists;
    unsigned minTransfersNeeded;
    unsigned totalStationsVisited;
    float totalTrackCovered;
} PassengerRouteInfo;

typedef enum{
    PassengerType_ResToCom,
    PassengerType_ComToRes
} PassengerType;

#pragma mark -

@class TrackSegment, TrainRoute;

typedef enum {
    LineColor_Red,
    LineColor_Orange,
    LineColor_Yellow,
    LineColor_Green,
    LineColor_Blue,
    LineColor_Purple,
    LineColor_Brown
} LineColor;
#define LineColor_Min LineColor_Red
#define LineColor_Max LineColor_Brown

@interface Line : NSObject
- (id) initWithColor:(LineColor)theColor;
@property(assign) int numberOfCars;
@property(assign, readonly) LineColor color;
@property(strong, readonly) NSArray *segmentsServed;
@property(strong, readonly) NSOrderedSet *stationsServed;

@property(strong) TrainRoute *preferredRoute;

- (void) applyToSegment:(TrackSegment *)theSeg;
- (void) removeFromSegment:(TrackSegment *)theSeg;

+ (UIColor *) uiColorForLineColor:(LineColor)theColor;
+ (NSString *) nameForLineColor:(LineColor)theColor;
@end

#pragma mark -

@interface TrainRoute : GameObject
@property(assign) Line *line;
@property(assign) BOOL isCircular;
@property(strong) NSMutableArray *routeChunks;
- (BOOL) reachesStation:(Station *)theStation;
- (PassengerRouteInfo) passengerRouteFromStationA:(Station *)a toStationB:(Station *)b;
- (NSOrderedSet *) segmentsInRoute;

@end

#pragma mark -

@interface RouteChunk : NSObject
@property(strong) TrackSegment *trackSegment;
@property(assign) BOOL backwards; // if true, goes from endStation->startStation

@property(strong, readonly) Station *origin;
@property(strong, readonly) Station *destination;
@end
