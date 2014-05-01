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

// Take a line of control points and return an interpolated spline line.
void splineInterpolate(CCPointArray *points, int numVertices, ccVertex2F *vertices)
{
	NSUInteger p;
	CGFloat lt;
	CGFloat deltaT = 1.0 / [points count];
    
    for( NSUInteger i=0; i < numVertices;i++) {
		
		// Interpolate with x values between given control points
		CGFloat dt = (CGFloat)i / numVertices;
		if( dt == 1 ) {
			p = [points count] - 1;
			lt = 1;
		} else {
			p = dt / deltaT;
			lt = (dt - deltaT * (CGFloat)p) / deltaT;
		}
		
		// Use surrounding control points.
		CGPoint pp0 = [points getControlPointAtIndex:p-1];
		CGPoint pp1 = [points getControlPointAtIndex:p+0];
		CGPoint pp2 = [points getControlPointAtIndex:p+1];
		CGPoint pp3 = [points getControlPointAtIndex:p+2];
		
        // Create interpolated line.
		CGPoint newPos = ccCardinalSplineAt( pp0, pp1, pp2, pp3, 0.5, lt);
		vertices[i].x = newPos.x;
		vertices[i].y = newPos.y;
	}
}

@implementation TracksNode{
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

/*
     Two ways to draw a track from point A to point B:
 
     Diagonal first:   /------ B     Flat part first:           B
                      /                                        /
                     A                                A ------/
*/
#define DIAGONAL_FIRST 1
#define DIAGONAL_LAST 2

// Calculate line segments making up the track and return the control points necessary to draw a rounded elbow.
- (CCPointArray *) curvyLineFromPoint:(CGPoint)a
                              toPoint:(CGPoint)b
                                style:(int)style
{
    // Point a and b are two ordered points, as in the diagrams above.
    // Let point f be the one on the flat line, and d the one on the diagonal.
    CGPoint f = (style == DIAGONAL_FIRST) ? a : b;
    CGPoint d = (style != DIAGONAL_FIRST) ? a : b;
    
    CGPoint elbow;
    if (abs(f.x-d.x) < abs(f.y-d.y))
    {
        // Flat component of diagonal line component is longer
        elbow = PointTowardsPoint(CGPointMake(d.x, f.y), d, abs(d.x-f.x));
    }
    else
    {
        // Flat line is longer
        elbow = PointTowardsPoint(CGPointMake(f.x, d.y), d, abs(d.y-f.y));
    }
    
    // Put two control points on either side of the elbow, but not on the elbow.
    // When we spline this it will make a nice curve.
    CCPointArray *points = [[CCPointArray alloc] init];
    [points addControlPoint:PointTowardsPoint(elbow, a, 20)];
    [points addControlPoint:PointTowardsPoint(elbow, a, 10)];
    [points addControlPoint:PointTowardsPoint(elbow, b, 10)];
    [points addControlPoint:PointTowardsPoint(elbow, b, 20)];
    
    return points;
}

- (void) rebuffer{
    
    int style = DIAGONAL_FIRST;
    
    int lineWidth = self.valid ? 18 : 10;

    // We draw thick lines by shifting the endpoints in the x or y directions.
    // A horizontal or vertical line has a shift coefficient of 1.
    // A line at a 45 degree angle has a shift of about 1.4.
    float diagThickness = 1 / cos(3.1415/4);
    float aThickness = (style == DIAGONAL_FIRST) ? diagThickness : 1;
    float bThickness = (style != DIAGONAL_FIRST) ? diagThickness : 1;
    
    // Shift a->b in order to make two edges of a thick line.
    CGPoint a1 = self.start, a2 = self.start, b1 = self.end, b2 = self.end;
    CCPointArray *elbow1CtlPoints, *elbow2CtlPoints;
    if (abs(self.end.x-self.start.x) < abs(self.end.y-self.start.y))
    {
        // Vertical component is larger.
        // Shift lines a2->b2 and a1->b1 apart horizontally.
        a1 = CGPointOffset(a1, -lineWidth*aThickness/2, 0);
        b1 = CGPointOffset(b1, -lineWidth*bThickness/2, 0);
        a2 = CGPointOffset(a2, lineWidth*aThickness/2, 0);
        b2 = CGPointOffset(b2, lineWidth*bThickness/2, 0);
    }
    else
    {
        // Horizontal component is larger.
        // Shift lines a2->b2 and a1->b1 apart vertically.
        a1 = CGPointOffset(a1, 0, -lineWidth*aThickness/2);
        b1 = CGPointOffset(b1, 0, -lineWidth*bThickness/2);
        a2 = CGPointOffset(a2, 0, lineWidth*aThickness/2);
        b2 = CGPointOffset(b2, 0, lineWidth*bThickness/2);
    }
    
    elbow1CtlPoints = [self curvyLineFromPoint:a1 toPoint:b1 style:style];
    elbow2CtlPoints = [self curvyLineFromPoint:a2 toPoint:b2 style:style];
    
    // Interpolate the control points to make a nice round elbow.
    int verticesToAdd = elbow1CtlPoints.count*2;
    _numVertices = 2*verticesToAdd + 4;
    ccVertex2F elbow1[verticesToAdd], elbow2[verticesToAdd], polygon[_numVertices];
    splineInterpolate(elbow1CtlPoints, verticesToAdd, elbow1);
    splineInterpolate(elbow2CtlPoints, verticesToAdd, elbow2);
    
    // Combine two edges and elbows to make a polygon.
    
    polygon[0].x = a1.x;
    polygon[0].y = a1.y;
    polygon[1].x = a2.x;
    polygon[1].y = a2.y;
    
    // Zip points from the two elbows together.
    int i;
    for (i = 0; i < verticesToAdd; i++)
    {
        polygon[2 + 2*i] = elbow1[i];
        polygon[2 + 2*i + 1] = elbow2[i];
    }
    
    polygon[2*verticesToAdd+2].x = b1.x;
    polygon[2*verticesToAdd+2].y = b1.y;
    polygon[2*verticesToAdd+3].x = b2.x;
    polygon[2*verticesToAdd+3].y = b2.y;
    
    glGenBuffers(1, &_verticesBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(polygon), polygon, GL_STATIC_DRAW);
}

- (void) dealloc{
    glDeleteBuffers(1, &(_verticesBuffer));
}

- (void)draw {
    
    ccColor4F lineColor = self.valid ? ccc4f(0, 0, 0, 0.3) : ccc4f(1, 0, 0, 0.3);
    
    [_trackShader use];
    [_trackShader setUniformsForBuiltins];
    [_trackShader setUniformLocation:_trackShaderColorLocation with4fv:(GLfloat*) &lineColor.r count:1];
    
    ccGLEnableVertexAttribs( kCCVertexAttribFlag_Position );
    
    glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffer);
    glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, 0);
    glDrawArrays(GL_TRIANGLE_STRIP, 0, (GLsizei) _numVertices);
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
