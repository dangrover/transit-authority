//
//  Goals.h
//  Transit Authority
//
//  Created by Dan Grover on 8/14/13.
//
//

#import <Foundation/Foundation.h>
#import "GameLedger.h"

@class GameState;

/// A result from evaluating a goal. We pass back whether the goal was met, as well
/// as the value we used to make the comparison, in case it needs to be displayed. This
/// avoids making an expensive computation twice.
typedef struct{
    BOOL isMet;
    NSDecimal currentValue;
    float progress;
} GoalEvaluationResult;

typedef enum{
    GoalFormat_GoalsScreen,
    GoalFormat_StatusBar
} GoalDescriptionType;

/// A goal for the player to meet in the game. Abstract class.
@interface ScenarioGoal : NSObject

- (id) initWithJSON:(NSDictionary *)jsonDict;

@property(assign) NSTimeInterval expirationInterval; // Expires after this amount after the starting date. If
@property(strong) NSString *caption; /// The human-readable text describing this goal. e.g. "get 10% ridership"
- (GoalEvaluationResult) evaluateAgainstState:(GameState *)theState; /// Evaluates the goal against the current game state and returns a GoalEvaluationResult
- (NSString *) formatResult:(GoalEvaluationResult)result descriptionLevel:(GoalDescriptionType)type; /// Formats the 'currentValue' field in GoalEvaluationResult according to what type of goal this is.

@property(assign) GoalEvaluationResult lastEvaluationResult;

@end

#pragma mark - Metric Goals

typedef enum{
    GoalComparison_Less,
    GoalComparison_More
} GoalComparison;

/// A goal attached to a specific metric the player is to optimize for.
@interface MetricScenarioGoal : ScenarioGoal
@property(strong) NSString *key; /// The key, stored in GameLedger, that we're watching
@property(strong) NSNumber *target; /// The value we want this key to reach
@property(assign) NSTimeInterval interval; /// The interval we're looking at the game ledger over to check for the value (useful for "X riders in a day" goals, etc).
@property(assign) GameStat statType; /// The type of stat that 'target' is (e.g. an average, a sum, etc)
@property(assign) Interpolation interpolation; /// If using Stat_SingleValue, how to interpolate the GameLedger data if there are missing values.
@property(assign) GoalComparison comparison; /// The type of comparison to be done in evaluating th emetric. Default is 'more', meaning the goal is met if the current value exceeds 'target'.

@end

#pragma mark - Other Goals
/// A goal that checks to see if a specific POI is connected to the system
@interface POIConnectionScenarioGoal : ScenarioGoal
@property(strong) NSArray *poiIdentifier;

@end

