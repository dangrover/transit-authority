//
//  Utilities.m
//  Transit Authority
//
//  Created by Dan Grover on 6/18/13.
//
//

#import "Utilities.h"
#include <OpenGLES/EAGL.h>

static NSNumberFormatter *_currencyFormatter;

CGFloat PointDistance(CGPoint point1,CGPoint point2){
    CGFloat dx = point2.x - point1.x;
    CGFloat dy = point2.y - point1.y;
    return sqrt(dx*dx + dy*dy );
};

// Calculate the distance between two points taking into account a third z dimension.
CGFloat PointDistance3D(CGPoint point1,CGPoint point2,CGFloat z1,CGFloat z2){
    CGFloat dx = point2.x - point1.x;
    CGFloat dy = point2.y - point1.y;
    CGFloat dz = z2 - z1;
    return sqrt(dx*dx + dy*dy + dz*dz);
};

CGPoint PointTowardsPoint(CGPoint pointA, CGPoint pointB, float distance)
{
    float totalDistance = PointDistance(pointA, pointB);
    float portion = distance / totalDistance;
    if (portion > 1) return pointB;
    return CGPointOffset(pointA, portion * (pointB.x - pointA.x), portion * (pointB.y - pointA.y));
};

float AngleBetweenPoints(CGPoint pointA, CGPoint pointB)
{
    return atan2(pointB.y - pointA.y, pointB.x - pointA.x);
};

CGPoint PointTowardsAngle(CGPoint pointA, float angle, float distance)
{
    return CGPointOffset(pointA, distance * cos(angle), distance * sin(angle));
};

CGPoint CGPointOffset(CGPoint thePoint, CGFloat x, CGFloat y){
    return CGPointMake(thePoint.x + x, thePoint.y + y);
};

float PointLineSegmentDistance(CGPoint pt, CGPoint p1, CGPoint p2)
{
    float dx = p2.x - p1.x;
    float dy = p2.y - p1.y;
    if ((dx == 0) && (dy == 0))
    {
        // It's a point not a line segment.
        dx = pt.x - p1.x;
        dy = pt.y - p1.y;
        return sqrt(dx * dx + dy * dy);
    }
    
    // Calculate the t that minimizes the distance.
    float t = ((pt.x - p1.x) * dx + (pt.y - p1.y) * dy) / (dx * dx + dy * dy);
    
    // See if this represents one of the segment's
    // end points or a point in the middle.
    if (t < 0)
    {
        dx = pt.x - p1.x;
        dy = pt.y - p1.y;
    }
    else if (t > 1)
    {
        dx = pt.x - p2.x;
        dy = pt.y - p2.y;
    }
    else
    {
        dx = pt.x - (p1.x + t * dx);
        dy = pt.y - (p1.y + t * dy);
    }
    
    return sqrt(dx * dx + dy * dy);
}

NSString *FormatCurrency(NSNumber *currency){
    if(!_currencyFormatter){
        _currencyFormatter = [NSNumberFormatter new];
        [_currencyFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        _currencyFormatter.currencySymbol = @"$";
        _currencyFormatter.maximumFractionDigits = 0;
    }
    return [_currencyFormatter stringFromNumber:currency];
}

NSString *FormatTimeInterval(NSTimeInterval timeInterval){
    int totalSeconds = (int)floor(timeInterval);
    //int seconds = totalSeconds % 60;
    int minutes = (totalSeconds / 60) % 60;
    int hours = totalSeconds / 3600;
    
    return [NSString stringWithFormat:@"%02d:%02d",hours, minutes];
}


CGPoint CGPointMidpoint(CGPoint a, CGPoint b){
    return CGPointMake(a.x + ((b.x - a.x) / 2),
                       a.y + ((b.y - a.y) / 2));
}





@implementation NSArray (Random)
- (id) randomObject{
    if(self.count) return self[arc4random_uniform(self.count)];
    return nil;
}

@end