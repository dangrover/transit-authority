//
//  StationNode.h
//  Transit Authority
//
//  Created by Dan Grover on 7/13/13.
//
//

#import "CCSprite.h"
#import "cocos2d.h"

@protocol StationNodeDelegate;

@interface StationNode : CCNode<CCTouchOneByOneDelegate>
@property(assign, nonatomic) int passengerCount;
@property(assign, nonatomic) NSObject<StationNodeDelegate> *delegate;
@property(strong, nonatomic) NSString *stationUUID;
@property(strong, nonatomic) NSArray *glyphsToDisplay; // filenames
@property(assign, nonatomic) float dotScale;
@end

@protocol StationNodeDelegate <NSObject>
- (void) stationNodeClicked:(StationNode *)stationNode;
@end