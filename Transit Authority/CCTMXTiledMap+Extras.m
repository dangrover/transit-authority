//
//  CCTMXTiledMap+Extras.m
//  Transit Authority
//
//  Created by Dan Grover on 6/7/13.
//
//

#import "CCTMXTiledMap+Extras.h"
#import "CCTMXTiledMap.h"

@implementation CCTMXTiledMap (Extras)
- (CGPoint) tileCoordinateFromNodeCoordinate:(CGPoint)nodeCoordinate{
    return CGPointMake(floor(nodeCoordinate.x / (self.tileSize.width / CC_CONTENT_SCALE_FACTOR())),
                self.mapSize.height - floor(nodeCoordinate.y / (self.tileSize.height/ CC_CONTENT_SCALE_FACTOR())) - 1);
}


@end
@implementation HKTMXTiledMap (Extras)
- (CGPoint) tileCoordinateFromNodeCoordinate:(CGPoint)nodeCoordinate{
    return CGPointMake(floor(nodeCoordinate.x / (self.tileSize.width)),
                       self.mapSize.height - floor(nodeCoordinate.y / (self.tileSize.height)) - 1);
}


@end
