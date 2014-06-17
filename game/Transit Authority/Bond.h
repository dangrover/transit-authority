//
//  Bond.h
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "GameObject.h"

@interface Bond : GameObject
@property(assign, nonatomic) float principal;
@property(assign, nonatomic) float rate;
@property(assign, nonatomic, readonly) float originalTotal;
@property(assign, nonatomic) float amountRemaining;
@property(assign, nonatomic) NSTimeInterval dateIssued;
@property(assign, nonatomic) NSTimeInterval term;

- (float) paymentForInterval:(NSTimeInterval)theInterval;

@end