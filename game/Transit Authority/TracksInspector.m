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

// Variables for drawing buttons.
@property(assign, readwrite) CGFloat xCursor, y, segmentPadding;
@property(assign, readwrite) int segmentSize;
@end

@implementation TracksInspector

- (id)initWithTracks:(TrackSegment *)theTracks gameState:(GameState *)theState{
    if(self = [super initWithNibName:@"TracksInspector" bundle:nil]){
        self.tracks = theTracks;
        self.state = theState;
    }
    return self;
}

- (void)prepareButton:(UIButton *)button
            lineColor:(LineColor)c
{
    [button removeTarget:self action:NULL forControlEvents:UIControlEventTouchUpInside];
    if (self.state.lines[@(c)])
    {
        [button addTarget:self action:@selector(colorButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [button setTitle:@"" forState:UIControlStateNormal];
        [button setTitle:@"\u2713" forState:UIControlStateSelected];
        [button setContentVerticalAlignment:UIControlContentVerticalAlignmentBottom];
    }
    else
    {
        [button addTarget:self action:@selector(newLineButtonPressed:) forControlEvents:UIControlEventTouchUpInside];
        [button setTitle:@"+" forState:UIControlStateNormal];
        [button setContentVerticalAlignment:UIControlContentVerticalAlignmentTop];
    }
    
    button.tag = c;
    button.selected = (self.tracks.lines[@(c)] != nil);
    
    button.layer.borderColor = [Line uiColorForLineColor:c].CGColor;
    button.layer.borderWidth = 2;
    button.layer.cornerRadius = button.frame.size.width/2;
    
    [button setTitleColor:[UIColor colorWithWhite:0.1f alpha:1] forState:UIControlStateNormal];

}

- (void)addNewLineButton
{
    if (self.state.lines.count <= LineColor_Max)
    {
        LineColor c;
        for(c = LineColor_Min; c <= LineColor_Max; c++)
        {
            if(!self.state.lines[@(c)]) break;
        }
        
        UIButton *colorButton = [[UIButton alloc] initWithFrame:CGRectMake(_xCursor, _y, _segmentSize, _segmentSize)];
        [self prepareButton:colorButton lineColor:c];
        [self.view addSubview:colorButton];
        _xCursor += _segmentSize + _segmentPadding;
    }
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    _segmentPadding = 3;
    _xCursor = chooseLinesLabel.frame.origin.x;
    _y = chooseLinesLabel.frame.origin.y + chooseLinesLabel.frame.size.height + 3;
    _segmentSize = floor(chooseLinesLabel.frame.size.width / (LineColor_Max) - _segmentPadding);
    
    // Add a color button for every line included in the selected tracks.
    for(LineColor c = LineColor_Min; c <= LineColor_Max; c++){
        if(self.state.lines[@(c)]){
            UIButton *colorButton = [[UIButton alloc] initWithFrame:CGRectMake(_xCursor, _y, _segmentSize, _segmentSize)];
            [self prepareButton:colorButton lineColor:c];
            [self.view addSubview:colorButton];
            _xCursor += _segmentSize + _segmentPadding;
        }
    }
    
    [self addNewLineButton];
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
    [self prepareButton:sender lineColor:sender.tag];
}

- (IBAction)newLineButtonPressed:(UIButton *)sender{
    Line *line = [_state addLineWithColor:sender.tag];
    [line applyToSegment:self.tracks];
    [self.state regenerateAllTrainRoutes];
    
    [self prepareButton:sender lineColor:sender.tag];
    [self addNewLineButton];
}

- (void) _cancelWithErrorHeading:(NSString *)heading body:(NSString *)body{
    QuickAlert(heading, body);
}

- (IBAction) demolish:(id)sender{
    [self.state removeTrackSegment:self.tracks];
}

@end
