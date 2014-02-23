//
//  POIPlaceholderNode.h
//  Transit Authority
//
//  Created by Dan Grover on 9/18/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "cocos2d.h"

@interface POIPlaceholderNode : CCNode
- (id) initWithGlyph:(NSString *)glyphFilename displayName:(NSString *)displayName;
@property(strong, readonly) NSString *accompanyingGlyphFilename;
@property(strong, readonly) NSString *displayedName;

@end
