//
//  TracksInspector.m
//  Transit Authority
//
//  Created by Dan Grover on 7/13/13.
//
//

#import "TracksInspector.h"
#import "Utilities.h"

@interface TracksInspector ()
@property(assign, readwrite) GameState *state;
@property(assign, readwrite) TrackSegment *tracks;
@end

@implementation TracksInspector

- (id)initWithTracks:(TrackSegment *)theTracks gameState:(GameState *)theState{
    if(self = [super initWithNibName:@"TracksInspector" bundle:nil]){
        self.tracks = theTracks;
        self.state = theState;
    }
    return self;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    CGFloat xCursor = chooseLinesLabel.frame.origin.x;
    CGFloat y = chooseLinesLabel.frame.origin.y + chooseLinesLabel.frame.size.height + 3;
    CGSize segmentSize = CGSizeMake(floor(chooseLinesLabel.frame.size.width / (LineColor_Max)),
                                    30);
    CGFloat segmentPadding = 2;
    
    for(LineColor c = LineColor_Red; c <= LineColor_Max; c++){
        if(self.state.lines[@(c)]){
            UIButton *colorButton = [[UIButton alloc] initWithFrame:CGRectMake(xCursor, y, segmentSize.width, segmentSize.height)];
            colorButton.backgroundColor = [Line uiColorForLineColor:c];
            [colorButton setTitle:@"X" forState:UIControlStateSelected];
            [colorButton addTarget:self action:@selector(colorButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
            colorButton.selected = (self.tracks.lines[@(c)] != nil);
            colorButton.tag = c;
            colorButton.layer.cornerRadius = 3;
            
            [self.view addSubview:colorButton];
            
            xCursor += segmentSize.width + segmentPadding;
        }
    }
}


- (IBAction)colorButtonPressed:(UIButton *)sender{
    BOOL shouldHaveLineHere = !sender.selected;
    Line *line = self.state.lines[@(sender.tag)];
    
    if(shouldHaveLineHere){
        if(![self.state line:line canAddSegment:self.tracks]){
            [self _cancelWithErrorHeading:@"Invalid Line"
                                     body:@"Adding this link would make your line invalid. Lines must be contiguous and non-branching."];
            return;
        }else{
            [line applyToSegment:self.tracks];
        }
    }else{
        if(![self.state line:line canRemoveSegment:self.tracks]){
            [self _cancelWithErrorHeading:@"Invalid Line"
                                     body:@"Removing this link would make your line invalid. Lines must be contiguous and non-branching."];
            return;
        }else{
            [line removeFromSegment:self.tracks];
        }
    }
    
    // we did something!
    [self.state regenerateAllTrainRoutes];
    
    
    sender.selected = shouldHaveLineHere;
}

- (void) _cancelWithErrorHeading:(NSString *)heading body:(NSString *)body{
    QuickAlert(heading, body);
}

- (IBAction) demolish:(id)sender{
    [self.state removeTrackSegment:self.tracks];
}

@end
