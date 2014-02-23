//
//  GameScenario.m
//  Transit Authority
//
//  Created by Dan Grover on 6/6/13.
//
//

#import "GameScenario.h"
#import "GameState.h"
#import "PointOfInterest.h"

@interface MetricScenarioGoal()
- (id) initWithJSON:(NSDictionary *)jsonDict;
@end

@implementation GameScenario{

}

- (id) initWithJSON:(NSString *)jsonPath{
    if(self = [super init]){
        NSLog(@"loading scenario at %@",jsonPath);
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[NSData dataWithContentsOfFile:jsonPath]
                                                             options:NSJSONReadingAllowFragments
                                                               error:&error];
        
        if(error){
            @throw [NSException exceptionWithName:@"ScenarioReadError" reason:@"Error parsing the JSON" userInfo:@{@"error":error}];
        }
        
        self.cityName = dict[@"city-name"];
        self.intro = dict[@"intro"];
        self.startingCash = [dict[@"starting-cash"] floatValue];
        self.startingDate = [NSDate dateWithTimeIntervalSince1970:[dict[@"starting-date"] floatValue]];
        
        NSString *basePath = [jsonPath stringByDeletingLastPathComponent];
        self.tmxMapPath = [basePath stringByAppendingPathComponent:dict[@"tmx-name"]];
        self.backgroundPath = [basePath stringByAppendingPathComponent:dict[@"bg-name"]];
        
     
        
        // load the goal groups
        NSArray *goalGroupsJSON = dict[@"goals"];
        NSMutableArray *parsedGoalGroups = [NSMutableArray array];
        for(NSArray *groupJSON in goalGroupsJSON){
            NSMutableArray *thisGroup = [NSMutableArray array];
            for(NSDictionary *goalJSON in groupJSON){
                ScenarioGoal *goal = nil;
                if([goalJSON[@"type"] isEqualToString:@"metric"]){
                    goal = [[MetricScenarioGoal alloc] initWithJSON:goalJSON];
                }else if([goalJSON[@"type"] isEqualToString:@"poi"]){
                    goal = [[POIConnectionScenarioGoal alloc] initWithJSON:goalJSON];
                }else{
                    NSLog(@"Unknown goal type: %@",goalJSON[@"type"]);
                    continue;
                }
                
                [thisGroup addObject:goal];
            }
            [parsedGoalGroups addObject:thisGroup];
        }

        self.goalGroups = parsedGoalGroups;
        
        // load the POIs
        NSDictionary *poisJSON = dict[@"pois"];
        NSMutableArray *myPOIs = [NSMutableArray arrayWithCapacity:poisJSON.count];
        for(NSString *poiIdent in poisJSON.allKeys){
            [myPOIs addObject:[[PointOfInterest alloc] initWithIdentifier:poiIdent
                                                       jsonRepresentation:poisJSON[poiIdent]]];
            
        }
        self.pointsOfInterest = myPOIs;
    }
    
    return self;
}


@end

