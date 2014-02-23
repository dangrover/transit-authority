//
//  MainMenuViewController.m
//  Transit Authority
//
//  Created by Dan Grover on 7/16/13.
//
//

#import "MainMenuViewController.h"
#import "GameScenario.h"
#import "GameState.h"
#import "MainGameScene.h"
#import "AppDelegate.h"
#import "InstructionsViewController.h"
#import "ScenarioIntroViewController.h"
#import "TestFlight.h"

@interface MainMenuViewController ()

@end

@implementation MainMenuViewController{
    AVPlayer *_player;
    ScenarioIntroViewController *_intro;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        _player = [[AVPlayer alloc] initWithURL:[[NSBundle mainBundle] URLForResource:@"menu-music" withExtension:@"mp3"]];
    }
    return self;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
 
}

- (void) viewWillAppear:(BOOL)animated{
    [[UIApplication sharedApplication] setStatusBarOrientation:UIInterfaceOrientationLandscapeRight animated:YES];
    
#if !(TARGET_IPHONE_SIMULATOR)
    [_player play];
#endif

}

- (IBAction)chooseScenario:(id)sender{
    // Hard-code Boston for now
    GameScenario *scenario = [[GameScenario alloc] initWithJSON:[[NSBundle mainBundle] pathForResource:@"boston" ofType:@"json"]];
    
    _intro = [[ScenarioIntroViewController alloc] initWithScenario:scenario];
    [((AppController *)[UIApplication sharedApplication].delegate).navController pushViewController:_intro animated:YES];
    
    /*
    UIActionSheet *sheet = [[UIActionSheet alloc] initWithTitle:@"Choose Scenario"
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:@"Boston", @"San Francisco", nil];
    
    [sheet showInView:self.view];*/
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex{
/*
    
    NSArray *jsons = @[@"boston", @"sf"];
    
    if(buttonIndex >= jsons.count) return;
    
    NSString *jsonName = jsons[buttonIndex];
    GameScenario *scenario = [[GameScenario alloc] initWithJSON:[[NSBundle mainBundle] pathForResource:jsonName ofType:@"json"]];
    
    _intro = [[ScenarioIntroViewController alloc] initWithScenario:scenario];
    [((AppController *)[UIApplication sharedApplication].delegate).navController pushViewController:_intro animated:YES];
 
 */
}

- (IBAction)sendFeedback:(id)sender{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"mailto:dan@brownbaglabs.com"]];
}

- (IBAction)readHelp:(id)sender{
    InstructionsViewController *ivc = [[InstructionsViewController alloc] initWithNibName:nil bundle:nil];
    [self presentViewController:ivc animated:YES completion:^{}];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation{
	return UIInterfaceOrientationIsLandscape(interfaceOrientation);
}

@end
