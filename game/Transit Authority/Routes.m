//
//  Routes.m
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "Routes.h"
#import "GameState.h"
#import "NSCoding-Macros.h"

@interface Line()
@property(assign, readwrite) LineColor color;
@end

@implementation Line{
    NSMutableArray *_segmentsServed;
}
static NSArray *uiColorsForLines;

- (id) initWithColor:(LineColor)theColor{
    if(self = [super init]){
        _segmentsServed = [NSMutableArray array];
        self.numberOfCars = 2;
        self.color = theColor;
    }
    
    return self;
}

- (NSString *) description{
    return [NSString stringWithFormat:@"<Line: %@>", [Line nameForLineColor:self.color]];
}

- (void) applyToSegment:(TrackSegment *)theSeg{
    theSeg.lines[@(self.color)] = self;
    [_segmentsServed addObject:theSeg];
}

- (void) removeFromSegment:(TrackSegment *)theSeg{
    if(!theSeg.lines[@(self.color)]) return;
    [theSeg.lines removeObjectForKey:@(self.color)];
    [_segmentsServed removeObject:theSeg];
}

- (NSOrderedSet *) stationsServed{
    NSMutableOrderedSet *stationsServed = [[NSMutableOrderedSet alloc] init];
    for(TrackSegment *s in self.segmentsServed){
        [stationsServed addObject:s.startStation];
        [stationsServed addObject:s.endStation];
    }
    
    return stationsServed;
}

- (NSArray *) segmentsServed{
    return _segmentsServed;
}

+ (UIColor *) uiColorForLineColor:(LineColor)theColor{
    if(!uiColorsForLines){
        uiColorsForLines = @[[UIColor colorWithRed:0.824 green:0.035 blue:0.082 alpha:1.000],
                             [UIColor colorWithRed:0.973 green:0.353 blue:0.122 alpha:1.000],
                             [UIColor colorWithRed:0.965 green:0.941 blue:0.204 alpha:1.000],
                             [UIColor colorWithRed:0.110 green:0.620 blue:0.098 alpha:1.000],
                             [UIColor colorWithRed:0.071 green:0.384 blue:0.647 alpha:1.000],
                             [UIColor colorWithRed:0.404 green:0.071 blue:0.584 alpha:1.000],
                             [UIColor colorWithRed:0.498 green:0.314 blue:0.059 alpha:1.000]
                             ];
    }
    
    return uiColorsForLines[theColor];
}

+ (NSString *) nameForLineColor:(LineColor)theColor{
    NSArray *colorNames = @[@"Red Line", @"Orange Line", @"Yellow Line", @"Green Line", @"Blue Line", @"Purple Line", @"Brown Line"];
    return colorNames[theColor];
}

- (void)encodeWithCoder:(NSCoder *)encoder {
    encodeInt(_numberOfCars);
    encodeInt(_color);
    encodeObject(_segmentsServed);
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [self init])
    {
        decodeInt(_numberOfCars);
        decodeInt(_color);
        decodeObject(_segmentsServed);
    }
    return self;
}

@end

#pragma mark -


@implementation TrainRoute

- (id) init{
    if(self = [super init]){
        self.routeChunks = [NSMutableArray array];
        
    }
    return self;
}

- (NSString *) description{
    return [NSString stringWithFormat:@"<TrainRoute: line=%@, chunks=%@>",self.line, self.routeChunks];
}

- (BOOL) reachesStation:(Station *)theStation{
    for(RouteChunk *c in self.routeChunks){
        if([c.origin isEqual:theStation] || [c.destination isEqual:theStation]){
            return YES;
        }
    }
    
    return NO;
}

- (PassengerRouteInfo) passengerRouteFromStationA:(Station *)a toStationB:(Station *)b{
    unsigned originIndex = NSNotFound;
    unsigned destIndex = NSNotFound;
    
    for(unsigned chunkIndex = 0; chunkIndex < self.routeChunks.count; chunkIndex++){
        RouteChunk *thisChunk = self.routeChunks[chunkIndex];
        if([thisChunk.origin isEqual:a]){
            originIndex = chunkIndex;
        }
        
        if((originIndex != NSNotFound) && [thisChunk.destination isEqual:b]){
            destIndex = chunkIndex;
            break;
        }
    }
    
    PassengerRouteInfo info;
    info.minTransfersNeeded = info.totalStationsVisited = info.totalTrackCovered = 0;
    info.routeExists = NO;
    
    if((originIndex != NSNotFound) && (destIndex != NSNotFound)){
        unsigned startIndex = MIN(originIndex, destIndex);
        unsigned endIndex = MAX(originIndex, destIndex);
        
        info.routeExists = YES;
        info.totalStationsVisited = endIndex - startIndex + 2;
        info.totalTrackCovered = [self tileDistanceOfTrackCoveredByChunks:NSMakeRange(startIndex, endIndex - startIndex)];
    }
    
    return info;
}

- (float) tileDistanceOfTrackCoveredByChunks:(NSRange)range{
    float distance = 0;
    for(unsigned i = range.location; i <= (range.location + range.length); i++){
        distance += ((RouteChunk *)self.routeChunks[i]).trackSegment.distanceInTiles;
    }
    return distance;
}

- (NSOrderedSet *) segmentsInRoute{
    NSMutableOrderedSet *set = [[NSMutableOrderedSet alloc] initWithCapacity:self.routeChunks.count];
    for(RouteChunk *rC in self.routeChunks){
        [set addObject:rC.trackSegment];
    }
    return set;
}
@end

#pragma mark -

@implementation RouteChunk

- (NSString *) description{
    return [NSString stringWithFormat:@"%@ -> %@",self.origin.name, self.destination.name];
}

- (Station *) origin{
    return self.backwards ? self.trackSegment.endStation : self.trackSegment.startStation;
}

- (Station *) destination{
    return self.backwards ? self.trackSegment.startStation : self.trackSegment.endStation;
}


@end
