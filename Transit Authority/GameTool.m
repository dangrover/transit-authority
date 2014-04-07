//
//  GameTool.m
//  Transit Authority
//
//  Created by Dan Grover on 6/25/13.
//
//

#import "GameTool.h"
#import "MainGameScene.h"
#import "Utilities.h"
#import "CCLabelTTF.h"


@implementation GameTool{
    BOOL _validMove;
}

- (BOOL) touchBegan:(UITouch *)touch withEvent:(UIEvent *)event{
    costLabel = [[CCLabelTTF alloc] initWithString:@"" fontName:@"Helvetica-Bold" fontSize:20];
 //   [costLabel enableShadowWithOffset:CGSizeMake(0, 1) opacity:1 blur:2 updateImage:NO];
    [self.parent addChild:costLabel z:95];
    
    return YES;
}

- (void) touchMoved:(UITouch *)touch withEvent:(UIEvent *)event{
    CGPoint pos = [touch locationInNode:self.parent];
    costLabel.position = CGPointOffset(pos, 90, 0);
}

- (void) touchEnded:(UITouch *)touch withEvent:(UIEvent *)event{
    [self.parent removeChild:costLabel cleanup:YES];
}

- (void) touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event{
    [self.parent removeChild:costLabel cleanup:YES];
}

- (NSString *) helpText{
    return @"Not implemented";
}

- (BOOL) showsHelpText{
    return YES;
}

- (void) started{
    
}

- (void) finished{
    
}

- (BOOL) allowsPanning{
    return NO;
}

- (void) setValidMove:(BOOL)validMove{
    _validMove = validMove;
   // [costLabel setFontFillColor:validMove ? ccc3(255, 255, 255) : ccc3(255, 0, 0) updateImage:YES];
}

- (BOOL) validMove{
    return _validMove;
}
@end