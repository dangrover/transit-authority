//
//  ScenarioIntroViewController.h
//  Transit Authority
//
//  Created by Dan Grover on 8/13/13.
//
//

#import <UIKit/UIKit.h>
@class GameScenario;

@interface ScenarioIntroViewController : UIViewController{
    IBOutlet UILabel *cityName;
    IBOutlet UILabel *tier1goal1;
    IBOutlet UILabel *tier1goal2;
    IBOutlet UILabel *tier2goal1;
    IBOutlet UILabel *tier2goal2;
    IBOutlet UILabel *tier3goal1;
    IBOutlet UILabel *tier3goal2;
    IBOutlet UITextView *cityDescription;
    IBOutlet UIImageView *backgroundImageView;
}

- (id) initWithScenario:(GameScenario *)theScenario;
@property(strong,readonly) GameScenario *scenario;

- (IBAction) back:(id)sender;
- (IBAction) startGame:(id)sender;

@end
