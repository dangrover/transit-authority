//
//  StationCoverageOverlay.m
//  Transit Authority
//
//  Created by Dan Grover on 8/20/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "StationCoverageOverlay.h"
#import "CCLabelTTF.h"
#import <QuartzCore/QuartzCore.h>
#import "CCDirector.h"

@implementation StationCoverageOverlay{
    unsigned _walkTiles;
    unsigned _carTiles;
    BOOL _needsRedraw;
    CCLabelTTF *_walkLabel;
    CCLabelTTF *_carLabel;
    BOOL _makeCarPartDarker;
    BOOL _labelsVisible;
}

- (id) init{
    if(self = [super init]){
        _walkLabel = [[CCLabelTTF alloc] initWithString:@"WALKING" fontName:@"NewsCycle" fontSize:12];
        _carLabel = [[CCLabelTTF alloc] initWithString:@"DRIVING" fontName:@"NewsCycle" fontSize:12];
        [self addChild:_walkLabel];
        [self addChild:_carLabel];
        _walkLabel.opacity = _carLabel.opacity = 175;
      //  NSLog(@"added labels");
    }
    return self;
}

- (unsigned) walkTiles{
    return _walkTiles;
}

- (void) setWalkTiles:(unsigned int)walkTiles{
    _walkTiles = walkTiles;
    _walkLabel.position = CGPointMake(0, 16/[CCDirector sharedDirector].contentScaleFactor*(_walkTiles-1.5));
    _needsRedraw = YES;
}

- (unsigned) carTiles{
    return _carTiles;
}

- (void) setCarTiles:(unsigned int)carTiles{
    _carTiles = carTiles;
    _carLabel.position = CGPointMake(0, 16/[CCDirector sharedDirector].contentScaleFactor*(_carTiles-1.5));

    _needsRedraw = YES;
}

- (BOOL) labelsVisible{
    return _carLabel.visible && _walkLabel.visible;
}

- (void) setLabelsVisible:(BOOL)labelsVisible{
    _carLabel.visible = _walkLabel.visible = labelsVisible;
}

- (BOOL) makeCarPartDarker{
    return _makeCarPartDarker;
}

- (void) setMakeCarPartDarker:(BOOL)makeCarPartDarker{
    _makeCarPartDarker = makeCarPartDarker;
    _needsRedraw = YES;
}

#define PARKING_DARKNESS 0.1

- (void) _redrawIfNeeded{
    if(_needsRedraw){
        [self clear];
        if(_carTiles){
            [self drawDot:CGPointMake(0, 0) radius:16/[CCDirector sharedDirector].contentScaleFactor*_carTiles
                    color:[CCColor colorWithCcColor4f:ccc4f(0, 0, 0, 0.05 + (self.makeCarPartDarker ? PARKING_DARKNESS : 0))]];
            
        }
        
        if(_walkTiles){
            [self drawDot:CGPointMake(0, 0) radius:16/[CCDirector sharedDirector].contentScaleFactor*_walkTiles
                    color:[CCColor colorWithCcColor4f:ccc4f(0, 0, 0, 0.25 - (self.makeCarPartDarker ? PARKING_DARKNESS : 0))]];
        }
        
        _needsRedraw = NO;
    }
}

- (void) visit{
    [self _redrawIfNeeded];
    [super visit];
}


@end
