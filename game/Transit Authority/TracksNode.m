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
#import "TrainPath.h"

static CCGLProgram *_trackShader;
static int _trackShaderColorLocation;

#define LINE_CLICK_THRESHOLD 25

#define INVALID_LINE_WIDTH 10
#define LINE_WIDTH 30
#define MAX_TRACK_WIDTH 40

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
        
		CGPoint newPos = CCCardinalSplineAt( pp0, pp1, pp2, pp3, 0.5, lt);
		vertices[i].x = newPos.x;
		vertices[i].y = newPos.y;
	}
}

@implementation TracksNode{
    GLuint *_verticesBuffers;
    NSLock *bufferingLock;
    unsigned _numLines;
    unsigned _numVertices;
    NSArray *_colors;
}

- (id)init {
    if (self = [super init])
    {
        if(!_trackShader){
            _trackShader = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_Position_uColor];
            _trackShaderColorLocation = glGetUniformLocation(_trackShader.program, "u_color");
        }
        
        // Create an array to hold up to 20 buffers. We'll have one for every line on the track.
        _verticesBuffers = (GLuint *)malloc(sizeof(GLuint)*20);
        
        _trainPaths = [[NSMutableArray alloc] init];
        
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
- (CGPoint) elbowBetweenPoint:(CGPoint)a
                     andPoint:(CGPoint)b
                        style:(int)style
{
    // Point a and b are two ordered points, as in the diagrams above.
    // Let point f be the one on the flat line, and d the one on the diagonal.
    CGPoint f = (style == DIAGONAL_FIRST) ? a : b;
    CGPoint d = (style != DIAGONAL_FIRST) ? a : b;
    
    if (abs(f.x-d.x) < abs(f.y-d.y))
    {
        // Flat component of diagonal line component is longer
        return PointTowardsPoint(CGPointMake(d.x, f.y), d, abs(d.x-f.x));
    }
    else
    {
        // Flat line is longer
        return PointTowardsPoint(CGPointMake(f.x, d.y), d, abs(d.y-f.y));
    }
}

- (void) rebuffer{
    
    [bufferingLock lock];
    
    int style = DIAGONAL_FIRST;
    int lineWidth;
    
    // Each buffer corresponds to one colored strip in the visible track between two stations.
    glDeleteBuffers(_numLines, _verticesBuffers);
    _numLines = max(self.segment.lines.count,1);
    glGenBuffers(_numLines, _verticesBuffers);
    
    // One train path corresponds to the line that an animated train follows on a track.
    [_trainPaths removeAllObjects];
    
    if (self.segment.lines.count == 0) // just tracks
    {
        lineWidth = self.valid ? LINE_WIDTH : INVALID_LINE_WIDTH;
        
        _colors = [NSArray arrayWithObject: self.valid ? [UIColor colorWithRed:0 green:0 blue:0 alpha:0.3] : [UIColor colorWithRed:1 green:0 blue:0 alpha:0.3]];
    }
    else
    {
        // When a track has multiple lines, the total width should be limited.
        lineWidth = MIN(LINE_WIDTH,ceil(MAX_TRACK_WIDTH/self.segment.lines.count));
        
        // Convert the LineColors to UIColors:
        int i;
        NSArray *lineColors = [self.segment.lines.allKeys sortedArrayUsingSelector:@selector(compare:)];
        NSMutableArray *colors = [NSMutableArray array];
        for (i = 0; i < self.segment.lines.count; i++)
        {
            NSNumber *colorNum = [lineColors objectAtIndex:i];
            [colors addObject:[Line uiColorForLineColor:[colorNum intValue]]];
        }
        _colors = [NSArray arrayWithArray:colors];
    }
    
    // The line a->b goes from station A to station B.
    // The lines as[0]->bs[0], etc. will be used to draw thick colored lines roughly parallel to a->b.
    int numEdges = _numLines*2 + 1;
    CGPoint a = self.start, b = self.end;
    CGPoint as[numEdges], bs[numEdges];
    ccVertex2F *elbows[numEdges];
    
    // Calculate where the elbow of a->b is.
    CGPoint mainElbow = [self elbowBetweenPoint:a andPoint:b style:style];
    // Calculate the angle of the line segments so we can draw ends on them.
    float endAngleA = AngleBetweenPoints(a, mainElbow) + M_PI_2;
    float endAngleB = AngleBetweenPoints(b, mainElbow) - M_PI_2;
    // Check whether the elbow is at one of the the ends.
    bool segmentAExists = PointDistance(a, mainElbow) > 0;
    bool segmentBExists = PointDistance(b, mainElbow) > 0;
    // If there is no elbow:
    if (!segmentAExists)
    {
        endAngleA = endAngleB;
    }
    else if (!segmentBExists)
    {
        endAngleB = endAngleA;
    }
    
    int numVertices, numElbowVertices;
    for (int i = 0; i < numEdges; i++)
    {
        // Offset as[i]->bs[i] line away from a->b by a multiple of lineWidth/2.
        // Thus lines 0, 2, etc. are the edges of colored lines, and lines 1, 3, etc. are the centers of colored lines.
        float offset = lineWidth*(i-1.0*_numLines)*.5;
        // The flat ends of the line match the direction that the line comes in from the elbow.
        as[i] = PointTowardsAngle(a, endAngleA, offset);
        bs[i] = PointTowardsAngle(b, endAngleB, offset);
        
        // Calculate where the elbow of as[i]->bs[i] edge should be.
        CGPoint elbow = [self elbowBetweenPoint:as[i] andPoint:bs[i] style:style];
        
        // Put two control points on either side of the elbow, but not on the elbow.
        // When we spline this it will make a nice curve.
        CCPointArray *elbowCtlPoints = [CCPointArray arrayWithCapacity:6];
        [elbowCtlPoints addControlPoint:PointTowardsPoint(elbow, as[i], 20)];
        [elbowCtlPoints addControlPoint:PointTowardsPoint(elbow, as[i], 20)];
        [elbowCtlPoints addControlPoint:PointTowardsPoint(elbow, as[i], 5)];
        [elbowCtlPoints addControlPoint:PointTowardsPoint(elbow, bs[i], 5)];
        [elbowCtlPoints addControlPoint:PointTowardsPoint(elbow, bs[i], 20)];
        [elbowCtlPoints addControlPoint:PointTowardsPoint(elbow, bs[i], 20)];
        
        // Spline interpolate the points to make a nice round elbow.
        numElbowVertices = elbowCtlPoints.count * 10;
        numVertices = numElbowVertices*2 + 4;
        elbows[i] = (ccVertex2F *)malloc(sizeof(ccVertex2F)*numElbowVertices);
        splineInterpolate(elbowCtlPoints, numElbowVertices, elbows[i]);
        
        if (i > 0)
        {
            if (i%2==0)
            {
                ccVertex2F polygon[numVertices];
                
                // Combine two edges and elbows to make a polygon.
                
                // First straight part:
                polygon[0].x = as[i-2].x; // Edge 1
                polygon[0].y = as[i-2].y;
                polygon[1].x = as[i].x; // Edge 2
                polygon[1].y = as[i].y;
                
                // Zip points from the two elbows (curved part) together.
                for (int t = 0; t < numElbowVertices; t++)
                {
                    polygon[2 + 2*t] = elbows[i-2][t]; // Edge 1
                    polygon[2 + 2*t + 1] = elbows[i][t]; // Edge 2
                }
                
                // Second straight part:
                polygon[numVertices-2].x = bs[i-2].x; // Edge 1
                polygon[numVertices-2].y = bs[i-2].y;
                polygon[numVertices-1].x = bs[i].x; // Edge 2
                polygon[numVertices-1].y = bs[i].y;
                
                glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffers[i/2-1]);
                glBufferData(GL_ARRAY_BUFFER, sizeof(polygon), polygon, GL_STATIC_DRAW);
                
                //NSLog(@"filled buffer [%d] %d of %d (%d vertices)", _verticesBuffers[i-1], i, _numLines, numVertices);
            }
            else
            {
                NSMutableArray *points = [NSMutableArray array];
                
                [points addObject:[NSValue valueWithCGPoint:as[i]]];
                for (int t = 0; t < numElbowVertices; t++)
                {
                    [points addObject:[NSValue valueWithCGPoint:CGPointMake(elbows[i][t].x, elbows[i][t].y)]];
                }
                [points addObject:[NSValue valueWithCGPoint:bs[i]]];
                
                TrainPath *path = [[TrainPath alloc] initWithControlPoints:points];
                [_trainPaths addObject:path];
            }
        }
    }
    
    for (int i = 0; i < numEdges; i++)
    {
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
        ccColor4F color = [[_colors objectAtIndex:i] c4f];
        
        [_trackShader setUniformLocation:_trackShaderColorLocation with4fv:&color count:1];
        
        //NSLog(@"drawing buffer [%d] %d with %d vertices", _verticesBuffers[i], i, _numVertices);
        glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffers[i]);
        glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, 0);
        glDrawArrays(GL_TRIANGLE_STRIP, 0, (GLsizei) _numVertices); // GL_LINE_STRIP for debugging
        glBindBuffer(GL_ARRAY_BUFFER, 0);
    }
    
    ccDrawFree();
    
    [bufferingLock unlock];
}

- (int)lineCount
{
    return _trainPaths.count;
}

- (CGPoint)coordForTrainAtPosition:(double)position
                            onLine:(int)line {
    return [[_trainPaths objectAtIndex:line] coordinatesAtPosition:position];
}

- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event{
 //   return [self _touchIsOnLine:touch];
}

- (BOOL) hitTestWithWorldPos:(CGPoint)pos{
    return [self _touchIsOnLine:[self convertToNodeSpace:pos]];
}

- (void)touchMoved:(UITouch *)touch withEvent:(UIEvent *)event{
    
}

- (void)touchEnded:(UITouch *)touch withEvent:(UIEvent *)event{
    if([self _touchIsOnLine:[touch locationInNode:self]]){
        [self.delegate tracks:self gotClicked:[touch locationInView:[CCDirector sharedDirector].view]];
    }
}

- (BOOL) _touchIsOnLine:(CGPoint)touchLoc{
    
    // Accurate way of testing track touches. See if the touch comes close (within LINE_CLICK_THRESHOLD) to any train path.
    
   // CGPoint touchLoc = [touch locationInNode:self];
    for (int i = 0; i < _trainPaths.count; i++)
    {
        if ([_trainPaths[i] distanceToPoint:touchLoc] < LINE_CLICK_THRESHOLD) return YES;
    }
    return NO;
}

@end