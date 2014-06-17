//
//  TrainNode.h
//  Transit Authority
//
//  Created by Dan Grover on 7/31/13.
//
//

#import "cocos2d.h"
#import "GameState.h"
#import "CCLabelTTF.h"

@interface TrainNode : CCSprite

- (id) init;

@property(assign, nonatomic) LineColor color;
@property(assign, nonatomic) unsigned count;
@property(assign, nonatomic) unsigned capacity;

@end
