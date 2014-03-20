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

CGPoint CGPointOffset(CGPoint thePoint, CGFloat x, CGFloat y){
    return CGPointMake(thePoint.x + x, thePoint.y + y);
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