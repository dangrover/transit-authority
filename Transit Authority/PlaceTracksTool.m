//
//  PlaceTracksTool.m
//  Transit Authority
//
//  Created by Dan Grover on 6/25/13.
//
//

#import "PlaceTracksTool.h"
#import "MainGameScene.h"
#import "TracksNode.h"
#import "Utilities.h"
#import "CCTiledMap.h"
#import "CCLayerPanZoom.h"
#import "HKTMXTiledMap.h"
#import "CCTMXTiledMap+Extras.h"

@implementation PlaceTracksTool{
    TracksNode *trackPlacement;
    
    Station *startStation;
    Station *endStation;
}


- (NSString *) helpText{
    return @"TRACKS  Drag between two stations.";
}


- (BOOL) touchBegan:(UITouch *)touch withEvent:(UIEvent *)event{
    [super touchBegan:touch withEvent:event];
    
    startStation = endStation = nil;
    
    CGPoint nodeCoord = [touch locationInNode:self.parent->tiledMap];
    Station *station = [self.parent stationAtNodeCoords:nodeCoord];
    
    if(station){
        trackPlacement = [[TracksNode alloc] init];
        trackPlacement.contentSize = self.parent.contentSize;
        trackPlacement.position = self.parent.position;
        
        trackPlacement.start = ((CCSprite *)self.parent->_stationSprites[station.UUID]).position;
        trackPlacement.end = nodeCoord;
        
        startStation = station;
        
        [self.parent->tiledMap addChild:trackPlacement z:99];
        
        return YES;
    }
    
    return NO;
}

- (void) touchMoved:(UITouch *)touch withEvent:(UIEvent *)event{
    
    if(trackPlacement){
        CGPoint nodeCoord = [touch locationInNode:self.parent->tiledMap];
        CGPoint start = [self.parent->tiledMap tileCoordinateFromNodeCoordinate:trackPlacement.start];
        CGPoint end = [self.parent->tiledMap tileCoordinateFromNodeCoordinate:trackPlacement.end];
        CGFloat cost = [self.parent.gameState trackSegmentCostBetween:start tile:end];
        
        Station *station = [self.parent stationAtNodeCoords:nodeCoord];
        
        if(station){
            trackPlacement.end = ((CCSprite *)self.parent->_stationSprites[station.UUID]).position;
        }
        
        // make sure we can afford to build it and that station isn't already linked to this one
        if(station && (!station.links[startStation.UUID]) && (cost < self.parent.gameState.currentCash)){
            endStation = station;
            trackPlacement.valid = YES;
            self.validMove = YES;
        }else{
            endStation = nil;
            trackPlacement.end = nodeCoord;
            trackPlacement.valid = NO;
            self.validMove = NO;
        }
        
        costLabel.string = FormatCurrency(@(cost));
        costLabel.position = CGPointOffset( [touch locationInNode:self.parent], 75, 0);
    }
}

- (void) touchEnded:(UITouch *)touch withEvent:(UIEvent *)event{
    [super touchEnded:touch withEvent:event];
    
    CGFloat distanceInTiles = PointDistance(startStation.tileCoordinate, endStation.tileCoordinate);
    CGFloat cost = distanceInTiles * GAME_TRACK_COST_PER_TILE;
    
    [self.parent.gameState willChangeValueForKey:@"tracks"];
    if(endStation && (endStation != startStation) && (cost < self.parent.gameState.currentCash)){
        TrackSegment *segment = [self.parent.gameState buildTrackSegmentBetween:startStation second:endStation];
        
        [[OALSimpleAudio sharedInstance] playEffect:SoundEffect_BuildTunnel];
        
        // If there's only one line in the game, apply it here.
        if((self.parent.gameState.lines.count == 1) && ([self.parent.gameState line:self.parent.gameState.lines.allValues[0] canAddSegment:segment])){
            [((Line *)self.parent.gameState.lines.allValues[0]) applyToSegment:segment];
            [self.parent.gameState regenerateAllTrainRoutes];
        }else if((startStation.lines.count + endStation.lines.count) == 1){
            // If they're extending a line, let's do it for them to save them the click.
            Station *hasLines = (startStation.lines.count) ? startStation : endStation;
            Line *line = [hasLines.lines objectAtIndex:0];
            if([self.parent.gameState line:line canAddSegment:segment]){
                [line applyToSegment:segment];
                [self.parent.gameState regenerateAllTrainRoutes];
            }
        }
    }else{
        // invalid placement
        [[OALSimpleAudio sharedInstance] playEffect:SoundEffect_Error];
    }
    [self.parent.gameState didChangeValueForKey:@"tracks"];
    
    [self.parent->tiledMap removeChild:trackPlacement cleanup:YES];
    
    trackPlacement = nil;
}


- (void) touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event{
    [super touchCancelled:touch withEvent:event];
    if(trackPlacement){
        [self.parent->tiledMap removeChild:trackPlacement cleanup:YES];
        trackPlacement = nil;
    }
}

@end