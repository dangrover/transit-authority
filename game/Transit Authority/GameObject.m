//
//  GameObject.m
//  Transit Authority
//
//  Created by Dan Grover on 8/16/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "GameObject.h"
#import "NSCoding-Macros.h"

@interface GameObject()
@property(strong, readwrite) NSString *UUID;
@end

@implementation GameObject
@synthesize UUID;

- (id) init{
    if(self = [super init]){
        CFUUIDRef uuidRef = CFUUIDCreate(NULL);
        NSString *uuidString = CFBridgingRelease(CFUUIDCreateString(NULL, uuidRef));
        self.UUID = uuidString;
        CFRelease(uuidRef);
    }
    
    return self;
}

#pragma mark - Serialization

- (void)encodeWithCoder:(NSCoder *)encoder {
    encodeObject(UUID);
}

- (id)initWithCoder:(NSCoder *)decoder {
    if (self = [self init])
    {
        decodeObject(UUID);
    }
    return self;
}

@end