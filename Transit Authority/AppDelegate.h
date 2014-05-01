//
//  AppDelegate.h
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//  Copyright Brown Bag Labs LLC 2013. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "cocos2d.h"
#import "GameState.h"

<<<<<<< HEAD
@interface AppController : CCAppDelegate <UIApplicationDelegate, CCDirectorDelegate>
=======
@interface AppController : NSObject <UIApplicationDelegate, CCDirectorDelegate>
{
	UIWindow *window_;
	UINavigationController *navController_;
    
    GameState *savedState_;
>>>>>>> master


@property (nonatomic, retain) UIWindow *window;
@property (readonly) CCDirectorIOS *director;

- (void) exitToMainMenu;


@end
