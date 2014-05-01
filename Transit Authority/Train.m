//
//  Train.m
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "Train.h"
#import "GameConstants.h"
#import "NSCoding-Macros.h"

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

#pragma mark - Serialization

- (void)encodeWithCoder:(NSCoder *)encoder {
    [super encodeWithCoder:encoder];

    encodeDouble(_currentChunkPosition);
    encodeDouble(_speed);
    encodeDouble(_acceleration);

    encodeObject(_line);
    encodeInt(_timeToWait);
    encodeInt(_currentRouteChunk);
    encodeInt(_lastStateChange);
    
    encodeObject(_passengersByDestination);
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [super initWithCoder:decoder])
    {
        decodeDouble(_currentChunkPosition);
        decodeDouble(_speed);
        decodeDouble(_acceleration);
        
        decodeObject(_line);
        decodeInt(_timeToWait);
        decodeInt(_currentRouteChunk);
        decodeInt(_lastStateChange);
        
        decodeObject(_passengersByDestination);
    }
    return self;
}

@end
