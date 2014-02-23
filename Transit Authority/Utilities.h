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
CGPoint CGPointOffset(CGPoint thePoint, CGFloat x, CGFloat y);
CGPoint CGPointMidpoint(CGPoint a, CGPoint b);

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