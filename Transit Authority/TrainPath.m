//
//  TrainPath.m
//  Transit Authority
//
//  Created by James Murdza on 5/17/14.
//  Copyright (c) 2014 Brown Bag Software LLC. All rights reserved.
//

#import "TrainPath.h"
#import "Utilities.h"

@implementation TrainPath

- (id)initWithControlPoints:(NSArray *)controlPoints
{
    if (self = [super init])
    {
        // These points make up a curve.
        _controlPoints = controlPoints;
        
        // Add up the distance between consecutive points on the curve.
        float distance = 0;
        for (int i = 0; i < _controlPoints.count-1; i++)
        {
            distance += PointDistance([_controlPoints[i] CGPointValue], [_controlPoints[i+1] CGPointValue]);
        }
        _length = distance;
    }
    
    return self;
}

// Give the position to draw the train at, interpolating between the closest two points on the path.
- (CGPoint)coordinatesAtPosition:(float)position
{
    // The absolute distance the train has moved along the path.
    // From this distance we will find the location of the train between the first and last points.
    float distanceTravelled = position * self.length;
    
    // Travel along the curve, increasing i until the train location is between control point i and control point i+1
    
    float distanceToPointI = 0;
    float distanceToNextPoint = 0;
    
    int i = 0;
    while (i < _controlPoints.count-1)
    {
        // Find the distance between from i to point i + 1
        distanceToNextPoint = PointDistance([_controlPoints[i] CGPointValue], [_controlPoints[i+1] CGPointValue]);
        
        // If it would push us past distanceTravelled, we're in the right spot.
        if (distanceToPointI + distanceToNextPoint >= distanceTravelled) break;
        
        // Otherwise, move to the next point.
        distanceToPointI += distanceToNextPoint;
        i++;
    }
    
    // Interpolate linearly between the two points.
    return PointTowardsPoint([_controlPoints[i] CGPointValue], [_controlPoints[i+1] CGPointValue], distanceTravelled-distanceToPointI);
}

@end
