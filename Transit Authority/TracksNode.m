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
// This function must always return the same amount of points however many times it's called.
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
    GLuint *_verticesBuffers;
    NSLock *bufferingLock;
    unsigned _numLines;
    unsigned _numVertices;
    ccColor4F *_colors;
}

- (id)init {
    if (self = [super init])
    {
        if(!_trackShader){
            _trackShader = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_Position_uColor];
            _trackShaderColorLocation = glGetUniformLocation(_trackShader.program, "u_color");
        }
        
        // Create an array to hold up to 20 buffers.
        _verticesBuffers = (GLuint *)malloc(sizeof(GLuint)*20);
        
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
    CCPointArray *points = [CCPointArray arrayWithCapacity:4];
    [points addControlPoint:PointTowardsPoint(elbow, a, 20)];
    [points addControlPoint:PointTowardsPoint(elbow, a, 10)];
    [points addControlPoint:PointTowardsPoint(elbow, b, 10)];
    [points addControlPoint:PointTowardsPoint(elbow, b, 20)];
    
    return points;
}

- (void) rebuffer{
    
    //[bufferingLock lock];
    
    glDeleteBuffers(_numLines, _verticesBuffers);
    _numLines = self.segment.lines.count;
    glGenBuffers(_numLines, _verticesBuffers);
    
    int style = DIAGONAL_FIRST;
    int lineWidth;

    free(_colors);
    if (_numLines == 0) // just tracks
    {
        _numLines = 1;
        lineWidth = self.valid ? 18 : 10;
        
        _colors = (ccColor4F *)malloc(sizeof(ccColor4F));
        _colors[0] = self.valid ? ccc4f(0, 0, 0, 0.3) : ccc4f(1, 0, 0, 0.3);
    }
    else // multi lines
    {
        lineWidth = MIN(20,ceil(50.0f/self.segment.lines.count));
        
        NSArray *coloredLines = [self.segment.lines.allKeys sortedArrayUsingSelector:@selector(compare:)];
        _colors = (ccColor4F *)malloc(sizeof(ccColor4F)*(_numLines));
        int i;
        for (i = 0; i < _numLines; i++) {
            NSNumber *colorNum = [coloredLines objectAtIndex:i];
            _colors[i] = [[Line uiColorForLineColor:[colorNum intValue]] c4f];
        }
    }

    // We draw thick lines by shifting the endpoints in the x or y directions.
    // A horizontal or vertical line has a shift coefficient of 1.
    // A line at a 45 degree angle has a shift of about 1.4.
    float diagThickness = 1 / cos(3.1415/4);
    float aThickness = (style == DIAGONAL_FIRST) ? diagThickness : 1;
    float bThickness = (style != DIAGONAL_FIRST) ? diagThickness : 1;
    
    // Shift a->b in order to make two edges of a thick line.
    int numEdges = _numLines + 1;
    CGPoint a = self.start, b = self.end;
    CGPoint as[numEdges], bs[numEdges];
    ccVertex2F *elbows[numEdges];
    
    int numVertices, numElbowVertices;
    int i;
    for (i = 0; i < numEdges; i++)
    {
        
        // Position this edge in relatino to the other edges.
        if (abs(self.end.x-self.start.x) < abs(self.end.y-self.start.y))
        {
            // Vertical component is larger.
            // Shift lines a2->b2 and a1->b1 apart horizontally.
            as[i] = CGPointOffset(a, (lineWidth*aThickness)*(i-_numLines*.5), 0);
            bs[i] = CGPointOffset(b, (lineWidth*bThickness)*(i-_numLines*.5), 0);
        }
        else
        {
            // Horizontal component is larger.
            // Shift lines a2->b2 and a1->b1 apart vertically.
            as[i] = CGPointOffset(a, 0, (lineWidth*aThickness)*(i-_numLines*.5));
            bs[i] = CGPointOffset(b, 0, (lineWidth*bThickness)*(i-_numLines*.5));
        }
        
        // Calculate where the elbow should be.
        CCPointArray *elbowCtlPoints = [self curvyLineFromPoint:as[i] toPoint:bs[i] style:style];
        // Interpolate the points to make a nice round elbow.
        numElbowVertices = elbowCtlPoints.count;
        numVertices = numElbowVertices*2 + 4;
        
        //NSLog(@"ALLOC ELBOW %d", i);
        elbows[i] = (ccVertex2F *)malloc(sizeof(ccVertex2F)*numElbowVertices);
        splineInterpolate(elbowCtlPoints, numElbowVertices, elbows[i]);
        
        if (i > 0)
        {
            ccVertex2F polygon[numVertices];
            
            // Combine two edges and elbows to make a polygon.
            
            polygon[0].x = as[i-1].x;
            polygon[0].y = as[i-1].y;
            polygon[1].x = as[i].x;
            polygon[1].y = as[i].y;
            
            // Zip points from the two elbows together.
            int t;
            for (t = 0; t < numElbowVertices; t++)
            {
                polygon[2 + 2*t] = elbows[i-1][t];
                polygon[2 + 2*t + 1] = elbows[i][t];
            }
            
            polygon[numVertices-2].x = bs[i-1].x;
            polygon[numVertices-2].y = bs[i-1].y;
            polygon[numVertices-1].x = bs[i].x;
            polygon[numVertices-1].y = bs[i].y;
            
            glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffers[i-1]);
            glBufferData(GL_ARRAY_BUFFER, sizeof(polygon), polygon, GL_STATIC_DRAW);

            //NSLog(@"filled buffer [%d] %d of %d (%d vertices)", _verticesBuffers[i-1], i, _numLines, numVertices);
        }
    }
    
    for (int i = 0; i < numEdges; i++)
    {
        //NSLog(@"FREE ELBOW %d", i);
        free(elbows[i]);
    }
    
    _numVertices = numVertices;
    
    [bufferingLock unlock];
}

- (void) dealloc{
    glDeleteBuffers(_numLines, _verticesBuffers);
}

- (void)draw {
    
    [bufferingLock lock];

    [_trackShader use];
    [_trackShader setUniformsForBuiltins];
    
    ccGLEnableVertexAttribs( kCCVertexAttribFlag_Position );
    
    int i;
    for (i = 0; i < _numLines; i++)
    {
        [_trackShader setUniformLocation:_trackShaderColorLocation with4fv:&_colors[i] count:1];

        //NSLog(@"drawing buffer %d with %d vertices", i+1, _numVertices);
        glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffers[i]);
        glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, 0);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, (GLsizei) _numVertices);
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
    
    ccDrawFree();
    
    [bufferingLock unlock];
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
