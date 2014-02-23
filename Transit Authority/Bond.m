//
//  Bond.m
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "Bond.h"

@implementation Bond

- (float) originalTotal{
    return (self.rate + 1.0f) * self.principal;
}

- (float) paymentForInterval:(NSTimeInterval)theInterval{
    return self.originalTotal * (theInterval/self.term);
}

@end
