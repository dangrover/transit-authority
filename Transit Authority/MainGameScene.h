//
//  MainGameScene.h
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//
//

#import <AVFoundation/AVFoundation.h>
#import "cocos2d.h"
#import "GameState.h"
#import "GameTool.h"
#import "HeatMapNode.h"
//#import "SimpleAudioEngine.h"

@class CCLayerPanZoom;

#define STATION_SPRITE_SCALE_LONG_PLATFORM 1
#define STATION_SPRITE_SCALE_UNSELECTED 0.7

#define SoundEffect_BuildStation @"build-station.wav"
#define SoundEffect_CashRegister @"cash-register.wav"
#define SoundEffect_BuildTunnel @"build-tunnel.aiff"
#define SoundEffect_CompleteGoal @"complete-goal.aiff"
#define SoundEffect_Owl @"owl.aiff"
#define SoundEffect_Rooster @"rooster.aiff"
#define SoundEffect_Error @"error.aiff"


/// The main scene showing the map, the lines, the stations, and the trains running between them.
@interface MainGameScene : CCScene{
    @public
    CCTiledMap *tiledMap;
    CCLayerPanZoom *_panZoomLayer;


    IBOutlet UIView *toolHelpOverlay;
    IBOutlet UILabel *toolHelpLabel;
    
    NSMutableDictionary *_stationSprites;
}

- (id) initWithGameState:(GameState *)theState;

@property(strong, nonatomic, readonly) GameState *gameState;

@property(strong, nonatomic, readonly) HeatMapNode *heatMap;

//- (IBAction) showStats:(id)sender;
- (IBAction) showFinances:(id)sender;
- (IBAction) showGoals:(id)sender;

@property(assign, nonatomic) BOOL showPopulationHeatmap;

- (Station *) stationAtNodeCoords:(CGPoint)thePoint;


- (double) scaleConsideringZoom:(double)correctScale;

@end

#pragma mark -


