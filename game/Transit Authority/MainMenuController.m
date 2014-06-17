//
//  MainMenuController.m
//  Transit Authority
//
//  Created by Dangrover on 3/15/14.
//  Copyright (c) 2014 Brown Bag Software LLC. All rights reserved.
//

#import "MainMenuController.h"
#import "GameScenario.h"
#import "cocos2d.h"
#import "GameState.h"
#import "MainGameScene.h"
#import "OALSimpleAudio.h"

@implementation MainMenuController{
    BOOL _started;
}

- (void) opened{
   /* if(!_started){
        [[OALSimpleAudio sharedInstance] playBg:@"theme-music.mp3" loop:YES];
        _started = YES;
    }*/
}

- (void) newGame{
    GameScenario *scenario = [[GameScenario alloc] initWithJSON:[[NSBundle mainBundle] pathForResource:@"boston" ofType:@"json"]];
    
    GameState *state = [[GameState alloc] initWithScenario:scenario];
    
    [[OALSimpleAudio sharedInstance] stopEverything];
    
    MainGameScene *scene = [[MainGameScene alloc] initWithGameState:state];
    [[CCDirector sharedDirector] replaceScene:scene withTransition:[CCTransition transitionFadeWithDuration:0.5]];
}


- (void) feedback{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:dan@brownbaglabs.com"]];
}

@end
