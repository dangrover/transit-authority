//
//  StreetNode.h
//  Transit Authority
//
//  Created by Dan Grover on 7/15/13.
//
//

#import "cocos2d.h"
#import <OpenGLES/EAGL.h>

typedef enum{
    StreetType_Regular,
    StreetType_Highway,
    StreetType_Railroad
} StreetType;

@interface StreetNode : CCNode
- (id) initWithBase:(CGPoint)base points:(NSString *)polylinePoints type:(StreetType)theType;

@end
