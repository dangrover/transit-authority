//
//  Passenger.m
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "Passenger.h"

@implementation Passenger

@end


static NSMutableSet *_passengerPool; // recycle these objects so we're not mallocing constantly

Passenger *GetNewPassenger(){
    if(!_passengerPool) _passengerPool = [NSMutableSet set];
    Passenger *p = nil;
    if(_passengerPool.count){
        p = [_passengerPool anyObject];
        [_passengerPool removeObject:p];
    }else{
        p = [[Passenger alloc] init];
        [_passengerPool addObject:p];
    }
    
    p.transfersMade = 0;
    p.origin = p.finalDestination = nil;
    
    return p;
}

void RecyclePassenger(Passenger *p){
    [_passengerPool addObject:p];
}

void RecyclePassengers(NSArray *a){
    for(Passenger *p in a){
        RecyclePassenger(p);
    }
}
