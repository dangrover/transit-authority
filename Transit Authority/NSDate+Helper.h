//
//  NSDate+Helper.h
//  Transit Authority
//
//  Created by Dan Grover on 6/30/13.
//
//

#import <Foundation/Foundation.h>

@interface NSDate(Helper)
+ (NSDate *)dateWithoutTime;
- (NSDate *)dateByAddingDays:(NSInteger)numDays;
- (NSDate *)dateAsDateWithoutTime;
- (int)differenceInDaysTo:(NSDate *)toDate;
- (NSString *)formattedDateString;
- (NSString *)formattedStringUsingFormat:(NSString *)dateFormat;
@end
