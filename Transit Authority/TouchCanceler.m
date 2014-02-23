//
//  TouchCanceler.m
//  Transit Authority
//
//  Created by Dan Grover on 9/13/13.
//  Copyright (c) 2013 Brown Bag Software LLC. All rights reserved.
//

#import "TouchCanceler.h"
#import "CCDirector.h"

@implementation TouchCanceler

- (BOOL)ccTouchBegan:(UITouch *)touch withEvent:(UIEvent *)event{
    UIView *glView = [[CCDirector sharedDirector] view];
    if(glView.subviews.count){
        CGPoint l = [touch locationInView:glView];
        for(UIView *s in glView.subviews){
            if(CGRectContainsPoint(s.frame, l)){
                NSLog(@"Blocked a touch that intersected with a view");
                return YES;
            }
        }
     
    }
    
    return NO; // let someone else in the game handle it
}

@end
