//
//  MainMenuViewController.h
//  Transit Authority
//
//  Created by Dan Grover on 7/16/13.
//
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

@interface MainMenuViewController : UIViewController{
    UIImageView *_logo;
}

- (IBAction)chooseScenario:(id)sender;
- (IBAction)sendFeedback:(id)sender;
- (IBAction)readHelp:(id)sender;


@end
