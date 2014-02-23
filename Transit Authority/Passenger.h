//
//  Passenger.h
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>

@class Station;

/// Stores information about an individual passenger in the system
@interface Passenger : NSObject
@property(strong) Station *origin; // Where they got on
@property(assign) Station *finalDestination; // Where they're going
@property(assign) NSTimeInterval enteredStationTime; // When they first entered a station
@property(assign) NSTimeInterval boardedTrainTime; // When they got on their train
@property(assign) unsigned transfersMade; // Number of tranfers they have made so far
@end

/// Because we move passengers around so much, we don't want to be alloc/initing,
/// all the time for performance reasons, so we keep them in a pool.
Passenger *GetNewPassenger();
void RecyclePassenger(Passenger *p);
void RecyclePassengers(NSArray *a);