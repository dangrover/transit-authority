//
//  GameFontLabel.h
//  Transit Authority
//
//  Created by Dan Grover on 4/27/14.
//  Copyright (c) 2014 Brown Bag Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface GameFontLabel : UILabel

@end


@interface UIFont (GameFont)
+ (UIFont *) gameFontOfSize:(CGFloat)theSize;
@end