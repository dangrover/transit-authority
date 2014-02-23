//
//  Infastructure.m
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "Infastructure.h"
#import "GameState.h"
#import "Utilities.h"

@interface Station()
@property(strong, nonatomic, readwrite) PointOfInterest *connectedPOI;
@end

@implementation Station{
    NSMutableSet *_upgrades;
}

- (id)init{
    if(self = [super init]){
        self.links = [NSMutableDictionary dictionary];
        self.passengersByDestination = [NSMutableDictionary dictionary];
        _upgrades = [[NSMutableSet alloc] init];
    }
    return self;
}

- (NSString *) description{
    return [NSString stringWithFormat:@"<Station: %@>", self.name];
}

- (NSSet *) linksForLine:(Line *)line{
    NSMutableSet *links = [NSMutableSet set];
    for(TrackSegment *t in self.links.allValues){
        if(t.lines[@(line.color)]){
            [links addObject:t];
        }
    }
    return links;
}

- (NSOrderedSet *) lines{
    NSMutableOrderedSet *allLines = [[NSMutableOrderedSet alloc] init];
    for(TrackSegment *t in self.links.allValues){
        [allLines addObjectsFromArray:t.lines.allValues];
    }
    return allLines;
}

- (unsigned) totalPassengersWaiting{
    unsigned total = 0;
    for(NSArray *a in self.passengersByDestination.allValues){
        total += a.count;
    }
    return total;
}

- (void) addUpgrade:(NSString *)upgradeIdent{
    [self willChangeValueForKey:@"upgrades"];
    [_upgrades addObject:upgradeIdent];
    [self didChangeValueForKey:@"upgrades"];
}

- (void) removeUpgrade:(NSString *)upgradeIdent{
    [self willChangeValueForKey:@"upgrades"];
    [_upgrades removeObject:upgradeIdent];
    [self didChangeValueForKey:@"upgrades"];
}

- (NSSet *) upgrades{
    return _upgrades;
}

@end

#pragma mark -

@implementation TrackSegment

- (id) init{
    if(self = [super init]){
        self.lines = [NSMutableDictionary dictionary];
    }
    
    return self;
}

- (CGFloat) distanceInTiles{
    return PointDistance(self.startStation.tileCoordinate, self.endStation.tileCoordinate);
}

@end