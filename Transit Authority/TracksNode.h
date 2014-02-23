//
//  TracksNode.h
//  Transit Authority
//
//  Created by Dan Grover on 6/25/13.
//
//

#import "GameState.h"
#import "cocos2d.h"

@protocol TracksNodeDelegate;

@interface TracksNode : CCNode<CCTouchOneByOneDelegate>
@property(assign) CGPoint start;
@property(assign) CGPoint end;
@property(assign) TrackSegment *segment;
@property(assign) BOOL valid;
@property(assign) NSObject<TracksNodeDelegate> *delegate;
@end


@protocol TracksNodeDelegate <NSObject>
- (void) tracks:(TracksNode *)tracks gotClicked:(CGPoint)touchLoc;
@end