//
//  CCTMXTiledMap+Extras.h
//  Transit Authority
//
//  Created by Dan Grover on 6/7/13.
//
//

#import "CCTiledMap.h"
#import "CCTiledMapLayer.h"
//#import "CCTiledMap.h"

@interface CCTiledMap (Extras)
- (CGPoint) tileCoordinateFromNodeCoordinate:(CGPoint)nodeCoordinate;
@end

/*
@interface CCTiledMap (Extras)
- (CGPoint) tileCoordinateFromNodeCoordinate:(CGPoint)nodeCoordinate;
@end
*/