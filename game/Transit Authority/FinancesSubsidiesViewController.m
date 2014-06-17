//
//  FinancesSubsidiesViewController.m
//  Transit Authority
//
//  Created by Dan Grover on 7/17/13.
//
//

#import "FinancesSubsidiesViewController.h"
#import "Utilities.h"
#import "GameState.h"
#import "GameLedger.h"
#import "Utilities.h"

@interface FinancesSubsidiesViewController ()
@property(strong, readwrite) GameState *gameState;
@end

@implementation FinancesSubsidiesViewController{
    NSTimer *_waitUpdate;
}

- (id) initWithState:(GameState *)state{
    if(self = [super initWithNibName:@"FinancesSubsidiesViewController" bundle:nil]){
        self.gameState = state;
    }
    return self;
}


- (void)viewDidLoad{
    [super viewDidLoad];
    
    
}

- (void) viewWillAppear:(BOOL)animated{
    [super viewWillAppear:animated];
    [self _updateDisplay];
    
    _waitUpdate = [NSTimer scheduledTimerWithTimeInterval:1.0/2 target:self selector:@selector(_updateWaitTimes) userInfo:Nil repeats:YES];
}

- (void) viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:animated];
    [_waitUpdate invalidate];
}

- (void) _updateDisplay{
    
    localSubsidyLabel.text = [NSString stringWithFormat:@"%@/day", FormatCurrency(@(self.gameState.dailyLocalSubsidy))];
    
    federalSubsidyLabel.text = [NSString stringWithFormat:@"%@/day", FormatCurrency(@(self.gameState.dailyFederalSubsidy))];
    
    totalSubsidyLabel.text = [NSString stringWithFormat:@"%@/day", FormatCurrency(@(self.gameState.dailyFederalSubsidy + self.gameState.dailyLocalSubsidy))];
    
    [self _updateWaitTimes];
}

- (void) _updateWaitTimes{
    double localWait = GAME_LOBBY_LOCAL_MAX_FREQ - (self.gameState.currentDate - self.gameState.lastLocalLobbyTime);
    double fedWait = GAME_LOBBY_FED_MAX_FREQ - (self.gameState.currentDate - self.gameState.lastFedLobbyTime);
    
    if(localWait > 0){
        localLobbyWaitLabel.hidden = localLobbyButton.enabled = NO;
        localLobbyWaitLabel.text = [NSString stringWithFormat:@"wait %@",FormatTimeInterval(localWait)];
    }else{
        localLobbyWaitLabel.hidden = localLobbyButton.enabled = YES;
    }
    
    if(fedWait > 0){
        fedLobbyWaitLabel.hidden = fedLobbyButton.enabled = NO;
        fedLobbyWaitLabel.text = [NSString stringWithFormat:@"wait %@",FormatTimeInterval(fedWait)];
    }else{
        fedLobbyWaitLabel.hidden = fedLobbyButton.enabled = YES;
    }
}


- (IBAction)lobbyLocal:(id)sender{
    if((self.gameState.currentDate - self.gameState.lastLocalLobbyTime) > GAME_LOBBY_LOCAL_MAX_FREQ){
        //float oldSubs = self.gameState.dailyLocalSubsidy;
        float newSubs = [self.gameState recommendedDailySubsidy:NO];
        
        self.gameState.dailyLocalSubsidy = newSubs;
        self.gameState.lastLocalLobbyTime = self.gameState.currentDate;
        [self _updateDisplay];
    }else{
        QuickAlert(@"You can only lobby the local government once per day.", @"");
    }
}

- (IBAction)lobbyFed:(id)sender{
    if((self.gameState.currentDate - self.gameState.lastFedLobbyTime) > GAME_LOBBY_FED_MAX_FREQ){
        //float oldSubs = self.gameState.dailyFederalSubsidy;
        float newSubs = [self.gameState recommendedDailySubsidy:YES];
        
        self.gameState.dailyFederalSubsidy = newSubs;
        self.gameState.lastFedLobbyTime = self.gameState.currentDate;
        [self _updateDisplay];
    }else{
        QuickAlert(@"You can only lobby the federal government once per two days", @"");
    }
}

- (IBAction)back:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

@end
