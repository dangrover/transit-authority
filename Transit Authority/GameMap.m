//
//  GameMap.m
//  Transit Authority
//
//  Created by Dan Grover on 7/20/13.
//
//

#import "GameMap.h"
#import "HKTMXTiledMap.h"
#import "CCTMXXMLParser.h"

#define TILE_GID_LAND 10
#define TILE_GID_AIRPORT 75

@interface GameMap()
@property(strong, readwrite) NSString *originalPath;
@property(strong, readwrite) MAP_CLASS *map;
@property(assign, readwrite) CGPoint startPosition;

@property(strong, readwrite) HKTMXLayer *landLayer;
@property(strong, readwrite) HKTMXLayer *residentialPopulationLayer;
@property(strong, readwrite) HKTMXLayer *commericalPopulationLayer;
@end

@implementation GameMap{
    unsigned _totalPopulation;
}

- (id) initWithMapAtPath:(NSString *)thePath{
    if(self = [super init]){
        self.map = [[MAP_CLASS alloc] initWithTMXFile:thePath];
        self.originalPath = thePath;
        
        // find start location
        if(self.map.properties[@"start"]){
            NSArray *split = [self.map.properties[@"start"] componentsSeparatedByString:@","];
            self.startPosition = CGPointMake([split[0] intValue], [split[1] intValue]);
        }
        
        self.residentialPopulationLayer = [self.map layerNamed:@"Residential"];
        self.commericalPopulationLayer = [self.map layerNamed:@"Commercial"];
        self.landLayer = [self.map layerNamed:@"Land"];
        
        NSAssert(self.landLayer, @"couldn't find land layer");
        NSAssert(self.residentialPopulationLayer, @"couldn't find res population layer");
        NSAssert(self.commericalPopulationLayer, @"couldn't find com population layer");
        
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

- (CCTMXObjectGroup *) neighborhoodNames{
    return [self.map objectGroupNamed:@"Neighborhoods"];
}

- (CCTMXObjectGroup *) streets{
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

- (BOOL) tileCoordinateIsInBounds:(CGPoint)tileCoordinate{
    return ((tileCoordinate.x >= 0) && (tileCoordinate.y >= 0)
            && (tileCoordinate.x < self.map.mapSize.width)
            && (tileCoordinate.y < self.map.mapSize.height));
}

- (BOOL) tileIsLand:(CGPoint)p{
    unsigned gid = [self.landLayer tileGIDAt:p];
    return ((gid == TILE_GID_LAND) || (gid == TILE_GID_AIRPORT));
}
@end