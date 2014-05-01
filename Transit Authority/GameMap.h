//
//  GameMap.h
//  Transit Authority
//
//  Created by Dan Grover on 7/20/13.
//
//

#import <Foundation/Foundation.h>

@class CCTiledMap, CCTiledMapObjectGroup, CCTiledMapLayer, CCTiledMap, HKTMXTiledMap;

#define GAMEMAP_MAX_DENSITY 3 /// the maximum density in a given tile
#define GAMEMAP_MAX_ELEVATION 3 /// the maximum elevation

/// When running unit tests, switch out CCTiledMap for the standard cocos2d class.
/// It seems to freak out when we use CCTiledMap, but we're not doing any graphics,
/// so it doesn't matter.
#ifdef UNIT_TESTS
#define MAP_CLASS CCTiledMap
#define MAP_LAYER_CLASS CCTiledMapLayer
#import "CCTiledMap.h"
#else
#import "HKTMXTiledMap.h"
#define MAP_CLASS HKTMXTiledMap
#define MAP_LAYER_CLASS HKTMXLayer
#endif

/// GameMap is a facade for accessing the map for a city.
/// Mainly contains a bunch of convenience methods for accessing things we need often.
@interface GameMap : NSObject
- (id) initWithMapAtPath:(NSString *)thePath;

@property(strong, nonatomic, readonly) NSString *originalPath;
@property(strong, nonatomic, readonly) MAP_CLASS *map;
@property(strong, nonatomic, readonly) MAP_LAYER_CLASS *landLayer;
@property(strong, nonatomic, readonly) MAP_LAYER_CLASS *residentialPopulationLayer;
@property(strong, nonatomic, readonly) MAP_LAYER_CLASS *commericalPopulationLayer;
@property(strong, nonatomic, readonly) MAP_LAYER_CLASS *elevationLayer;
@property(strong, nonatomic, readonly) CCTiledMapObjectGroup *neighborhoodNames;
@property(strong, nonatomic, readonly) CCTiledMapObjectGroup *streets;
@property(assign, nonatomic, readonly) CGPoint startPosition; // where to put the camera when we start
@property(assign, nonatomic, readonly) CGSize size;

// Misc
- (BOOL) tileCoordinateIsInBounds:(CGPoint)tileCoordinate;
- (BOOL) tileIsLand:(CGPoint)p;
- (NSArray *)tilesBetweenTile:(CGPoint)tileA andTile:(CGPoint)tileB;
- (float)waterPartBetweenTile:(CGPoint)tileA andTile:(CGPoint)tileB;

// Population Info
@property(assign, nonatomic, readonly) unsigned totalPopulation;
- (unsigned) commercialDensityAt:(CGPoint)p;
- (unsigned) residentialDensityAt:(CGPoint)p;
- (unsigned) totalDensityAt:(CGPoint)p;

// Elevation Info
- (unsigned) elevationAt:(CGPoint)p;


@end
