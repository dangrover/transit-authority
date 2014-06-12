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

@interface TracksNode : CCNode
@property(assign) CGPoint start;
@property(assign) CGPoint end;
@property(assign) TrackSegment *segment;
@property(assign) BOOL valid;
@property(retain) NSMutableArray *trainPaths;
@property(assign) NSObject<TracksNodeDelegate> *delegate;
- (void) rebuffer;
- (int)lineCount;
- (CGPoint)coordForTrainAtPosition:(double)position
                            onLine:(int)line;
@end


@protocol TracksNodeDelegate <NSObject>
- (void) tracks:(TracksNode *)tracks gotClicked:(CGPoint)touchLoc;
@end