//
//  TrainPath.h
//  Transit Authority
//
//  Created by James Murdza on 5/17/14.
//  Copyright (c) 2014 Brown Bag Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TrainPath : NSObject
{
    NSArray *_controlPoints;
    float _length;
}

@property(readonly) float length;

- (id)initWithControlPoints:(NSArray *)controlPoints;
- (CGPoint)coordinatesAtPosition:(float)position;
- (float)distanceToPoint:(CGPoint)point;

@end
