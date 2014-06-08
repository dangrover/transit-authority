//
//  MainGameScene.m
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//
//

#import "cocos2d.h"
#import "MainGameScene.h"
#import "CCTiledMap.h"
#import "UIColor+Cocos.h"
#import "CCTMXTiledMap+Extras.h"
#import "Utilities.h"
#import "DataTool.h"
#import "LinesTool.h"
#import "PlaceStationTool.h"
#import "PlaceTracksTool.h"
#import "TracksNode.h"
#import "MoreTool.h"
#import "FinancesViewController.h"
#import "PopoverView.h"
#import "TracksInspector.h"
#import "StationInspector.h"
#import "StationNode.h"
#import "TrainNode.h"
#import "StreetNode.h"
#import "GoalsViewController.h"
#import "StationCoverageOverlay.h"
#import "TAModal.h"
#import "POIPlaceholderNode.h"
#import "PointOfInterest.h"
#import "CCLayerPanZoom.h"
#import "CCScrollView.h"
#import "CCBReader.h"
#import "CCButton.h"

#define TRAIN_UPDATE_INTERVAL 0.5
#define EVENT_LOOP_INTERVAL (1.0/60.0)
#define STAT_UPDATE_INTERVAL 6
#define UI_CORNER_RADIUS 8

#define UI_FADE_DURATION 0.1

@interface MainGameScene()<FinancesViewDelegate, CCLayerPanZoomClickDelegate, PopoverViewDelegate, StationNodeDelegate, TracksNodeDelegate, GoalsDelegate>

@property(strong, nonatomic, readwrite) GameState *gameState;
@property(strong, nonatomic, readwrite) HeatMapNode *heatMap;

@property(strong, nonatomic, readwrite) GameTool *currentTool;

//@property(strong) CCScrollView *scrollView;
@end

ccColor4B COLOR_OVERLAYS_BY_HOUR[24] = {
    {0, 0, 255, 50}, // 12am
    {0, 0, 255, 50}, // 1am
    {0, 0, 255, 50}, // 2am
    {0, 0, 255, 50}, // 3am
    {0, 0, 255, 50}, // 4am
    {0, 0, 255, 30}, // 5am
    {255, 0, 0, 30}, // 6am
    {255, 0, 0, 15}, // 7am
    {0, 0, 0, 0}, // 8am
    {0, 0, 0, 0}, // 9am
    {0, 0, 0, 0}, // 10am
    {0, 0, 0, 0}, // 11am
    {0, 0, 0, 0}, // 12am
    {0, 0, 0, 0}, // 1pm
    {0, 0, 0, 0}, // 2pm
    {0, 0, 0, 0}, // 3pm
    {0, 0, 0, 0}, // 4pm
    {0, 0, 0, 0}, // 5pm
    {0, 0, 0, 0}, // 6pm
    {255, 0, 0, 15}, // 7pm
    {255, 0, 0, 30}, // 8pm
    {0, 0, 255, 50}, // 9pm
    {0, 0, 255, 50}, // 10pm
    {0, 0, 255, 50}, // 11pm
};

@implementation MainGameScene{
    @public
    
    BOOL panMode;
    BOOL _panningAllowed;
    BOOL _namesLayerOn;
    BOOL _populationLayerOn;
    
    BOOL _touchesHandledByTool;
    
    NSDateFormatter *_dateFormatter;
 
    
    float currentSpeed;
    
    NSTimeInterval lastTick;
    NSTimeInterval lastStatUpdate;
    double _lastTripPropDisplayed; // proportion of trips made on system
    
    FinancesViewController *financesVC;
    GoalsViewController *goalsVC;
    
    PopoverView *_popover;
    TracksInspector *_tracksInspector;
    TrackSegment *_tracksBeingInspected;
    
    StationInspector *_stationInspector;
    StationCoverageOverlay *_coverageOverlay;
    Station *_stationBeingInspected;
    
    UINavigationController *_modalNav;
    
    // Sprites
    NSMutableSet *_streetSprites;
    
    NSMutableDictionary *_trackSprites;
    NSMutableDictionary *_trainSprites;
    NSMutableSet *_nameSprites;
    NSMutableDictionary *_unbuiltPOISprites;
    
    AVQueuePlayer *_musicPlayer;
    
    CCNodeColor *_dayNightOverlay;
    
    TAModal *_myModalViewController;
    
    CCLabelTTF *cityNameLabel;
    CCLabelTTF *dateLabel;
    CCScrollView *scrollView;
//    CCLabelTTF *moneyLabel;
    CCButton *cashButton;
    
    CCNode *topNode;
    CCNode *_moreMenuNode;
    CCNode *_buildSubmenuNode;
    
    LinesTool *linesTool;
    UIView *_linesTopView;
    
    CCNode *buildButtonGroup;
    CCButton *buildButton;
    CCNode *menuButtonGroup;
    CCButton *menuButton;
    CCSprite *speedIcon;
    
    CCButton *goalsButton;
    
    CCButton *manageButton;
    
    CCNode *manageButtonGroup;
    
    CCButton *stationButton;
    CCButton *tracksButton;
    
    CCNode *dataButtonGroup;
    CCButton *dataButton;
    UIView *_dataTopView;
    DataTool *dataTool;
    
    CCNode *backgroundPlaceholderNode;
}

- (id) initWithGameState:(GameState *)theState{
    if(self = [super init]){
        
        topNode = [CCBReader load:@"GameScene" owner:self];
        [self addChild:topNode];
        
        [backgroundPlaceholderNode removeFromParentAndCleanup:YES];
        
        self.gameState = theState;
        currentSpeed = 0;
        
        _stationSprites = [NSMutableDictionary dictionary];
        _trackSprites = [NSMutableDictionary dictionary];
        _trainSprites = [NSMutableDictionary dictionary];
        _nameSprites = [NSMutableSet set];
        _streetSprites = [NSMutableSet set];
        _unbuiltPOISprites = [NSMutableDictionary dictionary];
        
        _dateFormatter = [[NSDateFormatter alloc] init];
        _dateFormatter.dateFormat = @"LLL d, h:mma";
        _dateFormatter.AMSymbol = @"am";
        _dateFormatter.PMSymbol = @"pm";
        _dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
        
        // load the map
        tiledMap = theState.map.map;
        
        [[OALSimpleAudio sharedInstance] preloadEffect:SoundEffect_BuildStation];
    }

    return self;
}

- (void) dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

-(void) onEnter{
   
    self.userInteractionEnabled = YES;
    
    _panZoomLayer = [[CCLayerPanZoom alloc] init];
    _panZoomLayer.mode = kCCLayerPanZoomModeSheet;
    _panZoomLayer.minScale = 1.0f/5.0f;
    _panZoomLayer.maxScale = 1.0f/2.0f;
    _panZoomLayer.rubberEffectRatio = 0;
    _panZoomLayer.userInteractionEnabled = YES;
    _panZoomLayer.delegate = self;
    
    
    CGPoint startPos = [self.gameState.map.landLayer positionAt:self.gameState.map.startPosition];
  
    tiledMap.position = CGPointMake(-1*(startPos.x - (self.boundingBox.size.width/2)),
                                    -1*(startPos.y - (self.boundingBox.size.height/2)));
    

    [_panZoomLayer addChild:tiledMap];
    _panZoomLayer.position = CGPointMake(self.boundingBox.size.width/2, self.boundingBox.size.height/2);
    
    [self addChild:_panZoomLayer z:-100];
    _panZoomLayer.scale = _panZoomLayer.minScale;
    
    [self _makeStreetSprites];
    [self _makeNeighborhoodNameSprites];

    
    
    NSArray *gameStatePropsToObserve = @[@"currentCash", @"currentDate", @"cityName", @"assignedTrains", @"stations", @"tracks", @"poisWithoutStations"];
    for(NSString *p in gameStatePropsToObserve){
        [self.gameState addObserver:self forKeyPath:p options:NSKeyValueObservingOptionInitial context:nil];
    }
    
    
    [self setSpeed:1];
    [self _updateGoalDisplay];
    
    // Music
    NSArray *trackNames = @[@"jazzy-glide",@"big-boy-blues"];
    NSMutableArray *itemArray = [NSMutableArray array];
    for(NSString *t in trackNames){
        [itemArray addObject:[[AVPlayerItem alloc] initWithAsset:[AVAsset assetWithURL:[[NSBundle mainBundle] URLForResource:t withExtension:@"mp3"]]]];
    }
    
    _musicPlayer = [[AVQueuePlayer alloc] initWithItems:itemArray];
         
    #if !(TARGET_IPHONE_SIMULATOR)
    [_musicPlayer play];
    #endif
    
    CGSize screenSize = [CCDirector sharedDirector].viewSizeInPixels;
    self.heatMap = [[HeatMapNode alloc] initWithMap:self.gameState.map
                                   viewportSize:CGSizeMake(2*ceil(screenSize.width/tiledMap.tileSize.width),
                                                           2*ceil(screenSize.height/tiledMap.tileSize.width))
                                     bufferSize:CGSizeMake(26, 26)];
    
    [tiledMap addChild:self.heatMap z:90];
    
    self.heatMap.currentPosition = self.gameState.map.startPosition;
    [self.heatMap refresh];
    
    [self setNamesVisible:YES];
    self.showPopulationHeatmap = NO;
    
    // Don't show any of the real layers in the map for density,
    // because we're rendering it in the heatmap.
    self.gameState.map.residentialPopulationLayer.visible = self.gameState.map.commericalPopulationLayer.visible = NO;
    
    _dayNightOverlay = [CCNodeColor nodeWithColor:[CCColor clearColor]];

    // Hide elevation layer:
    self.gameState.map.elevationLayer.visible = NO;

    _dayNightOverlay.opacity = 0;
    [self addChild:_dayNightOverlay];
    
    
    // Notifications
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self selector:@selector(bondIssued) name:GameStateNotification_IssuedBond object:self.gameState];
    [nc addObserver:self selector:@selector(hourChime) name:GameStateNotification_HourChanged object:self.gameState];
    [nc addObserver:self selector:@selector(stationBuilt) name:GameStateNotification_StationBuilt object:self.gameState];
    [nc addObserver:self selector:@selector(goalCompleted:) name:GameStateNotification_AccomplishedGoal    object:self.gameState];
    [nc addObserver:self selector:@selector(_updateGoalDisplay) name:GameStateNotification_CheckedGoals object:self.gameState];
    
    
    [self schedule:@selector(clockTick) interval:REAL_SECONDS_PER_TICK];
    
    [self _changeZooms];
    
    [super onEnter];
}

- (void)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event{
    
    if([self.currentTool touchBegan:touch withEvent:event]){
        _touchesHandledByTool = YES;
    }else{
        [super touchBegan:touch withEvent:event];
    }
}

- (void)touchMoved:(UITouch *)touch withEvent:(UIEvent *)event{
    if(_touchesHandledByTool){
        [self.currentTool touchMoved:touch withEvent:event];
    }else{
        [super touchMoved:touch withEvent:event];
    }
}

- (void)touchEnded:(UITouch *)touch withEvent:(UIEvent *)event{
    if(_touchesHandledByTool){
        [self.currentTool touchEnded:touch withEvent:event];
    }else{
        [super touchEnded:touch withEvent:event];
    }
    
    _touchesHandledByTool = NO;
}

- (void)touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event{
    if(_touchesHandledByTool){
        [self.currentTool touchCancelled:touch withEvent:event];
    }else{
        [super touchCancelled:touch withEvent:event];
    }
    
    _touchesHandledByTool = NO;
}

- (void) setAllowPanning:(BOOL)allowPanning{
    _panningAllowed = allowPanning;
}

- (void) layerPanZoom:(CCLayerPanZoom *)sender updatedPosition:(CGPoint)pos scale:(CGFloat)scale{
    //NSLog(@"PAN ZOOM LAYER MOVED. POSITION IS NOW %@", NSStringFromCGPoint(pos));
    
    CGPoint centerOfScreenInWorldSpace = [self convertToWorldSpace:CGPointMake(self.boundingBox.size.width/2,self.boundingBox.size.height/2)];
    
    _heatMap.currentPosition = [tiledMap tileCoordinateFromNodeCoordinate:[tiledMap convertToNodeSpace:centerOfScreenInWorldSpace]];
    
    //NSLog(@"Current pos = %@", NSStringFromCGPoint(_heatMap.currentPosition));
    
    [self.heatMap refresh];
    [self _changeZooms];
}

- (void) layerPanZoom: (CCLayerPanZoom *) sender
       clickedAtPoint: (CGPoint) aPoint
             tapCount: (NSUInteger) tapCount{
    // Not used
    
}

- (void) _changeZooms{
    for(StationNode *s in _stationSprites.allValues){
        s.scale = [self scaleConsideringZoom:1];
    }
    for(TrainNode *t in _trainSprites.allValues){
        t.scale = [self scaleConsideringZoom:1];
    }
    for(CCSprite *n in _nameSprites.allObjects){
        n.scale = [self scaleConsideringZoom:1 useContentScale:NO];
    }
    for(POIPlaceholderNode *n in _unbuiltPOISprites.allValues){
        n.scale = [self scaleConsideringZoom:1 useContentScale:NO]/2.0f;
    }
    
    [self.gameState.map.landLayer updateScale:_panZoomLayer.scale];
    [self.heatMap refresh];
    
}
- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
    if([keyPath isEqual:@"currentCash"]){
        cashButton.title = FormatCurrency(@(self.gameState.currentCash));
    }
    else if([keyPath isEqual:@"currentDate"]){
        // update displayed date
        dateLabel.string = [[_dateFormatter stringFromDate:[NSDate dateWithTimeIntervalSince1970:self.gameState.currentDate]] uppercaseString];
        
        
        struct tm info = self.gameState.currentDateComponents;
        
        unsigned hour = info.tm_hour;
        float progressThroughHour = (float)info.tm_min/((float)MINUTES_PER_HOUR);
        ccColor4B firstColor = COLOR_OVERLAYS_BY_HOUR[hour];
        ccColor4B secondColor = COLOR_OVERLAYS_BY_HOUR[((hour + 1) % HOURS_PER_DAY)];
        ccColor4B mix = {secondColor.r*progressThroughHour + firstColor.r*(1.0f-progressThroughHour),
            secondColor.g*progressThroughHour + firstColor.g*(1.0f-progressThroughHour),
            secondColor.b*progressThroughHour + firstColor.b*(1.0f-progressThroughHour),
            secondColor.a*progressThroughHour + firstColor.a*(1.0f-progressThroughHour)};
        
        _dayNightOverlay.color = [CCColor colorWithRed:mix.r green:mix.g blue:mix.b alpha:mix.a];
        //_dayNightOverlay.opacity = mix.a;
        
        //NSLog(@"setting color for hour %d", hour);
        
    }else if([keyPath isEqual:@"cityName"]){
        cityNameLabel.string = self.gameState.originalScenario.cityName;
    }else if([keyPath isEqual:@"assignedTrains"]){
        [self _createAndRemoveTrainSprites];
        [self _updateTrainSpritePositions];
    }else if([keyPath isEqual:@"stations"]){
        [self _createAndRemoveStationSprites];
        
        // if we're inspecting a station and now it doesn't exist, get rid of the dialog.
        if(_stationBeingInspected && !self.gameState.stations[_stationBeingInspected.UUID]){
            [_popover dismiss:YES];
        }
    }
    else if([keyPath isEqual:@"tracks"]){
        [self _createAndRemoveTrackSprites];
        
        // if we deleted some tracks using the inspector, get rid of the inspector
        if(_tracksBeingInspected && !self.gameState.trackSegments[_tracksBeingInspected.UUID]){
            [_popover dismiss:YES];
        }
    }
    else if([keyPath isEqual:@"poisWithoutStations"]){
        [self _createAndRemoveUnbuiltPOISprites];
    }
    else if([object isKindOfClass:[Station class]]){
        Station *s = (Station *)object;
        StationNode *n = ((StationNode *)_stationSprites[s.UUID]);
        
        if([keyPath isEqualToString:@"totalPassengersWaiting"]){
            n.passengerCount = s.totalPassengersWaiting;
        }
        else if([keyPath isEqualToString:@"upgrades"] || [keyPath isEqualToString:@"connectedPOI"]){
            NSMutableArray *glyphs = [NSMutableArray array];
            
            if(s.connectedPOI){
                [glyphs addObject:[NSString stringWithFormat:@"connection-%@.png",s.connectedPOI.type]];
            }
            
            for(NSString *ident in s.upgrades){
                if(![ident isEqual:StationUpgrade_LongPlatform]){
                    [glyphs addObject:[NSString stringWithFormat:@"upgrade-%@.png",ident]];
                }
            }
            
            n.glyphsToDisplay = glyphs;
            
            if([s.upgrades containsObject:StationUpgrade_LongPlatform]){
                n.dotScale = STATION_SPRITE_SCALE_LONG_PLATFORM;
            }else{
                n.dotScale = STATION_SPRITE_SCALE_UNSELECTED;
            }
            
            if(s == _stationBeingInspected){
                _coverageOverlay.makeCarPartDarker = [s.upgrades containsObject:StationUpgrade_ParkingLot];
            }
        }
        
    }else if([object isKindOfClass:[Train class]]){
        Train *t = (Train *)object;
        if([keyPath isEqual:@"totalPassengersOnBoard"]){
            ((TrainNode *)_trainSprites[t.UUID]).count = t.totalPassengersOnBoard;
            ((TrainNode *)_trainSprites[t.UUID]).capacity = t.capacity;
        }
        
    }
}

- (double) scaleConsideringZoom:(double)correctScale{
    return [self scaleConsideringZoom:correctScale useContentScale:YES];
}

- (double) scaleConsideringZoom:(double)correctScale useContentScale:(BOOL)useContentScale{
    return correctScale / _panZoomLayer.scale;
}

- (void) newSpeed{
    if(currentSpeed == 0){
        currentSpeed = 1;
    }else if(currentSpeed == 1){
        currentSpeed = 4;
    }else if(currentSpeed == 4){
        currentSpeed = 0;
    }
    [self _updateSpeedIcon];
}

- (void) _updateSpeedIcon{
    
    NSString *iconName = nil;
    if(currentSpeed == 0){
        iconName = @"pause.png";
    }else if(currentSpeed == 1){
        iconName = @"play.png";
    }else if(currentSpeed == 4){
        iconName = @"fast-forward.png";
    }else{
        NSLog(@"UNKNOWN SPEED");
        return;
    }
    
    CCTexture *tex = [CCTexture textureWithFile:iconName];
    speedIcon.texture = tex;
}

- (void) setSpeed:(float)speedMultiplier{
    currentSpeed = speedMultiplier;
}

- (void) clockTick{
    if(!currentSpeed) return;
    NSTimeInterval difference = (CFAbsoluteTimeGetCurrent() - lastTick);
    if(difference >= REAL_SECONDS_PER_TICK){
        int ticksToIncrement = floor(currentSpeed);
        [self.gameState incrementTime:ticksToIncrement];

        lastTick = CFAbsoluteTimeGetCurrent();
    }
       
    [self _updateTrainSpritePositions];
}


- (void) setCurrentTool:(GameTool *)aCurrentTool{
    _currentTool = aCurrentTool;
    _currentTool.parent = self;
    [_currentTool started];
}

- (void) buildButtonPressed{
    
    NSLog(@"Build");
    
    if(!_buildSubmenuNode){
        buildButton.selected = YES;
        _buildSubmenuNode = [CCBReader load:@"BuildSubmenu" owner:self];
    
        _buildSubmenuNode.positionType = buildButtonGroup.positionType;
        _buildSubmenuNode.position = CGPointMake(buildButtonGroup.position.x + buildButtonGroup.contentSize.width + 1,
                                                 buildButtonGroup.position.y);
        
        [topNode addChild:_buildSubmenuNode];
        _buildSubmenuNode.cascadeOpacityEnabled = YES;
        _buildSubmenuNode.opacity = 0;
        [_buildSubmenuNode runAction:[CCActionFadeIn actionWithDuration:UI_FADE_DURATION]];
        
    }else{
        self.currentTool = nil;
        buildButton.selected = NO;
        [_buildSubmenuNode runAction:[CCActionSequence actions:[CCActionFadeOut actionWithDuration:UI_FADE_DURATION],[CCActionCallBlock actionWithBlock:^{
                [_buildSubmenuNode removeFromParentAndCleanup:YES];
                _buildSubmenuNode = nil;
        }], nil]];
    }
}

- (void) manageButtonPressed{
  
    if(!linesTool){
        manageButton.selected = YES;
        linesTool = [[LinesTool alloc] init];
        linesTool.parent = self;
        
        _linesTopView = linesTool.viewController.view;
        UIView *gameView = [[CCDirector sharedDirector] view];
        
        _linesTopView.frame = CGRectMake(manageButtonGroup.position.x + manageButtonGroup.contentSize.width + 1,
                                         manageButtonGroup.position.y,
                                         240,
                                         gameView.frame.size.height - manageButtonGroup.position.y);
        _linesTopView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        _linesTopView.alpha = 0;
        [gameView addSubview:_linesTopView];
        [UIView animateWithDuration:UI_FADE_DURATION animations:^{
            _linesTopView.alpha = 1;
        } completion:^(BOOL finished) {}];
        
    }else{
        manageButton.selected = NO;
        
        [UIView animateWithDuration:UI_FADE_DURATION animations:^{
            _linesTopView.alpha = 0;
        } completion:^(BOOL finished) {
            [_linesTopView removeFromSuperview];
        }];
        
        _linesTopView = nil;
        linesTool.parent = nil;
        linesTool = nil;
    }
}

- (void) dataButtonPressed{
    if(!dataTool){
        dataButton.selected = YES;
        
        dataTool = [[DataTool alloc] init];
        dataTool.parent = self;
        
        _dataTopView = dataTool.navController.view;
        UIView *gameView = [[CCDirector sharedDirector] view];
        
        _dataTopView.frame = CGRectMake(manageButtonGroup.position.x + manageButtonGroup.contentSize.width + 1,
                                         manageButtonGroup.position.y,
                                         240,
                                         gameView.frame.size.height - manageButtonGroup.position.y);
        
        _dataTopView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.5];
        _dataTopView.alpha = 0;
        
        [dataTool started];
        [gameView addSubview:_dataTopView];
        
        [UIView animateWithDuration:UI_FADE_DURATION
                         animations:^{
                             _dataTopView.alpha = 1;
                         }
                         completion:^(BOOL finished){}];
        
    }else{
        dataButton.selected = NO;
        
        [dataTool finished];
        [UIView animateWithDuration:UI_FADE_DURATION animations:^{
            _dataTopView.alpha = 0;
        } completion:^(BOOL finished) {
            [_dataTopView removeFromSuperview];
        }];
        
        _dataTopView = nil;
        dataTool.parent = nil;
        dataTool = nil;
    }
}

- (void) moreButtonPressed{

    NSLog(@"Menu");
    
    if(!_moreMenuNode){
        _moreMenuNode = [CCBReader load:@"MoreSubmenu"];
    
        menuButton.selected = YES;
        _moreMenuNode.positionType = menuButtonGroup.positionType;
        _moreMenuNode.position = CGPointMake(menuButtonGroup.position.x  + menuButtonGroup.contentSize.width + 1,
                                             menuButtonGroup.position.y - 1);
        
        [topNode addChild:_moreMenuNode];
        _moreMenuNode.cascadeOpacityEnabled = YES;
        _moreMenuNode.opacity = 0;
        [_moreMenuNode runAction:[CCActionFadeIn actionWithDuration:UI_FADE_DURATION]];
        
    }else{
        menuButton.selected = NO;
        
        [_moreMenuNode runAction:[CCActionSequence actions:[CCActionFadeOut actionWithDuration:UI_FADE_DURATION],[CCActionCallBlock actionWithBlock:^{
            [_moreMenuNode removeFromParentAndCleanup:YES];
            _moreMenuNode = nil;
        }], nil]];
    }
}

- (void) saveGame{
    NSLog(@"Save game");
}

- (void) share{
    NSLog(@"Share");
}

- (void) showSettings{
    NSLog(@"Settings");
}

- (void) exitGame{
    NSLog(@"Exit game");
}

#pragma mark -

- (void) buildTracks{
    
    if(!tracksButton.selected){
        tracksButton.selected = YES;
        stationButton.selected = NO;
        
        self.currentTool = [[PlaceTracksTool alloc] init];
    }else{
        tracksButton.selected = NO;
        self.currentTool = nil;
    }
    
}

- (void) buildStations{
    if(!stationButton.selected){
        tracksButton.selected = NO;
        stationButton.selected = YES;
        
        self.currentTool = [[PlaceStationTool alloc] init];
    }else{
        stationButton.selected = NO;
        self.currentTool = nil;
    }
}

- (IBAction) showFinances{
    financesVC = [[FinancesViewController alloc] initWithGameState:self.gameState];
    financesVC.delegate = self;

    [self _showModal:financesVC];
}

- (IBAction) showGoals{
    goalsVC = [[GoalsViewController alloc] initWithGameState:self.gameState];
    goalsVC.delegate = self;
 
    [self _showModal:goalsVC];
}

- (void) _showModal:(TAModal *)theVC{
    if(_myModalViewController) [self _hideModal];
    
    UIView *glView = [[CCDirector sharedDirector] view];
    
    _modalNav = [[UINavigationController alloc] initWithRootViewController:theVC];
    _modalNav.navigationBarHidden = YES;
    
    [glView addSubview:_modalNav.view];

    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone){
        _modalNav.view.frame = glView.bounds;
    }else{
        _modalNav.view.frame = CGRectMake(200, 200, 400, 320);
        UIImage *closeImage = [UIImage imageNamed:@"closebox.png"];
        
        UIButton *close = [[UIButton alloc] initWithFrame:CGRectMake(_modalNav.view.frame.origin.x - closeImage.size.width/2,
                                                                           _modalNav.view.frame.origin.y - closeImage.size.height/2,
                                                                           closeImage.size.width,
                                                                           closeImage.size.height)];
        [close setImage:closeImage forState:UIControlStateNormal];
        [close addTarget:self action:@selector(_hideModal) forControlEvents:UIControlEventTouchUpInside];
        theVC.closeButton = close;
        [glView addSubview:close];
        
    }
    
    _myModalViewController = theVC;
    
}

- (void) _hideModal{
    [_modalNav.view removeFromSuperview];
    [_modalNav viewWillDisappear:NO];
    [_myModalViewController.closeButton removeFromSuperview];
    _modalNav = nil;
}


- (void) financesFinished:(FinancesViewController *)theFinancesVC{
   [self _hideModal];
    financesVC = nil;
}

- (void) goalsFinished:(GoalsViewController *)theGoalsVC{
    [self _hideModal];
    goalsVC = nil;
}

- (void) _updateGoalDisplay{
    ScenarioGoal *g = [self.gameState easiestUnmetGoal];
    
    goalsButton.label.string = [g formatResult:g.lastEvaluationResult descriptionLevel:GoalFormat_StatusBar];
    
    dispatch_async(dispatch_get_main_queue(), ^{
     //   goalsButton.title = [g formatResult:g.lastEvaluationResult descriptionLevel:GoalFormat_StatusBar];
        
      /*  goalsProgressBar.frame = CGRectMake(goalsProgressBar.frame.origin.x,
                                            goalsProgressBar.frame.origin.y,
                                            g.lastEvaluationResult.progress*goalsButton.frame.size.width,
                                            goalsProgressBar.frame.size.height);
        [goalsProgressBar setNeedsDisplay];
        [goalsProgressBar.superview setNeedsDisplay];*/
        
    });
}

#pragma mark -

- (void) setNamesVisible:(BOOL)newNamesVisible{
    _namesLayerOn = newNamesVisible;
    for(CCSprite *s in _nameSprites){
        s.visible = _namesLayerOn;
    }
}

- (void) setShowPopulationHeatmap:(BOOL)show{
    _heatMap.visible = show;
}

- (BOOL) showPopulationHeatmap{
    return _heatMap.visible;
}

- (void) _createAndRemoveStationSprites{
    for (Station *s in self.gameState.stations.allValues){
        if(![_stationSprites objectForKey:s.UUID]){
            //NSLog(@"Making sprite for station with ID %@",s.UUID);
            StationNode *stationSprite = [[StationNode alloc] init];
            stationSprite.position = [self.gameState.map.landLayer positionAt:s.tileCoordinate];
            stationSprite.scale = [self scaleConsideringZoom:1];
            stationSprite.dotScale = STATION_SPRITE_SCALE_UNSELECTED;
            stationSprite.anchorPoint = CGPointMake(0.5, 0.5);
            stationSprite.delegate = self;
            stationSprite.stationUUID = s.UUID;
            
            [tiledMap addChild:stationSprite z:100];
            
            _stationSprites[s.UUID] = stationSprite;
            [s addObserver:self forKeyPath:@"totalPassengersWaiting" options:NSKeyValueObservingOptionInitial context:nil];
            [s addObserver:self forKeyPath:@"upgrades" options:NSKeyValueObservingOptionInitial context:nil];
            [s addObserver:self forKeyPath:@"connectedPOI" options:NSKeyValueObservingOptionInitial context:nil];
            
        }
    }
    
    NSArray *stationIdsWeHaveSpritesFor = _stationSprites.allKeys;
    for(NSString *stationID in stationIdsWeHaveSpritesFor){
        if(!self.gameState.stations[stationID]){
            [_stationSprites[stationID] removeFromParent];
            [_stationSprites removeObjectForKey:stationID];
        }
    }
}

- (void) _createAndRemoveTrackSprites{
    for(TrackSegment *segment in self.gameState.trackSegments.allValues){
        if(![_trackSprites objectForKey:segment.UUID]){
            //NSLog(@"Making sprite for track with ID %@",segment.UUID);
            TracksNode *node = [[TracksNode alloc] init];
            node.userInteractionEnabled = YES;
         //   node.claimsUserInteraction = YES;
            node.start = [((StationNode *)_stationSprites[segment.startStation.UUID]) position];
            node.end = [((StationNode *)_stationSprites[segment.endStation.UUID]) position];
            //NSLog(@"making track sprite for segment %@",segment);
            node.segment = segment;
            node.valid = YES;
            node.delegate = self;
            _trackSprites[segment.UUID] = node;
        //    [[CCDirector sharedDirector].touchDispatcher addTargetedDelegate:node priority:5 swallowsTouches:YES];
            [tiledMap addChild:node z:99];
        }
    }
    
    NSArray *trackIdsWeHaveSpritesFor = _trackSprites.allKeys;
    for(NSString *trackID in trackIdsWeHaveSpritesFor){
        if(!self.gameState.trackSegments[trackID]){
            [_trackSprites[trackID] removeFromParent];
            [_trackSprites removeObjectForKey:trackID];
        }
    }
}

- (Station *) stationAtNodeCoords:(CGPoint)thePoint{
    for(NSString *stationID in _stationSprites.keyEnumerator){
        StationNode *sprite = _stationSprites[stationID];
        if(CGRectContainsPoint(CGRectInset(sprite.boundingBox, -40, -40), thePoint)){
            return self.gameState.stations[stationID];
        }
    }
    
    return nil;
}

- (void) _makeNeighborhoodNameSprites{
    for(NSDictionary *obj in self.gameState.map.neighborhoodNames.objects){
        
        CGPoint pos = CGPointMake([obj[@"x"] intValue], [obj[@"y"] intValue]);
        CGSize size = CGSizeMake([obj[@"width"] intValue], [obj[@"height"] intValue]);
        CGPoint centered = CGPointMake(pos.x + size.width/2, pos.y + size.height/2);
        
        NSString *name = obj[@"name"];
        if(!name) continue;
        
        CCLabelTTF *neighborhood = [[CCLabelTTF alloc] initWithString:name fontName:@"Palatino-Bold" fontSize:12];
        if([obj[@"type"] isEqual:@"region"]){
            neighborhood.color = [CCColor colorWithUIColor:[UIColor colorWithRed:0 green:0 blue:0 alpha:0]];
            neighborhood.string = [name uppercaseString];
        }else if([obj[@"type"] isEqual:@"water"]){
            neighborhood.color = [CCColor colorWithUIColor:[UIColor colorWithRed:1 green:1 blue:1 alpha:1]];
            neighborhood.fontName = @"Palatino-Italic";
        }
        neighborhood.position = centered;
        neighborhood.opacity = 0.5;
        neighborhood.scale = [self scaleConsideringZoom:1 useContentScale:NO];
        [tiledMap addChild:neighborhood z:100];
        [_nameSprites addObject:neighborhood];
    }
}

- (void) _makeStreetSprites{
    for(NSDictionary *obj in self.gameState.map.streets.objects){
        if(![obj[@"type"] isEqual:@"street"]) continue;
        
        CGPoint pos = CGPointMake([obj[@"x"] intValue] * tiledMap.scale,
                                  [obj[@"y"] intValue] * tiledMap.scale);
        
        StreetType type;
        NSString *subtype = obj[@"street-type"];
        if([subtype isEqual:@"highway"]){
            type = StreetType_Highway;
        }else if([subtype isEqual:@"railroad"]){
            type = StreetType_Railroad;
        }else{
            type = StreetType_Regular;
        }
        StreetNode *n = [[StreetNode alloc] initWithBase:pos
                                                  points:obj[@"polylinePoints"]
                                                    type:type];
        
        
        [tiledMap addChild:n z:10];
        [_streetSprites addObject:n];
    }
}

- (void) _createAndRemoveTrainSprites{
    // clean up sprites for trains that no longer exist
    NSMutableSet *existingTrainUUIDS = [NSMutableSet setWithArray:self.gameState.assignedTrains.allKeys];
    NSMutableSet *existingTrainSpriteUUIDS = [NSMutableSet setWithArray:_trainSprites.allKeys];
    
    [existingTrainSpriteUUIDS minusSet:existingTrainUUIDS];
    [existingTrainSpriteUUIDS unionSet:[NSSet setWithArray:self.gameState.unassignedTrains.allKeys]];
    for(NSString *uuid in existingTrainSpriteUUIDS){
        CCSprite *obsoleteSprite = _trainSprites[uuid];
        NSLog(@"removing sprite for train %@",uuid);
        [tiledMap removeChild:obsoleteSprite cleanup:YES];
        [_trainSprites removeObjectForKey:uuid];
    }
    
    // add sprites for trains that need them
    for(NSString *uuid in self.gameState.assignedTrains.allKeys){
        Train *t = self.gameState.assignedTrains[uuid];
        if(!_trainSprites[uuid]){
            
            TrainNode *tNode = [[TrainNode alloc] init];
            tNode.color = t.currentRoute.line.color;
            tNode.scale = [self scaleConsideringZoom:1];
            tNode.anchorPoint = CGPointMake(0.5, 0.05); // the tip of the pin points where we want it to
            [tiledMap addChild:tNode z:150];
            _trainSprites[uuid] = tNode;
            
            [t addObserver:self forKeyPath:@"totalPassengersOnBoard" options:NSKeyValueObservingOptionInitial context:nil];
        }
    }
}


- (void) _updateTrainSpritePositions{
    if(!_stationSprites.count) return;
    
    // for all the sprites, update their positions
    for(NSString *uuid in _trainSprites.allKeys){
        Train *t = self.gameState.assignedTrains[uuid];
        TrainNode *s = _trainSprites[uuid];
       
        s.color = t.currentRoute.line.color;
        
        // stagger the placement a little so the pins aren't all on top of each other
        const CGFloat jitterPerColor = 2;
        //CGFloat stationOffset = (((CCSprite *)[_stationSprites allValues][0]).contentSize.width * [self scaleConsideringZoom:STATION_SPRITE_SCALE_UNSELECTED]);
        CGFloat lineJitter = (-2 * jitterPerColor) + ((float)t.currentRoute.line.color * jitterPerColor);
        
        RouteChunk *currentChunk = t.currentRoute.routeChunks[t.currentRouteChunk];
        CGPoint originNodeCoord = [self.gameState.map.landLayer positionAt:currentChunk.origin.tileCoordinate];
        CGPoint destNodeCoord = [self.gameState.map.landLayer positionAt:currentChunk.destination.tileCoordinate];
        
        CGPoint currentCoord = CGPointMake(originNodeCoord.x + ((destNodeCoord.x - originNodeCoord.x) * t.currentChunkPosition) - (s.contentSize.width/2) + lineJitter,
                                           originNodeCoord.y + ((destNodeCoord.y - originNodeCoord.y) * t.currentChunkPosition) + lineJitter);
        
        s.position = currentCoord;
    }
}


- (void) _createAndRemoveUnbuiltPOISprites{
    NSDictionary *poisWithoutStations = self.gameState.poisWithoutStations;
    for(NSString *poiID in poisWithoutStations.allKeys){
        if(!_unbuiltPOISprites[poiID]){
            // create sprite
            PointOfInterest *poi = poisWithoutStations[poiID];
            POIPlaceholderNode *node = [[POIPlaceholderNode alloc] initWithGlyph:[NSString stringWithFormat:@"connection-%@.png",poi.type]
                                                                     displayName:poi.name];
            
            node.position = [self.gameState.map.landLayer positionAt:poi.location];
            node.scale = [self scaleConsideringZoom:1 useContentScale:NO];
            [tiledMap addChild:node];
            _unbuiltPOISprites[poiID] = node;
        }
    }
    
    for(NSString *poiID in _unbuiltPOISprites.allKeys){
        if(!poisWithoutStations[poiID]){
            //remove, they built a station
            [(POIPlaceholderNode *)_unbuiltPOISprites[poiID] removeFromParent];
            [_unbuiltPOISprites removeObjectForKey:poiID];
        }
    }
}


#pragma mark -

- (void) tracks:(TracksNode *)tracks gotClicked:(CGPoint)touchLoc{
    if(!_popover){
        _tracksInspector = [[TracksInspector alloc] initWithTracks:tracks.segment gameState:self.gameState];
        _tracksBeingInspected = tracks.segment;
        _popover = [[PopoverView alloc] init];
        _popover.delegate = self;
        [_popover showAtPoint:touchLoc
                       inView:[CCDirector sharedDirector].view
              withContentView:_tracksInspector.view];
    }
}

- (void) stationNodeClicked:(StationNode *)stationNode{
    if(!_popover){
        Station *s = self.gameState.stations[stationNode.stationUUID];
        
        _stationInspector = [[StationInspector alloc] initWithStation:s gameState:self.gameState];
        _stationBeingInspected = s;
        _modalNav = [[UINavigationController alloc] initWithRootViewController:_stationInspector];
        _modalNav.navigationBarHidden = YES;
        _modalNav.view.frame = CGRectMake(0, 0, _stationInspector.view.frame.size.width, _stationInspector.view.frame.size.height);
        _popover = [[PopoverView alloc] init];
        _popover.delegate = self;
        
        [_popover showAtPoint:[[CCDirector sharedDirector] convertToUI:[stationNode.parent convertToWorldSpace:stationNode.position]]
                       inView:[CCDirector sharedDirector].view
              withContentView:_modalNav.view];
        
        _coverageOverlay = [[StationCoverageOverlay alloc] init];
        _coverageOverlay.position = stationNode.position;
        _coverageOverlay.walkTiles = GAME_STATION_WALK_RADIUS_TILES;
        _coverageOverlay.carTiles = GAME_STATION_CAR_RADIUS_TILES;
        _coverageOverlay.makeCarPartDarker = [s.upgrades containsObject:StationUpgrade_ParkingLot];
        [tiledMap addChild:_coverageOverlay z:50];
    }
}

- (void)popoverViewDidDismiss:(PopoverView *)popoverView{
    _popover = nil;
    [tiledMap removeChild:_coverageOverlay];
    _coverageOverlay = nil;
    
    _stationBeingInspected = nil;
    _tracksBeingInspected = nil;
}

#pragma mark -

- (void) goalCompleted:(NSNotification *)notification{
    ScenarioGoal *goal = notification.userInfo[@"goal"];
    
    [[OALSimpleAudio sharedInstance] playEffect:SoundEffect_CompleteGoal];
    
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Goal Completed"
                                                    message:[NSString stringWithFormat:@"You completed the goal '%@!'",goal.caption]
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles: nil];
    
    [alert show];
}

- (void) bondIssued{
    [[OALSimpleAudio sharedInstance] playEffect:SoundEffect_CashRegister];
}

- (void) hourChime{
    unsigned hour = self.gameState.currentDateComponents.tm_hour;
    
    if(hour == (GAME_START_NIGHT_HOUR+1)){
        [[OALSimpleAudio sharedInstance] playEffect:SoundEffect_Owl];
    }else if(hour == GAME_END_NIGHT_HOUR){
        [[OALSimpleAudio sharedInstance] playEffect:SoundEffect_Rooster];
    }
}

- (void) stationBuilt{
    [[OALSimpleAudio sharedInstance] playEffect:SoundEffect_BuildStation];
    [self.gameState forceGoalEvaluate];
}

@end
