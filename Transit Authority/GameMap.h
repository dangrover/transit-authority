//
//  GameMap.h
//  Transit Authority
//
//  Created by Dan Grover on 7/20/13.
//
//

#import <Foundation/Foundation.h>

@class CCTiledMap, CCTiledMapObjectGroup, CCTiledMapLayer, CCTiledMap, HKTMXLayer;

#define GAMEMAP_MAX_DENSITY 3 /// the maximum density in a given tile

/// When running unit tests, switch out CCTiledMap for the standard cocos2d class.
/// It seems to freak out when we use CCTiledMap, but we're not doing any graphics,
/// so it doesn't matter.
#ifdef UNIT_TESTS
#define MAP_CLASS CCTMXTiledMap
#import "CCTMXTiledMap.h"
#else
#define MAP_CLASS CCTiledMap
#endif

/// GameMap is a facade for accessing the map for a city.
/// Mainly contains a bunch of convenience methods for accessing things we need often.
@interface GameMap : NSObject
- (id) initWithMapAtPath:(NSString *)thePath;

@property(strong, nonatomic, readonly) NSString *originalPath;
@property(strong, nonatomic, readonly) MAP_CLASS *map;
@property(strong, nonatomic, readonly) CCTiledMapLayer *landLayer;
@property(strong, nonatomic, readonly) CCTiledMapLayer *residentialPopulationLayer;
@property(strong, nonatomic, readonly) CCTiledMapLayer *commericalPopulationLayer;
@property(strong, nonatomic, readonly) CCTiledMapObjectGroup *neighborhoodNames;
@property(strong, nonatomic, readonly) CCTiledMapObjectGroup *streets;
@property(assign, nonatomic, readonly) CGPoint startPosition; // where to put the camera when we start
@property(assign, nonatomic, readonly) CGSize size;

// Misc
- (BOOL) tileCoordinateIsInBounds:(CGPoint)tileCoordinate;
- (BOOL) tileIsLand:(CGPoint)p;


// Population Info
@property(assign, nonatomic, readonly) unsigned totalPopulation;
- (unsigned) commercialDensityAt:(CGPoint)p;
- (unsigned) residentialDensityAt:(CGPoint)p;
- (unsigned) totalDensityAt:(CGPoint)p;



@end
