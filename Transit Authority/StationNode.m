//
//  StationNode.m
//  Transit Authority
//
//  Created by Dan Grover on 7/13/13.
//
//

#import "StationNode.h"

@implementation StationNode{
    CCLabelTTF *_countLabel;
    CCSprite *_dot;
    NSArray *_glyphs;
    NSMutableDictionary *_glyphSprites;
}

- (id) init{
    if(self = [super init]){
        _dot = [[CCSprite alloc] initWithImageNamed:@"station.png"];
        [self addChild:_dot];
        
        _countLabel = [[CCLabelTTF alloc] initWithString:@"" fontName:@"Raleway-Light" fontSize:18];
        _countLabel.anchorPoint = CGPointMake(0.5, 0.5);
        _countLabel.position = CGPointMake(_dot.contentSize.width/2, _dot.contentSize.height / 2);
        _countLabel.color = [CCColor colorWithWhite:0.15 alpha:1];
        [_dot addChild:_countLabel];
        
        self.passengerCount = 0;
        _glyphSprites = [NSMutableDictionary dictionary];
        
        self.userInteractionEnabled = YES;
     //   self.claimsUserInteraction = YES;
    }
    
    return self;
}

- (void) setPassengerCount:(int)passengerCount{
    _countLabel.string = [NSString stringWithFormat:@"%d",passengerCount];
}

- (int) passengerCount{
    return [_countLabel.string integerValue];
}


- (BOOL)hitTestWithWorldPos:(CGPoint)pos{
    return CGRectContainsPoint(_dot.boundingBox, [self convertToNodeSpace:pos]);
}

- (void) touchBegan:(UITouch *)touch withEvent:(UIEvent *)event{
 //   return CGRectContainsPoint(_dot.boundingBox, [touch locationInNode:self]);
}

- (void) touchMoved:(UITouch *)touch withEvent:(UIEvent *)event{
    
}

- (void) touchEnded:(UITouch *)touch withEvent:(UIEvent *)event{
    if(CGRectContainsPoint(_dot.boundingBox, [touch locationInNode:self])){
        [self.delegate stationNodeClicked:self];
    }
}

- (NSArray *) glyphsToDisplay{
    return _glyphs;
}

- (float) dotScale{
    return _dot.scale;
}

- (void) setDotScale:(float)dotScale{
    _dot.scale = dotScale;
}


- (void) setScale:(float)scale{
    float oldDotScale = self.dotScale;
    [super setScale:scale];
    self.dotScale = oldDotScale;
}

- (void) setGlyphsToDisplay:(NSArray *)glyphsToDisplay{
    _glyphs = glyphsToDisplay;
    
    // remove sprites we don't need
    for(NSString *path in _glyphSprites.allKeys){
        if(![_glyphs containsObject:path]){
            [self removeChild:_glyphSprites[path]];
            [_glyphSprites removeObjectForKey:path];
        }
    }
    
    // create sprites
    for(NSString *path in _glyphs){
        CCSprite *s = _glyphSprites[path];
        if(!s){
            CCSprite *s = [[CCSprite alloc] initWithImageNamed:path];
            _glyphSprites[path] = s;
            s.scale = 0.6;
            s.anchorPoint = CGPointMake(0.5, 0.5);
            [self addChild:s];
        }
    }
    
    // position all of them
    float xCursor = _dot.boundingBox.size.width/2.0 + 7;
    for(NSString *p in _glyphs){
        CCSprite *s = _glyphSprites[p];
        s.position = CGPointMake(xCursor, 0);
        xCursor += s.contentSize.width*s.scale + 4;
    }
}


@end
