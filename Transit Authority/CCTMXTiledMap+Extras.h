//
//  CCTMXTiledMap+Extras.h
//  Transit Authority
//
//  Created by Dan Grover on 6/7/13.
//
//

#import "CCTMXTiledMap.h"
#import "CCTMXLayer.h"
#import "HKTMXTiledMap.h"

@interface CCTMXTiledMap (Extras)
- (CGPoint) tileCoordinateFromNodeCoordinate:(CGPoint)nodeCoordinate;
@end

@interface HKTMXTiledMap (Extras)
- (CGPoint) tileCoordinateFromNodeCoordinate:(CGPoint)nodeCoordinate;
@end
