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
        
        _glyph = [CCSprite spriteWithImageNamed:glyphFilename];
        _dottedLine = [CCSprite spriteWithImageNamed:@"poi-placeholder.png"];
        _nameLabel = [[CCLabelTTF alloc] initWithString:displayName
                                               fontName:@"Raleway"
                                               fontSize:18];
        
        
        [self addChild:_dottedLine];
        [self addChild:_glyph];
        [self addChild:_nameLabel];
        
        _nameLabel.position = CGPointMake(0, -60);
        _nameLabel.color = [CCColor colorWithCcColor3b:ccc3(125, 125, 125)];
        _glyph.scale = 1.25;
        _glyph.opacity = 0.5;
        _dottedLine.scale = 0.6;
        _dottedLine.opacity = 0.25;
    }
    
    return self;
}

@end
