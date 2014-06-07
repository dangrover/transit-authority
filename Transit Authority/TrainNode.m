//
//  TrainNode.m
//  Transit Authority
//
//  Created by Dan Grover on 7/31/13.
//
//

#import "TrainNode.h"

@interface TrainNode()

@end

@implementation TrainNode{
    LineColor _color;
    BOOL _initialColorSet;
    CCLabelTTF *_countLabel;
    CCSprite *_emptyProgress;
    CCSprite *_fullProgress;
    
    unsigned _count;
    unsigned _capacity;
    CCProgressNode *_progressTimer;
}

- (id) init{
    if(self = [super initWithTexture:[self _textureForColor:LineColor_Red]]){
        _countLabel = [[CCLabelTTF alloc] initWithString:@""
                                                    fontName:@"Helvetica-Bold"
                                                    fontSize:11.0];
        
        _emptyProgress = [[CCSprite alloc] initWithImageNamed:@"progress-indicator-empty.png"];
        _fullProgress = [[CCSprite alloc] initWithImageNamed:@"progress-indicator-full.png"];
        
        _progressTimer = [[CCProgressNode alloc] initWithSprite:_fullProgress];
        _progressTimer.type = CCProgressNodeTypeRadial;
       
        
        _countLabel.anchorPoint = _emptyProgress.anchorPoint = _progressTimer.anchorPoint = CGPointMake(0.5, 0.5);
       
      //  [_countLabel enableShadowWithOffset:CGSizeMake(0, -1) opacity:1 blur:0 updateImage:NO];
        //[_countLabel setFontFillColor:ccWHITE updateImage:NO];
        
        [self addChild:_emptyProgress];
        [self addChild:_progressTimer];
        [self addChild:_countLabel];
    }
    
    return self;
}


- (LineColor) color{
    return _color;
}

- (void) setColor:(LineColor)color{
    if((_color != color) || !_initialColorSet){
        
        self.texture = [self _textureForColor:color];
        _countLabel.position = CGPointMake(self.contentSize.width / 2, self.contentSize.height/3*2);
        _emptyProgress.position = _progressTimer.position = _countLabel.position;
        _color = color;
        _initialColorSet = YES;
    }
}

- (unsigned) count{
    return _count;
}

- (void) setCount:(unsigned)newCount{
    _count = newCount;
    
    _countLabel.string = [NSString stringWithFormat:@"%d",newCount];
    
    [self _updateProgress];
}

- (unsigned) capacity{
    return _capacity;
}

- (void) setCapacity:(unsigned)newCapacity{
    _capacity = newCapacity;
    [self _updateProgress];
}

- (void) _updateProgress{
    _progressTimer.percentage = (float)_count/(float)_capacity * 100.0f;
}

- (CCTexture *) _textureForColor:(LineColor)c{
    return [CCTexture textureWithFile:[NSString stringWithFormat:@"train-pin-%d.png",c]];
    //return [[CCTextureCache sharedTextureCache] addImage: [NSString stringWithFormat:@"train-pin-%d.png",c]];
}

@end
