//
//  GoalsViewController.m
//  Transit Authority
//
//  Created by Dan Grover on 8/13/13.
//
//

#import "GoalsViewController.h"

@interface GoalsViewController ()
@property(strong, readwrite) GameState *state;
@end

@implementation GoalsViewController{
    NSArray *_statusCheckboxes;
    NSArray *_statusLabels;
    NSArray *_captionLabels;
    GoalEvaluationResult _evalResults[SCENARIO_GOAL_TIERS][SCENARIO_GOALS_PER_TIER];
}

- (id) initWithGameState:(GameState *)state{
    if (self = [super initWithNibName:@"GoalsViewController" bundle:nil]){
        self.state = state;
    }
    return self;
}

- (void) dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


- (void) _updateDisplay{
    
    _captionLabels = @[@[tier1goal1Caption, tier1goal2Caption],
                       @[tier2goal1Caption, tier2goal2Caption],
                       @[tier3goal1Caption, tier3goal2Caption]];
    
    _statusLabels = @[@[tier1goal1Status, tier1goal2Status],
                      @[tier2goal1Status, tier2goal2Status],
                      @[tier3goal1Status, tier3goal2Status]];
    
    _statusCheckboxes = @[@[tier1goal1Check, tier1goal2Check],
                          @[tier2goal1Check, tier2goal2Check],
                          @[tier3goal1Check, tier3goal2Check]];
    
    
    // Okay, now go populate everything
    NSArray *tiers = self.state.originalScenario.goalGroups;
    
    for(unsigned t=0; t < SCENARIO_GOAL_TIERS; t++){
        for(unsigned g=0; g < SCENARIO_GOALS_PER_TIER; g++){
            UIImageView *checkbox = _statusCheckboxes[t][g];
            UILabel *status = _statusLabels[t][g];
            UILabel *caption = _captionLabels[t][g];
            if((t < tiers.count) && (g < ((NSArray *)tiers[t]).count)){
                ScenarioGoal *goal = tiers[t][g];
                GoalEvaluationResult res = _evalResults[t][g] = goal.lastEvaluationResult;
                
                if(res.isMet){
                    checkbox.image = [UIImage imageNamed:@"checkbox-checked"];
                    // @{NSStrikethroughStyleAttributeName: @(NSUnderlineStyleSingle)
                    caption.attributedText = [[NSAttributedString alloc] initWithString:goal.caption attributes:nil];
                }else{
                    caption.attributedText = [[NSAttributedString alloc] initWithString:goal.caption attributes:nil];
                    checkbox.image = [UIImage imageNamed:@"checkbox-unchecked"];
                }
                
                status.text = [goal formatResult:res descriptionLevel:GoalFormat_GoalsScreen];
                
            }else{
                status.text = caption.text = @"";
                checkbox.image = nil;
            }
        }
    }
}

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self _updateDisplay];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_updateDisplay)
                                                 name:GameStateNotification_CheckedGoals
                                               object:self.state];
}

- (IBAction)back:(id)sender{
    [self.delegate goalsFinished:self];
}

@end
