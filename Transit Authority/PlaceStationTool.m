//
//  PlaceStationTool.m
//  Transit Authority
//
//  Created by Dan Grover on 6/25/13.
//
//

#import "PlaceStationTool.h"
#import "MainGameScene.h"
#import "cocos2d.h"
#import "CCTMXTiledMap+Extras.h"
#import "GameLedger.h"
#import "Utilities.h"
#import "StationCoverageOverlay.h"
#import "PointOfInterest.h"
#import "CCTMXTiledMap+Extras.h"

@implementation PlaceStationTool{
    CCSprite *stationPlacement;
    BOOL _validPlacement;
    StationCoverageOverlay *coverageOverlay;
    
    NSMutableSet *_poisToCheck;
    PointOfInterest *_poiToBeAssociatedWithStation;
    BOOL _heatmapWasOriginallyVisible;
    CCClippingNode *_clippingNode;
    CCSprite *_clippingMask;
}


- (NSString *) helpText{
    return @"STATION  Tap on map to build.";
}


- (void) started{
    _poisToCheck = [NSMutableSet setWithArray:self.parent.gameState.poisWithoutStations.allValues];
   
    unsigned t = self.parent.gameState.map.map.tileSize.width;
    _clippingMask = [self _createCircleStencilWithWalkRadius:GAME_STATION_WALK_RADIUS_TILES*t
                                                 driveRadius:GAME_STATION_CAR_RADIUS_TILES*t];
    
    
}

- (BOOL) touchBegan:(UITouch *)touch withEvent:(UIEvent *)event{
    if(event.allTouches.count > 1){
        return NO;
    }
    
    [super touchBegan:touch withEvent:event];
    
    _heatmapWasOriginallyVisible = self.parent.showPopulationHeatmap;
    

    stationPlacement = [[CCSprite alloc] initWithImageNamed:@"station.png"];
    stationPlacement.anchorPoint = CGPointMake(0.5, 0.5);
    stationPlacement.scale = [self.parent scaleConsideringZoom:STATION_SPRITE_SCALE_UNSELECTED];
    [self.parent->tiledMap addChild:stationPlacement z:20];
    
    CGPoint pos = [[CCDirector sharedDirector] convertToGL:[touch locationInView:[touch view]]];
    stationPlacement.position = pos;
    
    costLabel.string = FormatCurrency(@(GAME_STATION_COST));
    
    //_clippingMask = [[CCDrawNode alloc] init];
    _clippingNode = [[CCClippingNode alloc] initWithStencil:_clippingMask];
    
   /* HeatMapNode *heatMap = self.parent.heatMap;
    heatMap.visible = YES;
    [heatMap removeFromParent];
    [_clippingNode addChild:heatMap];
    [self.parent->tiledMap addChild:_clippingNode z:50];
    _clippingNode.alphaThreshold = 0.5;
   */
    
    
    coverageOverlay = [[StationCoverageOverlay alloc] init];
    [self.parent->tiledMap addChild:coverageOverlay z:50];
    coverageOverlay.walkTiles = GAME_STATION_WALK_RADIUS_TILES;
    coverageOverlay.carTiles = GAME_STATION_CAR_RADIUS_TILES;
   
    //CGFloat r = GAME_STATION_CAR_RADIUS_TILES*self.parent.gameState.map.map.tileSize.width*2;
   // [_clippingMask drawDot:CGPointMake(-0.5*r, -0.5*r)
   //                 radius:r
   //                  color:ccc4f(0, 0, 0, 1)];
    
    [self touchMoved:touch withEvent:event];
    
    return YES;
}


- (void) touchMoved:(UITouch *)touch withEvent:(UIEvent *)event{
    [super touchMoved:touch withEvent:event];
    
    CGPoint pos = [touch locationInNode:self.parent->tiledMap];
    CGPoint tileCoordinate = [self.parent->tiledMap tileCoordinateFromNodeCoordinate:pos];
    
    
    BOOL stationAlreadyExistsHere = ([self.parent stationAtNodeCoords:pos] != nil);
    
    if(stationAlreadyExistsHere || ![self.parent.gameState.map tileIsLand:tileCoordinate] || (self.parent.gameState.currentCash < GAME_STATION_COST)){
        stationPlacement.texture = [CCTexture textureWithFile:@"invalid-station.png"];
        self.validMove = NO;
    }else{
        
        // see if it hits a POI
        for(PointOfInterest *potentialPOI in _poisToCheck){
            if(PointDistance(potentialPOI.location, tileCoordinate) < 5){
                _poiToBeAssociatedWithStation = potentialPOI;
                tileCoordinate = potentialPOI.location;
                pos = [self.parent.gameState.map.landLayer positionAt:tileCoordinate]; // round it off
                
                break;
            }
        }
        
        stationPlacement.texture = [CCTexture textureWithFile:@"station.png"];
        self.validMove = YES;
    }
    
    _clippingMask.position = stationPlacement.position = coverageOverlay.position = pos;
    
}

- (void) touchEnded:(UITouch *)touch withEvent:(UIEvent *)event{
    [super touchEnded:touch withEvent:event];
    
    [self.parent->tiledMap removeChild:stationPlacement cleanup:YES];
    stationPlacement = nil;
    [self.parent->tiledMap removeChild:coverageOverlay];
    coverageOverlay = nil;
    
    GameState *gameState = self.parent.gameState;
    
   // [self _fixHeatMap];
    
    // place the actual station
    CGPoint tileCoordinate = [self.parent->tiledMap tileCoordinateFromNodeCoordinate:[self.parent->tiledMap convertToNodeSpace:[touch locationInNode:self.parent->tiledMap]]];
    
    if(self.validMove && (gameState.currentCash >= GAME_STATION_COST)){
        if(_poiToBeAssociatedWithStation){
            [gameState buildNewStationForPOI:_poiToBeAssociatedWithStation];
            [_poisToCheck removeObject:_poiToBeAssociatedWithStation];
            _poiToBeAssociatedWithStation = nil;
        }else{
            [gameState buildNewStationAt:tileCoordinate];
        }
    }else{
    //    [self.parent->audioEngine playEffect:SoundEffect_Error];
    }
}

- (void)touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event{
    [super touchCancelled:touch withEvent:event];
    
    [self.parent->tiledMap removeChild:stationPlacement];
    [self.parent->tiledMap removeChild:coverageOverlay];
    stationPlacement = nil;
    coverageOverlay = nil;
    _poiToBeAssociatedWithStation = nil;
    
    [self _fixHeatMap];
}

- (void) _fixHeatMap{
    [self.parent.heatMap removeFromParent];
    [self.parent->tiledMap addChild:self.parent.heatMap];
    self.parent.heatMap.visible = _heatmapWasOriginallyVisible;
}

- (CCSprite *) _createCircleStencilWithWalkRadius:(unsigned)walkRadius driveRadius:(unsigned)driveRadius{
    CGSize imgPointSize = CGSizeMake(driveRadius*2, driveRadius*2);
    CGSize imgBufferSize = CGSizeMake(driveRadius*2*CC_CONTENT_SCALE_FACTOR(),
                                driveRadius*2*CC_CONTENT_SCALE_FACTOR());
    
    NSMutableData *mainRenderSpace = [[NSMutableData alloc] initWithLength:imgBufferSize.width*imgBufferSize.height*4];
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceGray();
    CGContextRef ctx = CGBitmapContextCreate((void *)[mainRenderSpace bytes],
                                             imgBufferSize.width,
                                             imgBufferSize.height,
                                             8,
                                             imgBufferSize.width,
                                             rgbColorSpace,
                                             kCGImageAlphaOnly);
    
    CGContextScaleCTM(ctx, CC_CONTENT_SCALE_FACTOR(), CC_CONTENT_SCALE_FACTOR());
    
    CGContextSetFillColorWithColor(ctx, [[UIColor colorWithWhite:0 alpha:0.5] CGColor]);
    CGContextFillEllipseInRect(ctx, CGRectMake(0, 0, imgPointSize.width, imgPointSize.height));
    
  /*  CGContextSetFillColorWithColor(ctx, [[UIColor colorWithWhite:0 alpha:0.5] CGColor]);
    CGContextFillEllipseInRect(ctx, CGRectMake(imgPointSize.width/2.0 - walkRadius,
                                               imgPointSize.height/2.0 - walkRadius,
                                               walkRadius*2,
                                               walkRadius*2));
    
    */
    
     CCTexture *tex = [[CCTexture alloc] initWithData:[mainRenderSpace bytes]
                        pixelFormat:CCTexturePixelFormat_A8
                         pixelsWide:imgBufferSize.width
                         pixelsHigh:imgBufferSize.height
                contentSizeInPixels:CGSizeMake(imgBufferSize.width, imgBufferSize.height)
                       contentScale:1.0];
    
    
    
    CGContextRelease(ctx);
    
    return [[CCSprite alloc] initWithTexture:tex];
}




@end
