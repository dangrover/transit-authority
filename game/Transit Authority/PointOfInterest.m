//
//  PointOfInterest.m
//  Transit Authority
//
//  Created by Dan Grover on 9/18/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "PointOfInterest.h"
#import "NSCoding-Macros.h"

@interface POIFacet()
- (id) initWithJsonRepresentation:(NSDictionary *)jsonDict;
@property(assign, nonatomic, readwrite) unsigned strength;
@property(strong, nonatomic, readwrite) NSArray *weightByHour;
@end

@interface PointOfInterest()
@property(strong, nonatomic, readwrite) NSString *identifier;
@property(strong, nonatomic, readwrite) NSDictionary *json; // keep the JSON to serialize later
@property(strong, nonatomic, readwrite) NSString *name; // the name dislayed for this POI
@property(strong, nonatomic, readwrite) NSString *type;
@property(assign, nonatomic, readwrite) CGPoint location; // in tile coordinates

@property(strong, nonatomic, readwrite) POIFacet *emitCom;
@property(strong, nonatomic, readwrite) POIFacet *emitRes;
@property(strong, nonatomic, readwrite) POIFacet *attractCom;
@property(strong, nonatomic, readwrite) POIFacet *attractRes;

@end

@implementation PointOfInterest
- (id) initWithIdentifier:(NSString *)theIdentifier jsonRepresentation:(NSDictionary *)jsonDict{
    if(self = [super init]){
        self.identifier = theIdentifier;
        self.json = jsonDict;
        self.name = jsonDict[@"name"];
        self.type = jsonDict[@"type"];
        self.location = CGPointMake([jsonDict[@"location"][0] unsignedIntValue],
                                    [jsonDict[@"location"][1] unsignedIntValue]);
        
        NSDictionary *emitComJSON = jsonDict[@"emit-com"];
        if(emitComJSON) self.emitCom = [[POIFacet alloc] initWithJsonRepresentation:emitComJSON];
        
        NSDictionary *emitResJSON = jsonDict[@"emit-res"];
        if(emitResJSON) self.emitRes = [[POIFacet alloc] initWithJsonRepresentation:emitResJSON];
        
        NSDictionary *attractResJSON = jsonDict[@"attract-res"];
        if(attractResJSON) self.attractRes = [[POIFacet alloc] initWithJsonRepresentation:attractResJSON];
        
        NSDictionary *attractComJSON = jsonDict[@"attract-com"];
        if(attractComJSON) self.attractCom = [[POIFacet alloc] initWithJsonRepresentation:attractComJSON];
    }
    
    return self;
}

- (NSString *) description{
    return [NSString stringWithFormat:@"<POI: %@>",self.name];
}

#pragma mark - Serialization

- (void)encodeWithCoder:(NSCoder *)encoder {
    encodeObject(_identifier);
    encodeObject(_json);
}

// When decoding the GameScenario from a saved GameState, reread the JSON file.
- (id)initWithCoder:(NSCoder *)decoder {
    decodeObject(_identifier);
    decodeObject(_json);
    return [self initWithIdentifier:_identifier jsonRepresentation:_json];
}

@end

#pragma mark -

@implementation POIFacet

- (id) initWithJsonRepresentation:(NSDictionary *)jsonDict{
    if(self = [super init]){
        self.strength = [jsonDict[@"strength"] unsignedIntValue];
        self.weightByHour = jsonDict[@"weight-by-hour"];
        NSAssert(self.weightByHour.count == 24, @"incorrect length for weight-by-hour");
    }
    
    return self;
}

@end