//
//  TracksInspector.h
//  Transit Authority
//
//  Created by Dan Grover on 7/13/13.
//
//

#import <UIKit/UIKit.h>
#import "TracksNode.h"
#import "GameState.h"

@interface TracksInspector : UIViewController{
    IBOutlet UILabel *chooseLinesLabel;
}
- (id)initWithTracks:(TrackSegment *)theTracks gameState:(GameState *)theState;
@property(assign, readonly) GameState *state;
@property(assign, readonly) TrackSegment *tracks;

- (IBAction) demolish:(id)sender;

@end
