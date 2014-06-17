//
//  Goals.m
//  Transit Authority
//
//  Created by Dan Grover on 8/14/13.
//
//

#import "Goals.h"
#import "GameState.h"

@implementation ScenarioGoal

- (id) initWithJSON:(NSDictionary *)jsonDict{
    if(self = [super init]){
        self.caption = jsonDict[@"caption"];
    }
    
    return self;
}

- (GoalEvaluationResult) evaluateAgainstState:(GameState *)theState{
    GoalEvaluationResult res;
    res.isMet = YES;
    res.currentValue = [[NSDecimalNumber zero] decimalValue];
    return res;
}

- (NSString *) formatResult:(GoalEvaluationResult)result descriptionLevel:(GoalDescriptionType)type{
    return nil;
}

@end

@implementation MetricScenarioGoal

- (id) initWithJSON:(NSDictionary *)jsonDict{
    if(self = [super initWithJSON:jsonDict]){
        self.key = jsonDict[@"metric-key"];
        self.statType = [MetricScenarioGoal statFromString:jsonDict[@"metric-stat"]];
        self.target = jsonDict[@"metric-target"];
        if(jsonDict[@"metric-interval"]){
            self.interval = [jsonDict[@"metric-interval"] doubleValue];
        }else{
            self.interval = SECONDS_PER_HOUR;
        }
        
        if(self.statType == Stat_SingleValue){
            if(jsonDict[@"metric-interpolation"]){
                self.interpolation = [MetricScenarioGoal interpolationFromString:jsonDict[@"metric-interpolation"]];
            }else{
                self.interpolation = Interpolation_ForwardFill;
            }
        }else{
            self.interpolation = Interpolation_None;
        }
        
        NSString *comparisonStr = jsonDict[@"metric-compare"];
        self.comparison = ([comparisonStr isEqualToString:@"lt"]) ? GoalComparison_Less : GoalComparison_More;
    }
    
    return self;
}

- (NSString *) description{
    return [NSString stringWithFormat:@"<MetricGoal: %@ ~ %@",self.key, self.target];
}

+ (GameStat) statFromString:(NSString *)s{
    if([s isEqualToString:@"average"]){
        return Stat_Average;
    }else if([s isEqualToString:@"sum"]){
        return Stat_Sum;
    }else if([s isEqualToString:@"single-value"]){
        return Stat_SingleValue;
    }else if([s isEqualToString:@"count"]){
        return Stat_Count;
    }else{
        @throw [NSException exceptionWithName:@"ScenarioLoad" reason:@"Unknown metric-stat" userInfo:nil];
    }
}

+ (Interpolation) interpolationFromString:(NSString *)s{
    if([s isEqual:@"backfill"]){
        return Interpolation_BackFill;
    }else if([s isEqual:@"forwardfill"]){
        return Interpolation_ForwardFill;
    }else if([s isEqual:@"midpoint"]){
        return Interpolation_Midpoints;
    }else if([s isEqual:@"none"]){
        return Interpolation_None;
    }else{
        @throw [NSException exceptionWithName:@"ScenarioLoad" reason:@"Unknown metric metric-interpolation" userInfo:nil];
    }
}


- (GoalEvaluationResult) evaluateAgainstState:(GameState *)theState{
    GoalEvaluationResult res;
    
    NSNumber *metric = [theState.ledger getAggregate:self.statType
                                              forKey:self.key
                                  forRollingInterval:self.interval
                                              ending:theState.currentDate
                                         interpolate:self.interpolation];
    
    res.currentValue = [metric decimalValue];
    
    NSComparisonResult compRes = [metric compare:self.target];

    
    if(self.comparison == GoalComparison_Less){
        res.isMet = (compRes == NSOrderedAscending);
    }else{
        res.isMet = ((compRes == NSOrderedDescending) || (compRes == NSOrderedSame));
    }
    
    NSDecimal progressDecimal;
    NSDecimal targetDecimal = [self.target decimalValue];
    NSDecimalDivide(&progressDecimal, &res.currentValue, &targetDecimal, NSRoundPlain);
    res.progress = [[[NSDecimalNumber alloc] initWithDecimal:progressDecimal] floatValue];
    
    return res;
}

- (NSString *) formatResult:(GoalEvaluationResult)result descriptionLevel:(GoalDescriptionType)type{
    
    if([self.key isEqual:GameLedger_NumberOfStations]){
        if(type == GoalFormat_GoalsScreen){
            return [NSString stringWithFormat:@"%d built",
                    [[[NSDecimalNumber alloc] initWithDecimal:result.currentValue] intValue]];
        }
        else{
            return [NSString stringWithFormat:@"%d/%d stations",
                    [[[NSDecimalNumber alloc] initWithDecimal:result.currentValue] intValue],
                    [self.target intValue]];
        }
    }else if([self.key isEqual:GameLedger_PopulationServedProportion]){
        if(type == GoalFormat_GoalsScreen){
            return [NSString stringWithFormat:@"%0.1f%% served",
                    [[[NSDecimalNumber alloc] initWithDecimal:result.currentValue] floatValue]*100];
        }
        else{
            return [NSString stringWithFormat:@"%0.1f%% of pop.",
                    [[[NSDecimalNumber alloc] initWithDecimal:result.currentValue] floatValue]*100];
        }
    }else if([self.key isEqual:GameLedger_TripsMadeOnSystemProportion]){
        if(type == GoalFormat_GoalsScreen){
            return [NSString stringWithFormat:@"%0.1f%% made",
                    [[[NSDecimalNumber alloc] initWithDecimal:result.currentValue] floatValue]*100];
        }
        else{
            return [NSString stringWithFormat:@"%0.1f%%/trips",
                    [[[NSDecimalNumber alloc] initWithDecimal:result.currentValue] floatValue]*100];
        }
    }
    
    return [[[NSDecimalNumber alloc] initWithDecimal:result.currentValue] description];
}

@end

#pragma mark -

@implementation POIConnectionScenarioGoal

- (id) initWithJSON:(NSDictionary *)jsonDict{
    if(self = [super initWithJSON:jsonDict]){
        self.poiIdentifier = jsonDict[@"poi"];
    }
    return self;
}

- (GoalEvaluationResult) evaluateAgainstState:(GameState *)theState{
    GoalEvaluationResult r;
    r.currentValue = [[NSDecimalNumber zero] decimalValue];
    r.isMet = NO;
    r.progress = 0;
    
    Station *s = theState.stationsByConnectedPOI[self.poiIdentifier];
    if(s){
        if(s.links.count > 0){
            r.progress = 1;
            r.isMet = YES;
        }else{
            r.progress = 0.5;
        }
    }
    
    return r;
}

- (NSString *) formatResult:(GoalEvaluationResult)result descriptionLevel:(GoalDescriptionType)type{
    if(type == GoalFormat_StatusBar){
        return self.caption;
    }else{
        if(result.progress == 0.5){
            return @"Station not connected";
        }else if(result.progress == 1){
            return @"Connected!";
        }
        
        return @"No station built";
    }
}

@end