//
//  UIColor+Cocos.m
//  Transit Authority
//
//  Created by Dan Grover on 7/20/13.
//
//

#import "UIColor+Cocos.h"


@implementation UIColor (Cocos)

- (const CGFloat *) components{
    return CGColorGetComponents(self.CGColor);
}

-(ccColor3B)c3b {
    const CGFloat *rgba = self.components;
    return ccc3(0xFF * rgba[0], 0xFF * rgba[1], 0xFF * rgba[2]);
}

-(ccColor4B)c4b {
    const CGFloat *rgba = self.components;
    return ccc4(0xFF * rgba[0], 0xFF * rgba[1], 0xFF * rgba[2], 0xFF * rgba[3]);
}

-(ccColor4F)c4f {
    const CGFloat *rgba = self.components;
    return (ccColor4F) { (GLfloat) rgba[0], (GLfloat) rgba[1], (GLfloat) rgba[2], (GLfloat) rgba[3] };
}

-(void)setCCDrawColor {
    const CGFloat *rgba = self.components;
    ccDrawColor4F(rgba[0], rgba[1], rgba[2], rgba[3]);
}

@end

