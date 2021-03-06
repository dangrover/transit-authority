//
//  GameMap.m
//  Transit Authority
//
//  Created by Dan Grover on 7/20/13.
//
//

#import "GameMap.h"
#import "CCTiledMap.h"
#import "CCTMXXMLParser.h"
#import "CCTiledMapLayer.h"

#define TILE_GID_LAND 1
#define TILE_GID_AIRPORT 4
#define TILE_GID_WATER 2

@interface GameMap()
@property(strong, readwrite) NSString *originalPath;
@property(strong, readwrite) MAP_CLASS *map;
@property(assign, readwrite) CGPoint startPosition;
@property(strong, readwrite) MAP_LAYER_CLASS *landLayer;
@property(strong, readwrite) MAP_LAYER_CLASS *residentialPopulationLayer;
@property(strong, readwrite) MAP_LAYER_CLASS *commericalPopulationLayer;
@property(strong, readwrite) MAP_LAYER_CLASS *elevationLayer;
@end

@implementation GameMap{
    unsigned _totalPopulation;
}

- (id) initWithMapAtPath:(NSString *)thePath{
    if(self = [super init]){
        #ifdef UNIT_TESTS
            self.map = [[MAP_CLASS alloc] initWithFile:thePath];
        #else
            self.map = [[MAP_CLASS alloc] initWithTMXFile:thePath];
        #endif
        
        self.originalPath = thePath;
        
        // find start location
        if(self.map.properties[@"start"]){
            NSArray *split = [self.map.properties[@"start"] componentsSeparatedByString:@","];
            self.startPosition = CGPointMake([split[0] intValue], [split[1] intValue]);
        }
        
        self.residentialPopulationLayer = [self.map layerNamed:@"Residential"];
        self.commericalPopulationLayer = [self.map layerNamed:@"Commercial"];
        self.landLayer = [self.map layerNamed:@"Land"];
        self.elevationLayer = [self.map layerNamed:@"Elevation"];
        
        NSAssert(self.landLayer, @"couldn't find land layer");
        NSAssert(self.residentialPopulationLayer, @"couldn't find res population layer");
        NSAssert(self.commericalPopulationLayer, @"couldn't find com population layer");
        NSAssert(self.elevationLayer, @"couldn't find elevation layer");
        
        // tabulate the total population
        _totalPopulation = 0;
        for(unsigned x = 0; x < self.map.mapSize.width; x++){
            for(unsigned y = 0; y < self.map.mapSize.height; y++){
                _totalPopulation += [self totalDensityAt:CGPointMake(x, y)];
            }
        }
    }
    
    return self;
}

- (unsigned) totalPopulation{
    return _totalPopulation;
}

- (CGSize) size{
    return self.map.mapSize;
}

- (CCTiledMapObjectGroup *) neighborhoodNames{
    return [self.map objectGroupNamed:@"Neighborhoods"];
}

- (CCTiledMapObjectGroup *) streets{
    return [self.map objectGroupNamed:@"Streets"];
}

- (unsigned) commercialDensityAt:(CGPoint)p{
    if((self.size.width <= p.x) || (self.size.height <= p.y)) return 0;
    
    uint32_t comGid = [self.commericalPopulationLayer tileGIDAt:p];
    
    return comGid ? MAX(0, MIN(GAMEMAP_MAX_DENSITY, comGid - self.commericalPopulationLayer.tileset.firstGid + 1)) : 0;
}

- (unsigned) residentialDensityAt:(CGPoint)p{
    if((self.size.width <= p.x) || (self.size.height <= p.y)) return 0;
    
    uint32_t resGid = [self.residentialPopulationLayer tileGIDAt:p];
    return resGid ? MAX(0, MIN(GAMEMAP_MAX_DENSITY, resGid - self.residentialPopulationLayer.tileset.firstGid + 1)) : 0;
}

- (unsigned) totalDensityAt:(CGPoint)p{
    return [self commercialDensityAt:p] + [self residentialDensityAt:p];
}

- (unsigned) elevationAt:(CGPoint)p{
    if((self.size.width <= p.x) || (self.size.height <= p.y)) return 0;
    
    uint32_t resGid = [self.elevationLayer tileGIDAt:p];
    return resGid ? MAX(0, MIN(GAMEMAP_MAX_ELEVATION, resGid - self.elevationLayer.tileset.firstGid + 1)) : 0;
}

- (BOOL) tileCoordinateIsInBounds:(CGPoint)tileCoordinate{
    return ((tileCoordinate.x >= 0) && (tileCoordinate.y >= 0)
            && (tileCoordinate.x < self.map.mapSize.width)
            && (tileCoordinate.y < self.map.mapSize.height));
}

// This is a simplified rasterization function which returns all of the grid squares on a diagonal from A to B.
- (NSArray *)tilesBetweenTile:(CGPoint)tileA andTile:(CGPoint)tileB {
    
    // Count two times the amount of tiles needed for a horizontal or vertical line.
    float deltaX = tileA.x - tileB.x;
    float deltaY = tileA.y - tileB.y;
    float distance = sqrt(deltaX * deltaX + deltaY * deltaY);
    int pointsToMake = round(distance*2);
    
    int i;
    NSMutableArray *tiles = [NSMutableArray arrayWithCapacity:pointsToMake];
    for (i = 0; i < pointsToMake; i++)
    {
        // Find and add the point i/pointsToMake of the way from A to B.
        NSValue *newPoint = [NSValue valueWithCGPoint:CGPointMake(
                                                                  tileB.x + round(i*deltaX/pointsToMake),
                                                                  tileB.y + round(i*deltaY/pointsToMake)
                                                                  )];
        if (![[tiles lastObject] isEqual:newPoint])
        {
            [tiles addObject:newPoint];
        }
    }
    return tiles;
}

// This function returns the distance of a track that is water between two points, in tile lengths.
- (float)waterPartBetweenTile:(CGPoint)tileA andTile:(CGPoint)tileB
{
    float deltaX = tileA.x - tileB.x;
    float deltaY = tileA.y - tileB.y;
    float distance = sqrt(deltaX * deltaX + deltaY * deltaY);
    
    NSArray *tiles = [self tilesBetweenTile:tileA andTile:tileB];
    int totalTiles = [tiles count];

    if (totalTiles == 0)
    {
        return 0;
    }
    
    int totalWaterTiles = 0;
    int i;
    for (i = 0; i < [tiles count]; i++)
    {
        CGPoint tile = [[tiles objectAtIndex:i] CGPointValue];
        if ([self.landLayer tileGIDAt:tile] == TILE_GID_WATER)
        {
            totalWaterTiles++;
        }
    }
    return distance*totalWaterTiles/totalTiles;
}


- (BOOL) tileIsLand:(CGPoint)p{
    unsigned gid = [self.landLayer tileGIDAt:p];
    return ((gid == TILE_GID_LAND) || (gid == TILE_GID_AIRPORT));
}
@end