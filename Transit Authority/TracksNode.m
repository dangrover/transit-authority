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

static CCGLProgram *_trackShader;
static int _trackShaderColorLocation;

#define LINE_CLICK_THRESHOLD 30

@implementation TracksNode{
    CCPointArray *_points;
    GLuint _verticesBuffer;
    
    unsigned _numVertices;
}

- (id)init {
    if (self = [super init])
    {
        if(!_trackShader){
            _trackShader = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_Position_uColor];
            _trackShaderColorLocation = glGetUniformLocation(_trackShader.program, "u_color");
        }
        [self rebuffer];
    }
    return self;
}

- (void) rebuffer{
    
    _points = [[CCPointArray alloc] initWithCapacity:2];
    [_points addControlPoint:self.start];
    [_points addControlPoint:CGPointMake(self.start.x, self.end.y)];
    [_points addControlPoint:self.end];
    
    _numVertices = _points.count * 3;
    ccVertex2F vertices[_numVertices + 1];
    
	NSUInteger p;
	CGFloat lt;
	CGFloat deltaT = 1.0 / [_points count];
    
    for( NSUInteger i=0; i < _numVertices+1;i++) {
		
		CGFloat dt = (CGFloat)i / _numVertices;
        
		// border
		if( dt == 1 ) {
			p = [_points count] - 1;
			lt = 1;
		} else {
			p = dt / deltaT;
			lt = (dt - deltaT * (CGFloat)p) / deltaT;
		}
		
		// Interpolate
		CGPoint pp0 = [_points getControlPointAtIndex:p-1];
		CGPoint pp1 = [_points getControlPointAtIndex:p+0];
		CGPoint pp2 = [_points getControlPointAtIndex:p+1];
		CGPoint pp3 = [_points getControlPointAtIndex:p+2];
		
		CGPoint newPos = ccCardinalSplineAt( pp0, pp1, pp2, pp3, 0.5, lt);
		vertices[i].x = newPos.x;
		vertices[i].y = newPos.y;
	}

    glGenBuffers(1, &_verticesBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);
}

- (void) dealloc{
    glDeleteBuffers(1, &(_verticesBuffer));
}

- (void)draw {
    
    float lineWidth = 0;
    
    ccColor4F lineColor;
    
    // draw a dotted line?
    if(self.valid){
        lineWidth = 18;
        lineColor = ccc4f(0, 0, 0, 0.3);
    }else{
        lineWidth = 10;
        lineColor = ccc4f(1, 0, 0, 0.3);
    }
    
    glLineWidth(lineWidth * CC_CONTENT_SCALE_FACTOR());
    //ccDrawLine(self.start, self.end);
    
    [_trackShader use];
    [_trackShader setUniformsForBuiltins];
    [_trackShader setUniformLocation:_trackShaderColorLocation with4fv:(GLfloat*) &lineColor.r count:1];
    
    ccGLEnableVertexAttribs( kCCVertexAttribFlag_Position );
    
    glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffer);
    glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_LINE_STRIP, 0, (GLsizei) _numVertices + 1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);

    
    /*if(self.segment.lines.count == 0){ // just tracks
     

    
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
    }*/
    
    ccDrawFree();
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
    CGPoint touchLoc = [self convertTouchToNodeSpace:touch];
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
