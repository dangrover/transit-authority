//
//  GameLedger.h
//  Transit Authority
//
//  Created by Dan Grover on 7/19/13.
//
//

#import <Foundation/Foundation.h>

typedef enum{
    Stat_Sum,
    Stat_Count,
    Stat_Average,
    Stat_SingleValue // get a single value for the interval, using interpolation if requested
} GameStat;

typedef enum{
    Interpolation_None,
    Interpolation_BackFill,
    Interpolation_ForwardFill,
    Interpolation_Midpoints
} Interpolation;

/// GameLedger is a key-value store for keeping historical statistics.
/// Powers the graphs/stats view. Internally, it uses sqllite for fast lookups.
@interface GameLedger : NSObject

// Insertion
/// Stores the passed value for the passed key a given point in time.
- (void) recordDatum:(NSNumber *)n forKey:(NSString *)key atDate:(NSTimeInterval)date;

/// Stores the passed value for the passed key at a given point in time, but compresses
/// multiple occurrances of the same datum into a single record so that it is more efficient
/// than just calling the other recordDatum: repeatedly. If you wanted to record 5 of the record '1',
/// you would record the datum '5' with the count '5'.
- (void) recordDatum:(NSNumber *)n forKey:(NSString *)key count:(unsigned)count atDate:(NSTimeInterval)date;

/// Convenience method for recording datums where we are mainly interested in the number of times
/// they occur, not the value. Use 0 for the count. Nothing other than the 'count' stat type supported on
/// event rows. No averages, sums, etc.
- (void) recordEventWithKey:(NSString *)key count:(unsigned)count atDate:(NSTimeInterval)date;

// Querying

/// Get a sum, average, count, or single value for the passed key over the passed time interval.
- (NSNumber *) getAggregate:(GameStat)gameStat
                     forKey:(NSString *)key
                      start:(NSTimeInterval)startDate
                        end:(NSTimeInterval)endDate
                interpolate:(Interpolation)interpolate;

- (NSNumber *) getAggregate:(GameStat)gameStat
                     forKey:(NSString *)key
         forRollingInterval:(NSTimeInterval)interval
                     ending:(NSTimeInterval)endDateTime
                interpolate:(Interpolation)interpolate;

- (NSNumber *) getAggregate:(GameStat)gameStat
                     forKey:(NSString *)key
                     forDay:(NSTimeInterval)day;


// Saving space
- (void) coalesceGivenTime:(NSTimeInterval)time;

// Info/Stats
@property(assign, readonly) unsigned rowCount;
@property(retain, readonly) NSSet *activeKeys;


@end