//
//  AppDelegate.m
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//  Copyright Brown Bag Labs LLC 2013. All rights reserved.
//

#import <TestFlightSDK/TestFlight.h>
#import "AppDelegate.h"
#import "GameScenario.h"
#import "GameState.h"
#import "MainGameScene.h"
#import "MainMenuViewController.h"
#import "TouchCanceler.h"


@implementation AppController
@synthesize window=window_, navController=navController_, director=director_;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
	// Create the main window
	window_ = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];


	// Create an CCGLView with a RGB565 color buffer, and a depth buffer of 0-bits
	CCGLView *glView = [CCGLView viewWithFrame:[window_ bounds]
								   pixelFormat:kEAGLColorFormatRGBA8	//kEAGLColorFormatRGBA8
								   depthFormat:GL_DEPTH24_STENCIL8
							preserveBackbuffer:NO
									sharegroup:nil
								 multiSampling:NO
							   numberOfSamples:0];
    [glView setMultipleTouchEnabled:YES];
    
    
	director_ = (CCDirectorIOS*) [CCDirector sharedDirector];
	director_.wantsFullScreenLayout = YES;
	[director_ setDisplayStats:NO]; // Display FSP and SPF
    [director_ setDelegate:self]; // for rotation and other messages
    [director_ setProjection:kCCDirectorProjection2D];
    [director_ setAnimationInterval:1.0/60];
	[director_ setView:glView]; // attach the openglView to the director
	

	// Enables High Res mode (Retina Display) on iPhone 4 and maintains low res on all other devices
	if( ! [director_ enableRetinaDisplay:YES] )	CCLOG(@"Retina Display Not supported");

	// Default texture format for PNG/BMP/TIFF/JPEG/GIF images
	[CCTexture2D setDefaultAlphaPixelFormat:kCCTexture2DPixelFormat_RGBA8888];
    [CCTexture2D PVRImagesHavePremultipliedAlpha:YES]; // Assume that PVR images have premultiplied alpha
    
	CCFileUtils *sharedFileUtils = [CCFileUtils sharedFileUtils];
	[sharedFileUtils setEnableFallbackSuffixes:NO];				// Default: NO. No fallback suffixes are going to be used
	[sharedFileUtils setiPhoneRetinaDisplaySuffix:@"@-hd"];		// Default on iPhone RetinaDisplay is "-hd"
	[sharedFileUtils setiPadSuffix:@""];					// Default on iPad is "ipad"
	[sharedFileUtils setiPadRetinaDisplaySuffix:@"@-hd"];	// Default on iPad RetinaDisplay is "-ipadhd"
    
	// Create a Navigation Controller with the Director
	navController_ = [[UINavigationController alloc] initWithRootViewController:director_];
	navController_.navigationBarHidden = YES;
	[window_ setRootViewController:navController_];
	[window_ makeKeyAndVisible];
    
    MainMenuViewController *mm = [[MainMenuViewController alloc] initWithNibName:nil bundle:nil];
    [navController_ pushViewController:mm animated:NO];
    
    [[UIApplication sharedApplication] setStatusBarHidden:YES withAnimation:UIStatusBarAnimationNone];
	
    TouchCanceler *canceler = [[TouchCanceler alloc] init];
    [director_.touchDispatcher addTargetedDelegate:canceler priority:0 swallowsTouches:YES];
    
    // testflight
    [TestFlight setDeviceIdentifier:[[[UIDevice currentDevice] identifierForVendor] UUIDString]];
    [TestFlight takeOff:@"36d93e59-b263-4c26-a1e8-1fe37b7e934e"];
    
	return YES;
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
    NSLog(@"should autorotate to %d? %d",interfaceOrientation, UIInterfaceOrientationIsLandscape(interfaceOrientation));
    
	return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}


// getting a call, pause the game
-(void) applicationWillResignActive:(UIApplication *)application
{
	if( [navController_ visibleViewController] == director_ )
		[director_ pause];
}

// call got rejected
-(void) applicationDidBecomeActive:(UIApplication *)application
{
	if( [navController_ visibleViewController] == director_ )
		[director_ resume];
}

-(void) applicationDidEnterBackground:(UIApplication*)application
{
	if( [navController_ visibleViewController] == director_ )
		[director_ stopAnimation];
}

-(void) applicationWillEnterForeground:(UIApplication*)application
{
	if( [navController_ visibleViewController] == director_ )
		[director_ startAnimation];
}

// application will be killed
- (void)applicationWillTerminate:(UIApplication *)application
{
	CC_DIRECTOR_END();
}

// purge memory
- (void)applicationDidReceiveMemoryWarning:(UIApplication *)application
{
	[[CCDirector sharedDirector] purgeCachedData];
}

// next delta time will be zero
-(void) applicationSignificantTimeChange:(UIApplication *)application
{
	[[CCDirector sharedDirector] setNextDeltaTimeZero:YES];
}

#pragma mark - Application State

- (BOOL)application:(UIApplication *)application shouldSaveApplicationState:(NSCoder *)coder {
    return YES;
}

- (BOOL)application:(UIApplication *)application shouldRestoreApplicationState:(NSCoder *)coder {
    return YES;
}

- (void)application:(UIApplication *)application willEncodeRestorableStateWithCoder:(NSCoder *)coder
{
    CCScene *runningScene = self.director.runningScene;
    if ([runningScene isKindOfClass:[MainGameScene class]])
    {
        NSLog(@"Saving Game State");
        MainGameScene *gameScene = (MainGameScene *)runningScene;
        [coder encodeObject:gameScene.gameState forKey:@"Game State"];
    }
    else
    {
        NSLog(@"Not saving Game State. Open scene is not game scene.");
    }
}

- (void)application:(UIApplication *)application didDecodeRestorableStateWithCoder:(NSCoder *)coder {
    NSLog(@"Loading Game State...");

    GameState *gameState;
    @try {
        gameState = [coder decodeObjectForKey:@"Game State"];
    }
    @catch (NSException *exception) {
        NSLog(@"Something went terribly wrong while loading the game state.");
    }
    @finally {
        if (gameState)
        {
            NSLog(@"Loaded: %@", gameState);
        }
        else
        {
            NSLog(@"No game state found");
        }
    }
}

- (void) exitToMainMenu{
   
    for(UIView *v in [CCDirector sharedDirector].view.subviews){
        [v removeFromSuperview];
    }
    
    [director_ popScene];
    
    MainMenuViewController *mm = [[MainMenuViewController alloc] initWithNibName:nil bundle:nil];
    [navController_ pushViewController:mm animated:NO];
    
}
@end

