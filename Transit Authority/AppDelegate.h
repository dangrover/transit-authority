//
//  AppDelegate.h
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//  Copyright Brown Bag Labs LLC 2013. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "cocos2d.h"

@interface AppController : CCAppDelegate <UIApplicationDelegate, CCDirectorDelegate>


@property (nonatomic, retain) UIWindow *window;
@property (readonly) CCDirectorIOS *director;

- (void) exitToMainMenu;


@end
