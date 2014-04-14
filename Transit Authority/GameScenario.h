//
//  GameScenario.h
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//
//

#import <Foundation/Foundation.h>
#import "GameLedger.h"
#import "Goals.h"

#define SCENARIO_GOAL_TIERS 3
#define SCENARIO_GOALS_PER_TIER 2

@class GameState;

/// GameScenario is the top-level object holding all of the data associated with a given city level.
@interface GameScenario : NSObject

/// Main initializer. Takes a full path to a JSON file.
- (id) initWithJSON:(NSString *)jsonPath;
@property(strong) NSString *jsonPath;

@property(strong) NSString *cityName; /// The name of the city
@property(assign) float startingCash; /// The amount of money the player starts with
@property(strong) NSDate *startingDate; /// The date the game starts at
@property(strong) NSString *tmxMapPath; /// The filename of the .TMX file holding the map
@property(strong) NSArray *goalGroups; /// Goals for the player to accomplish, grouped by number of stars
@property(strong) NSString *intro; /// Introductory text displayed before the level starts.
@property(strong) NSString *backgroundPath; /// Image to show near the intro text
@property(strong) NSArray *pointsOfInterest; /// An array of PointOfInterests
@end
