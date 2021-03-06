//
//  GameTool.h
//  Transit Authority
//
//  Created by Dan Grover on 6/25/13.
//
//

#import <Foundation/Foundation.h>
#import "cocos2d.h"

@class MainGameScene;


@interface GameTool : NSObject{
@protected
    CCLabelTTF *costLabel;
}

@property(assign) MainGameScene *parent;
@property(strong, readonly) NSString *helpText;
@property(assign, readonly) BOOL showsHelpText;
//@property(strong) IBOutlet UIViewController *viewController;

@property(assign, readonly) BOOL allowsPanning;
@property(assign) BOOL validMove;

- (void) started;
- (void) finished;

- (BOOL)touchBegan:(UITouch *)touch withEvent:(UIEvent *)event;
- (void)touchMoved:(UITouch *)touch withEvent:(UIEvent *)event;
- (void)touchEnded:(UITouch *)touch withEvent:(UIEvent *)event;
- (void)touchCancelled:(UITouch *)touch withEvent:(UIEvent *)event;
@end