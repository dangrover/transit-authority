//
//  HeatMapNode.h
//  Transit Authority
//
//  Created by Dan Grover on 9/4/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "cocos2d.h"
#import "GameMap.h"
#import <CoreImage/CoreImage.h>
#import "UIImage+Blur.h"

@interface HeatMapNode : CCNode
- (id) initWithMap:(GameMap *)theGameMap viewportSize:(CGSize)theViewportSize bufferSize:(CGSize)theBufferSize;
@property(strong, readonly) GameMap *map;
@property(assign, readonly) CGSize viewportSize; // in tiles
@property(assign, readonly) CGSize bufferSize; // in tiles
@property(assign) CGPoint currentPosition; // as a tile coordinate


- (void) refresh;

@end
