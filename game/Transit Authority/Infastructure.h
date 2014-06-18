//
//  Infastructure.h
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameObject.h"

@class Line, PointOfInterest;

#pragma mark - Stations

/// A station in the system where people can get off and on
@interface Station : GameObject
@property(strong, nonatomic) NSString *name;
@property(assign, nonatomic) CGPoint tileCoordinate;
@property(assign, nonatomic) NSTimeInterval built;
@property(strong, nonatomic) NSMutableDictionary *links; // by station ID

- (NSSet *) linksForLine:(Line *)line; // the links this station has for a given line
@property(strong, nonatomic, readonly) NSOrderedSet *lines; // the lines this station serves

@property(strong) NSMutableDictionary *passengersByDestination; // UUID -> @(count)
- (unsigned) totalPassengersWaiting;

// Upgrades
@property(strong, nonatomic, readonly) NSSet *upgrades;
- (void) addUpgrade:(NSString *)upgradeIdent;
- (void) removeUpgrade:(NSString *)upgradeIdent;

// Point of interest
@property(strong, nonatomic, readonly) PointOfInterest *connectedPOI; // Is this station inside an airport, stadium, etc?

@end

#pragma mark - Tracks

/// A segment of track between two stations
@interface TrackSegment : GameObject
@property(strong, nonatomic) Station *startStation;
@property(strong, nonatomic) Station *endStation;
@property(assign, nonatomic) NSTimeInterval built;
@property(strong, nonatomic) NSMutableDictionary *lines;

- (CGFloat) distanceInTiles;
// control points/shape?
@end
