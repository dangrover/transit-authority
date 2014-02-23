//
//  POIPlaceholderNode.m
//  Transit Authority
//
//  Created by Dan Grover on 9/18/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "POIPlaceholderNode.h"

@interface POIPlaceholderNode()
@property(strong, readwrite) NSString *accompanyingGlyphFilename;
@property(strong, readwrite) NSString *displayedName;
@end

@implementation POIPlaceholderNode{
    CCSprite *_glyph;
    CCSprite *_dottedLine;
    CCLabelTTF *_nameLabel;
}

- (id) initWithGlyph:(NSString *)glyphFilename displayName:(NSString *)displayName{
    if(self = [super init]){
        
        _glyph = [[CCSprite alloc] initWithFile:glyphFilename];
        _dottedLine = [CCSprite spriteWithFile:@"poi-placeholder.png"];
        _nameLabel = [[CCLabelTTF alloc] initWithString:[displayName uppercaseString]
                                               fontName:@"HelveticaNeue-CondensedBold"
                                               fontSize:11];
        
        
        [self addChild:_dottedLine];
        [self addChild:_glyph];
        [self addChild:_nameLabel];
        
        _nameLabel.position = CGPointMake(0, -30);
        _nameLabel.color = ccc3(125, 125, 125);
        _glyph.scale = 1.25;
        _dottedLine.scale = 0.6;
        _dottedLine.opacity = 200;
    }
    
    return self;
}

@end