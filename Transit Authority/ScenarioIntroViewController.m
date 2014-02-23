//
//  ScenarioIntroViewController.m
//  Transit Authority
//
//  Created by Dan Grover on 8/13/13.
//
//

#import "ScenarioIntroViewController.h"
#import "GameScenario.h"
#import "GameState.h"
#import "MainGameScene.h"
#import "AppDelegate.h"

@interface ScenarioIntroViewController ()
@property(readwrite) GameScenario *scenario;

@end

@implementation ScenarioIntroViewController{
    UILabel *_goalDescriptionLabels[SCENARIO_GOAL_TIERS][SCENARIO_GOALS_PER_TIER];
}

- (id) initWithScenario:(GameScenario *)theScenario{
    if(self = [super initWithNibName:@"ScenarioIntroViewController" bundle:nil]){
        self.scenario = theScenario;
    }
    return self;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    
    NSAssert(self.scenario != nil, @"need a scenario");
    
    
    cityName.text = [self.scenario.cityName uppercaseString];
    cityDescription.text = self.scenario.intro;
    backgroundImageView.image = [[UIImage alloc] initWithContentsOfFile:self.scenario.backgroundPath];
    
    NSArray *tiers = self.scenario.goalGroups;
    
    _goalDescriptionLabels[0][0] = tier1goal1;
    _goalDescriptionLabels[0][1] = tier1goal2;
    _goalDescriptionLabels[1][0] = tier2goal1;
    _goalDescriptionLabels[1][1] = tier2goal2;
    _goalDescriptionLabels[2][0] = tier3goal1;
    _goalDescriptionLabels[2][1] = tier3goal2;
    
    
    for(unsigned t = 0; t < SCENARIO_GOAL_TIERS; t++){
        for(unsigned g = 0; g < SCENARIO_GOALS_PER_TIER; g++){
            UILabel *label = _goalDescriptionLabels[t][g];
            if((t < self.scenario.goalGroups.count) && (g < ((NSArray *)self.scenario.goalGroups[t]).count)){
                ScenarioGoal *goal = tiers[t][g];
                label.text = goal.caption;
            }else{
                label.text = @"";
            }
        }
    }
    
}

- (IBAction) back:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction) startGame:(id)sender{
    GameState *state = [[GameState alloc] initWithScenario:self.scenario];
    
    
    [((AppController *)[UIApplication sharedApplication].delegate).navController popToRootViewControllerAnimated:NO];
    MainGameScene *gameScene = [[MainGameScene alloc] initWithGameState:state];
    [[CCDirector sharedDirector] pushScene:gameScene];
}
@end
