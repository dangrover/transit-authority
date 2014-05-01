//
//  GameLedger.m
//  Transit Authority
//
//  Created by Dan Grover on 7/19/13.
//
//

#import "GameLedger.h"
#import "NSDate+Helper.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "GameConstants.h"
#import "NSCoding-Macros.h"

#define KEY_SEPERATOR @"."

@implementation GameLedger{
    NSString *_path;
    FMDatabase *_db;
    NSMutableSet *_activeKeys;
}

- (id) initWithPath:(NSString *)path {
    
    if(self = [super init]){
        
        _path = path;
        _db = [[FMDatabase alloc] initWithPath:_path];
        _db.logsErrors = YES;
        _db.crashOnErrors = YES;
        _db.shouldCacheStatements = YES;
        
        [_db open];
    }
    
    return self;
}

- (id) init {
    
    // Create a new database on disk.
    NSString *tmPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.sqlite",[[NSUUID UUID] UUIDString]]];
    NSLog(@"DATABASE PATH IS %@",tmPath);

    if (self = [self initWithPath:tmPath])
    {
        NSString *schema = [NSString stringWithContentsOfURL:[[NSBundle mainBundle] URLForResource:@"ledger" withExtension:@"sql"] usedEncoding:nil error:nil];
        //NSLog(@"schema = %@",schema);
        [_db beginTransaction];
        [_db executeUpdate:schema];
        [_db commit];
    }
    
    return self;
}

// This deletes the database file permanently. It should be called the user quits a game.
- (void)destroy {
    [_db close];
}

- (void) recordDatum:(NSNumber *)n forKey:(NSString *)key atDate:(NSTimeInterval)date{
    [self recordDatum:n forKey:key count:1 atDate:date];
}

- (void) recordDatum:(NSNumber *)n forKey:(NSString *)key count:(unsigned)count atDate:(NSTimeInterval)date{
    //  [_db beginTransaction];
    
    NSArray *components = [key componentsSeparatedByString:KEY_SEPERATOR];
    if(components.count == 1){
        if(![_db executeUpdate:@"INSERT INTO ledger (time, key, value, multiplier, period) VALUES (?,?,?,?,?);"
          withArgumentsInArray:@[@(floor(date)), key, n, @(count), @(0)]]){
            NSLog(@"Could not insert into ledger");
        }
    }else{
        if(![_db executeUpdate:@"INSERT INTO ledger (time, key, subkey, value, multiplier, period) VALUES (?,?,?,?,?,?);"
          withArgumentsInArray:@[@(floor(date)), components[0], components[1], n, @(count), @(0)]]){
            NSLog(@"Could not insert into ledger");
        }
    }
    
    //  [_db commit];
}


- (void) recordEventWithKey:(NSString *)key count:(unsigned)count atDate:(NSTimeInterval)date{
//    [_db beginTransaction];
    
    NSArray *components = [key componentsSeparatedByString:KEY_SEPERATOR];
    if(components.count == 1){
        if(![_db executeUpdate:@"INSERT INTO ledger (time, key, value, multiplier, period) VALUES (?,?,?,?,?);"
          withArgumentsInArray:@[@(floor(date)), key, @(0), @(count), @(0)]]){
            NSLog(@"Could not insert into ledger");
        }
    }
    else{
        if(![_db executeUpdate:@"INSERT INTO ledger (time, key, subkey, value, multiplier, period) VALUES (?,?,?,?,?,?);"
          withArgumentsInArray:@[@(floor(date)), components[0], components[1], @(0), @(count), @(0)]]){
            NSLog(@"Could not insert into ledger");
        }
    }
  //  [_db commit];
}

- (void) recordEventWithKey:(NSString *)key atDate:(NSTimeInterval)date{
    [self recordDatum:@(1) forKey:key atDate:date];
}


- (NSNumber *) getAggregate:(GameStat)gameStat forKey:(NSString *)key start:(NSTimeInterval)startDate end:(NSTimeInterval)endDate interpolate:(Interpolation)interpolate{
    
    NSArray *keyComponents = [key componentsSeparatedByString:KEY_SEPERATOR];
    NSString *keyClause = (keyComponents.count == 1) ? @"key=?" : @"key=? AND subkey=?";
    
    if(gameStat == Stat_Sum){
        FMResultSet *r = [_db executeQuery:[NSString stringWithFormat:@"SELECT SUM(value) as value, SUM(multiplier) as rows FROM ledger WHERE %@ and time >= ? and time <= ?;",keyClause]
                      withArgumentsInArray:[keyComponents arrayByAddingObjectsFromArray:@[@(startDate),@(endDate)]]];
        
        [r next];
        double val = [r doubleForColumn:@"value"];
        int rows = [r intForColumn:@"rows"];
        return @(rows ? val : 0);
        
    }else if(gameStat == Stat_Count){
        FMResultSet *r = [_db executeQuery:[NSString stringWithFormat:@"SELECT SUM(multiplier) as weighted FROM ledger WHERE %@ and time >= ? and time <= ?;", keyClause]
                      withArgumentsInArray:[keyComponents arrayByAddingObjectsFromArray:@[@(startDate),@(endDate)]]];
        [r next];
        double num = [r doubleForColumn:@"weighted"];
        return @(num);
    }else if(gameStat == Stat_Average){
         FMResultSet *r = [_db executeQuery:[NSString stringWithFormat:@"SELECT SUM(value) as weighted, SUM(multiplier) as rows FROM ledger WHERE %@ and time >= ? and time <= ?;", keyClause]
                       withArgumentsInArray:[keyComponents arrayByAddingObjectsFromArray:@[@(startDate),@(endDate)]]];
        
        [r next];
        double num = [r doubleForColumn:@"weighted"];
        double rows = [r doubleForColumn:@"rows"];
        return @(rows ? (num / rows) : 0);
    }
    else if(gameStat == Stat_SingleValue){
        FMResultSet *r = [_db executeQuery:[NSString stringWithFormat:@"SELECT value as v, time as time FROM ledger WHERE %@ and time >= ? and time <= ? ORDER BY time DESC LIMIT 1;", keyClause]
                      withArgumentsInArray:[keyComponents arrayByAddingObjectsFromArray:@[@(startDate),@(endDate)]]];
        
        if([r next]){
            return @([r doubleForColumn:@"v"]);
        }else{
            if(interpolate == Interpolation_None){
                return @(0);
            }else{
                FMResultSet *prevRowResults = [_db executeQuery:[NSString stringWithFormat:@"SELECT value, time FROM ledger WHERE %@ and time<? ORDER BY time DESC LIMIT 1;",keyClause]
                              withArgumentsInArray:[keyComponents arrayByAddingObject:@(startDate)]];
                
                FMResultSet *nextRowResults = [_db executeQuery:[NSString stringWithFormat:@"SELECT value, time FROM ledger WHERE %@ and time>? ORDER BY time LIMIT 1;", keyClause]
                                           withArgumentsInArray:[keyComponents arrayByAddingObject:@(endDate)]];
                
                
                double prevRowVal =  [prevRowResults next] ? [prevRowResults doubleForColumn:@"value"] : 0;
                
                double nextRowVal = [nextRowResults next] ? [nextRowResults doubleForColumn:@"value"] : 0;
                
                if(interpolate == Interpolation_ForwardFill){
                    return @(prevRowVal);
                }else if(interpolate == Interpolation_BackFill){
                    return @(nextRowVal);
                }else if(interpolate == Interpolation_Midpoints){
                    NSTimeInterval prevRowTime = [prevRowResults doubleForColumn:@"time"];
                    NSTimeInterval nextRowTime = [nextRowResults doubleForColumn:@"time"];
                    
                    NSTimeInterval queryMidpoint = startDate + ((endDate - startDate) * 0.5);
                    double proportionAcross = (queryMidpoint - prevRowTime) / (nextRowTime - prevRowTime);
                    return @((proportionAcross * prevRowVal) + ((1.0f - proportionAcross) * nextRowVal));
                }else{
                    NSLog(@"Unknown interpolation %d",interpolate);
                    return @(0);
                }
            }
        }
    }
    
    return @(0);
}

- (NSNumber *) getAggregate:(GameStat)gameStat
                     forKey:(NSString *)key
        forRollingDayEnding:(NSTimeInterval)endDateTime{
    return [self getAggregate:gameStat forKey:key forRollingInterval:24*60*60 ending:endDateTime interpolate:Interpolation_None];
}

- (NSNumber *) getAggregate:(GameStat)gameStat
                     forKey:(NSString *)key
         forRollingInterval:(NSTimeInterval)interval
                     ending:(NSTimeInterval)endDateTime
                interpolate:(Interpolation)interpolate{
    return [self getAggregate:gameStat
                       forKey:key
                        start:endDateTime - interval + 1
                          end:endDateTime + 1
            interpolate:interpolate]; // the end should be inclusive
}

- (NSNumber *)getAggregate:(GameStat)gameStat forKey:(NSString *)key forDay:(NSTimeInterval)day{
    NSDate *start = [[NSDate dateWithTimeIntervalSinceReferenceDate:day] dateAsDateWithoutTime];
    NSDate *end = [start dateByAddingDays:1];
    return [self getAggregate:gameStat
                       forKey:key
                        start:[start timeIntervalSinceReferenceDate]
                          end:[end timeIntervalSinceReferenceDate]
            interpolate:NO];
}


- (void) coalesceGivenTime:(NSTimeInterval)currentTime{
    // (T - 1hr) -> T gets to stay
    // (T - 24hr) -> (T - 1hr) gets coalesced into 1-hour chunks
    
    NSTimeInterval startDelete = floor(currentTime - SECONDS_PER_HOUR);
    NSTimeInterval endDelete = floor(currentTime);
    //NSLog(@"Coalescing at time %f",currentTime);
    //NSLog(@"That means start=%f, end=%f",startDelete, endDelete);
    
    // Take just the entries in the hour before the past hour and sum them up.
    FMResultSet *results = [_db executeQuery:@"SELECT SUM(value) as valueSum, value, SUM(multiplier) as multiplierSum, multiplier, key, subkey FROM ledger WHERE time > ? AND time <= ? GROUP BY key, subkey ORDER BY time ASC;"
                        withArgumentsInArray: @[@(startDelete), @(endDelete)]];
    
    NSMutableArray *newRows = [NSMutableArray array];
    while([results next]){
        [newRows addObject:[results resultDictionary]];
    }
    
    // Delete them from the DB
    BOOL worked = [_db executeUpdate:@"DELETE FROM ledger WHERE time >= ? and time < ?"
                withArgumentsInArray:@[@(startDelete), @(endDelete)]];
    NSAssert(worked, @"error with delete");
    
    // Insert the aggregated versions
    for(NSDictionary *row in newRows){
        
        id value, multiplier;
        if ([row[@"key"] isEqual:GameLedger_NumberOfStations] || [row[@"key"] isEqual:GameLedger_NumberOfRunningTrains])
        {
            // For "number of" stats, the aggregated row is simply the latest row in the time period.
            value = row[@"value"];
            multiplier = row[@"multiplier"];
        }
        else
        {
            // For all other stats, the aggregated row is the sum of the rows in the time period.
            value = row[@"valueSum"];
            multiplier = row[@"multiplierSum"];
        }
        
        if(row[@"subkey"] && ![row[@"subkey"] isEqual:[NSNull null]]){
            worked = [_db executeUpdate:@"INSERT INTO ledger (time, key, subkey, value, multiplier, period) VALUES (?,?,?,?,?,?);"
               withArgumentsInArray:@[@(startDelete), row[@"key"], row[@"subkey"], value, multiplier, @(SECONDS_PER_HOUR)]];
        }else{
            worked = [_db executeUpdate:@"INSERT INTO ledger (time, key, value, multiplier, period) VALUES (?,?,?,?,?);"
                   withArgumentsInArray:@[@(startDelete), row[@"key"], value, multiplier, @(SECONDS_PER_HOUR)]];
        }
        NSAssert(worked, @"could not insert summary row");
    }
    
    //NSSet *keys = [self activeKeys];
    //NSLog(@"active keys = %@",keys);
    //NSLog(@"There are %d rows",[self rowCount]);
}

- (NSSet *) activeKeys{
   // if(!_activeKeys){
        NSMutableSet *a = [NSMutableSet set];
        FMResultSet *r = [_db executeQuery:@"SELECT DISTINCT key, subkey FROM ledger;"];
        while([r next]){
            NSString *k = [r stringForColumn:@"key"];
            NSString *sk = [r stringForColumn:@"subkey"];
            [a addObject:sk ? [NSString stringWithFormat:@"%@.%@",k,sk] : k];
        }
        
        return a; // cache this later
      //  _activeKeys = a;
    //}
    
   // return _activeKeys;
}

- (unsigned) rowCount{
    FMResultSet *r = [_db executeQuery:@"SELECT count(*) as c FROM ledger;"];
    [r next];
    return [r intForColumn:@"c"];
}

#pragma mark - Serialization

// Save the path to the mysql file.
- (void)encodeWithCoder:(NSCoder *)encoder {
    encodeObject(_path);
}

// Open the database from the saved mysql file.
- (id)initWithCoder:(NSCoder *)decoder {
    return [self initWithPath:decodeObject(_path)];
}

@end