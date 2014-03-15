//
//  TracksNode.m
//  Transit Authority
//
//  Created by Dan Grover on 6/25/13.
//
//

#import "TracksNode.h"
#import "Utilities.h"
#import "UIColor+Cocos.h"

#import "CCDrawingPrimitives.h"

#define LINE_CLICK_THRESHOLD 30

@implementation TracksNode

- (void)draw {
    
 //   ccDrawInit();
    
    
    CGFloat pixelDistance = PointDistance(self.start, self.end);
  
    float lineWidth = 0;
    if(self.segment.lines.count == 0){ // just tracks
        // draw a dotted line?
        if(self.valid){
            lineWidth = 18;
            ccDrawColor4F(0, 0, 0, 0.3);
        }else{
            lineWidth = 10;
            ccDrawColor4F(1, 0, 0, 0.3);
        }
        
        glLineWidth(lineWidth * CC_CONTENT_SCALE_FACTOR());
        ccDrawLine(self.start, self.end);
        
    }else{
        // multi lines
        int w = MIN(20,ceil(50.0f/self.segment.lines.count));
        CGFloat offsetAmount = -1 * ((((float)self.segment.lines.count/2.0f) - 0.5) * w);
        unsigned i = 0;
        NSArray *coloredLines = [self.segment.lines.allKeys sortedArrayUsingSelector:@selector(compare:)];
        
        for(NSNumber *colorNum in coloredLines){
            glLineWidth((w/2.0f) * CC_CONTENT_SCALE_FACTOR());
            ccColor4F drawColor = [[Line uiColorForLineColor:[colorNum intValue]] c4f];
            ccDrawColor4F(drawColor.r, drawColor.g, drawColor.b, 1);
            
            CGPoint s,e;
            if(fabs(self.end.x - self.start.x) > fabs(self.end.y - self.start.y)){
                // we are drawing horizontally
                CGPoint offsettedStart = CGPointOffset(self.start, 0, offsetAmount);
                CGPoint offsettedEnd = CGPointOffset(self.end, 0, offsetAmount);
                
                s = CGPointOffset(offsettedStart, 0, i*w);
                e = CGPointOffset(offsettedEnd, 0, i*w);
            }else{
                // we are drawing vertically
                CGPoint offsettedStart = CGPointOffset(self.start, offsetAmount, 0);
                CGPoint offsettedEnd = CGPointOffset(self.end, offsetAmount, 0);
                
                s = CGPointOffset(offsettedStart, i*w, 0);
                e = CGPointOffset(offsettedEnd, i*w, 0);
            }
            
            ccDrawLine(s, e);
            
            i++;
        }
    }
    
   // ccDrawLine();
}


- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event{
    return [self _touchIsOnLine:touch];
}

- (void)ccTouchMoved:(UITouch *)touch withEvent:(UIEvent *)event{

}

- (void)ccTouchEnded:(UITouch *)touch withEvent:(UIEvent *)event{
    if([self _touchIsOnLine:touch]){
        [self.delegate tracks:self gotClicked:[touch locationInView:[CCDirector sharedDirector].view]];
    }
}

- (CGRect) lineRect{
    CGRect r = CGRectMake(MIN(self.start.x, self.end.x),
                      MIN(self.start.y, self.end.y),
                      fabs(self.start.x - self.end.x),
                      fabs(self.start.y - self.end.y));
    
    if((r.size.width < LINE_CLICK_THRESHOLD) || (r.size.height < LINE_CLICK_THRESHOLD)){
        r = CGRectInset(r, -1*LINE_CLICK_THRESHOLD, -1*LINE_CLICK_THRESHOLD);
    }
    return r;
}

- (BOOL) _touchIsOnLine:(UITouch *)touch{
    CGPoint touchLoc = [touch locationInNode:self];
    if(!CGRectContainsPoint([self lineRect], touchLoc)){
        return NO;
    }else{
        CGSize s = [self distanceFromLine:touchLoc];
        return ((s.width < LINE_CLICK_THRESHOLD) || (s.height < LINE_CLICK_THRESHOLD));
    }
}


- (CGSize) distanceFromLine:(CGPoint)touchLoc{
    float xCovered = self.end.x - self.start.x;
    float yCovered = self.end.y - self.start.y;

    float proportionAcross = (touchLoc.x - self.start.x) / xCovered;
    float proportionDown = (touchLoc.y - self.start.y) / yCovered;
    
    return CGSizeMake(fabsf((proportionDown * xCovered) + self.start.x - touchLoc.x),
                      fabsf((proportionAcross * yCovered) + self.start.y - touchLoc.y));
}

@end
