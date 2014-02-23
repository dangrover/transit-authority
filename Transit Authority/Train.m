//
//  Train.m
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "Train.h"
#import "GameConstants.h"

@implementation Train

- (id) init{
    if(self = [super init]){
        self.passengersByDestination = [NSMutableDictionary dictionary];
    }
    return self;
}


- (unsigned) totalPassengersOnBoard{
    unsigned total = 0;
    for(NSArray *a in self.passengersByDestination.allValues){
        total += a.count;
    }
    return total;
}

- (unsigned) capacity{
    return self.line.numberOfCars * GAME_TRAIN_PASSENGERS_PER_CAR;
}
@end
