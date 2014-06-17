//
//  Utilities.h
//  Transit Authority
//
//  Created by Dan Grover on 6/18/13.
//
//

#import <Foundation/Foundation.h>



#define ARC4RANDOM_MAX      0x100000000

CGFloat PointDistance(CGPoint point1,CGPoint point2);
CGFloat PointDistance3D(CGPoint point1,CGPoint point2,CGFloat z1,CGFloat z2);
CGPoint CGPointOffset(CGPoint thePoint, CGFloat x, CGFloat y);
CGPoint CGPointMidpoint(CGPoint a, CGPoint b);
CGPoint PointTowardsPoint(CGPoint pointA, CGPoint pointB, float distance);
float AngleBetweenPoints(CGPoint pointA, CGPoint pointB);
CGPoint PointTowardsAngle(CGPoint pointA, float angle, float distance);
float PointLineSegmentDistance(CGPoint p, CGPoint v, CGPoint w);

NSString *FormatCurrency(NSNumber *currency);
NSString *FormatTimeInterval(NSTimeInterval timeInterval);

#define QuickAlert(TITLE,MSG) [[[UIAlertView alloc] initWithTitle:(TITLE) \
message:(MSG) \
delegate:nil \
cancelButtonTitle:@"OK" \
otherButtonTitles:nil] show]



@interface NSArray (Random)
- (id) randomObject;
@end