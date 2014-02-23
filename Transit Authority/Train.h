//
//  Train.h
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "GameObject.h"
#import "Routes.h"

typedef enum{
    TrainState_MovingOnTrack,
    TrainState_StoppedInStation
} TrainState;

@interface Train : GameObject
@property(strong) NSDate *bought;

// position
@property(assign, nonatomic) double currentChunkPosition; // if 0, we are waiting in the first station, as it approaches 1, we have arrived in the next
@property(assign, nonatomic) double speed; // tiles per tick
@property(assign, nonatomic) double acceleration; // tiles per tick

@property(strong) Line *line;
@property(strong) TrainRoute *currentRoute; // nil for nowhere
@property(assign) TrainState state;

@property(assign, nonatomic) unsigned currentRouteChunk; // index
@property(assign, nonatomic) NSTimeInterval lastStateChange; // the time we last changed the state

// passengers
@property(strong) NSMutableDictionary *passengersByDestination; // UUID -> @(count)
@property(assign, readonly) unsigned totalPassengersOnBoard;
@property(assign, readonly) unsigned capacity;

@end
