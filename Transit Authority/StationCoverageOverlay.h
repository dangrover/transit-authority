//
//  StationCoverageOverlay.h
//  Transit Authority
//
//  Created by Dan Grover on 8/20/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "CCDrawNode.h"
#import "CCNode.h"

@interface StationCoverageOverlay : CCDrawNode

@property(assign) unsigned walkTiles;
@property(assign) unsigned carTiles;
@property(assign) BOOL makeCarPartDarker;
@property(assign) BOOL labelsVisible;

@end
