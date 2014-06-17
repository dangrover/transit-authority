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
        for (int i = 0; i < self.segmentCount; i++)
        {
            distance += PointDistance([self controlPointAtIndex:i], [self controlPointAtIndex:i+1]);
        }
        _length = distance;
    }
    
    return self;
}

- (CGPoint)controlPointAtIndex:(int)index
{
    return [_controlPoints[index] CGPointValue];
}

- (int)segmentCount
{
    return _controlPoints.count - 1;
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
    while (i < self.segmentCount)
    {
        // Find the distance between from i to point i + 1
        distanceToNextPoint = PointDistance([self controlPointAtIndex:i], [self controlPointAtIndex:i+1]);
        
        // If it would push us past distanceTravelled, we're in the right spot.
        if (distanceToPointI + distanceToNextPoint >= distanceTravelled) break;
        
        // Otherwise, move to the next point.
        distanceToPointI += distanceToNextPoint;
        i++;
    }
    
    // Interpolate linearly between the two points.
    return PointTowardsPoint([self controlPointAtIndex:i], [self controlPointAtIndex:i+1], distanceTravelled-distanceToPointI);
}

// Return the shortest distance between a point and the path.
- (float)distanceToPoint:(CGPoint)point
{
    float minDistance = 0;
    
    // Check the distance to the individual line segments.
    for (int i = 0; i < self.segmentCount; i++)
    {
        float distance = PointLineSegmentDistance(point, [self controlPointAtIndex:i], [self controlPointAtIndex:i+1]);
        // Take the minimum.
        if (i == 0 || distance < minDistance)
        {
            minDistance = distance;
        }
    }
    
    return minDistance;
}

@end
