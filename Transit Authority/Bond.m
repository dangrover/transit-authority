//
//  Bond.m
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "Bond.h"
#import "NSCoding-Macros.h"

@implementation Bond

- (float) originalTotal{
    return (self.rate + 1.0f) * self.principal;
}

- (float) paymentForInterval:(NSTimeInterval)theInterval{
    return self.originalTotal * (theInterval/self.term);
}

#pragma mark - Serialization

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];
    encodeInt(_principal);
    encodeInt(_rate);
    encodeInt(_amountRemaining);
    encodeInt(_dateIssued);
    encodeInt(_term);
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder])
    {
        decodeInt(_principal);
        decodeInt(_rate);
        decodeInt(_amountRemaining);
        decodeInt(_dateIssued);
        decodeInt(_term);
    }
    return self;
}

@end
