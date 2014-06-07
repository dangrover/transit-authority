//
//  GameFontLabel.m
//  Transit Authority
//
//  Created by Dan Grover on 4/27/14.
//  Copyright (c) 2014 Brown Bag Software LLC. All rights reserved.
//

#import "GameFontSupport.h"

@implementation GameFontLabel

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
    }
    return self;
}

- (id) initWithCoder:(NSCoder *)aDecoder{
    if(self = [super initWithCoder:aDecoder]){
        self.font = [UIFont gameFontOfSize:self.font.pointSize];
    }

    return self;
}


@end



@implementation UIFont (GameFont)

+ (UIFont *) gameFontOfSize:(CGFloat)theSize{
    return [UIFont fontWithName:@"Raleway" size:theSize];
}

@end