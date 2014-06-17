//
//  PointOfInterest.h
//  Transit Authority
//
//  Created by Dan Grover on 9/18/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "GameObject.h"

@class POIFacet;

#define PointOfInterest_Type_TrainStation @"rail"
#define PointOfInterest_Type_Airport @"airport"
#define PointOfInterest_Type_FerryTerminal @"ferry"
#define PointOfInterest_Type_Stadium_Baseball @"stadium-baseball"
//#define PointOfInterest_Type_Stadium_Football @"stadium-football"
//#define PointOfInterest_Type_Stadium_Soccer @"stadium-soccer"
//#define PointOfInterest_Type_Stadium_Hockey @"stadium-hockey"
//#define PointOfInterest_Type_ConferenceCenter @"conference-center"
//#define PointOfInterest_Type_MilitaryBase @"military-base"

@interface PointOfInterest : NSObject
- (id) initWithIdentifier:(NSString *)theIdentifier jsonRepresentation:(NSDictionary *)jsonDict;
@property(strong, nonatomic, readonly) NSString *identifier;
@property(strong, nonatomic, readonly) NSString *name; // the name dislayed for this POI
@property(strong, nonatomic, readonly) NSString *type;
@property(assign, nonatomic, readonly) CGPoint location; // in tile coordinates
@property(strong, nonatomic, readonly) NSArray *facets;

@property(strong, nonatomic, readonly) POIFacet *emitCom;
@property(strong, nonatomic, readonly) POIFacet *emitRes;
@property(strong, nonatomic, readonly) POIFacet *attractCom;
@property(strong, nonatomic, readonly) POIFacet *attractRes;

@end

#pragma mark - Facets

// value of combinations
// emit res   : generates res->com trips
// emit com   : generates com->res trips
// attract res: attracts res->com trips
// attract com: attracts com->res trips

@interface POIFacet : NSObject
@property(assign, nonatomic, readonly) unsigned strength; // equivilent to a tile with this density (normally 0-3)
@property(strong, nonatomic, readonly) NSArray *weightByHour; // how likely is it, in a given hour, to perform the described functio?
@end

