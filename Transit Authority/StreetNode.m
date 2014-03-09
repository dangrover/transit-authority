//
//  StreetNode.m
//  Transit Authority
//
//  Created by Dan Grover on 7/15/13.
//
//

#import "StreetNode.h"

static CCGLProgram *_streetShader;
static int _streetShaderColorLocation;

@implementation StreetNode{
    CGPoint _base;
    CCPointArray *_points;
    CGRect _bbox;
    GLuint _verticesBuffer;
    
    unsigned _numVertices;
    ccColor4F _lineColor;
    unsigned _lineThickness;
    
}

- (id) initWithBase:(CGPoint)base points:(NSString *)polylinePoints type:(StreetType)theType;{
    if(self = [super init]){
        _base = base;
        
        NSArray *pairs = [polylinePoints componentsSeparatedByString:@" "];
        _points = [[CCPointArray alloc] initWithCapacity:[pairs count]];
        
        CGFloat minX = 0;
        CGFloat maxX = 0;
        CGFloat minY = 0;
        CGFloat maxY = 0;
        BOOL first = YES;
        for(NSString *pair in pairs){
            NSArray *xy = [pair componentsSeparatedByString:@","];
            NSAssert(xy.count == 2, @"malformed coordinates");
            CGPoint p = CGPointMake([((NSString *)xy[0]) floatValue] + _base.x,
                                    _base.y - [((NSString *)xy[1]) floatValue]);
            
            [_points addControlPoint:p];
            
            if(first){
                minX = p.x;
                minY = p.y;
                maxX = p.x;
                maxY = p.y;
                first = NO;
            }else{
                maxX = MAX(maxX, p.x);
                maxY = MAX(maxY, p.y);
                minX = MIN(minX, p.x);
                minY = MIN(minY, p.y);
            }
        }
        
        _bbox = CGRectMake(minX, minY, maxX - minX, maxY - minY);
   
        if(theType == StreetType_Highway){
            _lineColor = ccc4f(1.000, 1.000, 0.815, 1.000);
            _lineThickness = 15;
        }else if(theType == StreetType_Railroad){
            _lineColor = ccc4f(0,0,0,0.25);
            _lineThickness = 2;
        }else{
            _lineColor = ccc4f(1, 1, 1, 0.5);
            _lineThickness = 5;
        }
        
        if(!_streetShader){
            _streetShader = [[CCShaderCache sharedShaderCache] programForKey:kCCShader_Position_uColor];
            _streetShaderColorLocation = glGetUniformLocation(_streetShader.program, "u_color");
        }
        
        [self _generateVerticesBuffer];
    }
    
    
    return self;
}




- (void) _generateVerticesBuffer{
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
		
		CGPoint newPos = CCCardinalSplineAt( pp0, pp1, pp2, pp3, 0.5, lt);
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


- (CGRect) boundingBox{
    return _bbox;
}


- (void)draw {
    if([_points count] < 2) return;

    glLineWidth(_lineThickness);
    [_streetShader use];
    [_streetShader setUniformsForBuiltins];
    [_streetShader setUniformLocation:_streetShaderColorLocation with4fv:(GLfloat*) &_lineColor.r count:1];

    ccGLEnableVertexAttribs( kCCVertexAttribFlag_Position );
    
    glBindBuffer(GL_ARRAY_BUFFER, _verticesBuffer);
	glVertexAttribPointer(kCCVertexAttrib_Position, 2, GL_FLOAT, GL_FALSE, 0, 0);
	glDrawArrays(GL_LINE_STRIP, 0, (GLsizei) _numVertices + 1);
    glBindBuffer(GL_ARRAY_BUFFER, 0);
}
@end
