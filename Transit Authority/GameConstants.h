//
//  GameConstants.h
//  Transit Authority
//
//  Created by Dan Grover on 7/20/13.
//
//

#import <Foundation/Foundation.h>

#define SECONDS_PER_MINUTE 60
#define MINUTES_PER_HOUR 60
#define HOURS_PER_DAY 24
#define SECONDS_PER_HOUR (SECONDS_PER_MINUTE*MINUTES_PER_HOUR)
#define SECONDS_PER_DAY (SECONDS_PER_HOUR*HOURS_PER_DAY)

// Distance scale
#define DEFAULT_DISTANCE_SCALE_TPM 25.0f // default scale is 25 tiles per mile

// Timescale
#define REAL_SECONDS_PER_TICK (1/60.0)
#define TICK_IN_GAME_SECONDS 240*REAL_SECONDS_PER_TICK
#define GAME_STATION_BOARDING_TIME_IN_GAME_SECONDS 100
#define GAME_PASSENGER_MAX_WAIT (60*60) // max a passenger will wait
#define GAME_TICKS_BETWEEN_DEMAND_GENERATION (3/REAL_SECONDS_PER_TICK) 

// Financials
#define GAME_DEFAULT_FARE 2.25
#define GAME_STATION_COST 50000
#define GAME_TRACK_COST_PER_TILE 1200
#define GAME_BRIDGE_COST_PER_TILE 1000
#define GAME_TRAIN_COST 10000

#define GAME_TRAIN_MAINTENENCE_PER_DAY 1000.0f
#define GAME_TRAIN_CAR_MAINTENENCE_PER_DAY 100.0

#define GAME_MAINTENENCE_DEDUCTION_INTERVAL SECONDS_PER_HOUR
#define BOND_PAYMENT_INTERVAL SECONDS_PER_HOUR
#define SUBSIDY_PAYMENT_INTERVAL SECONDS_PER_HOUR

// Train Physics
// TPT = tiles per tick
#define GAME_TRAIN_MAX_SPEED_TPT 0.55f
#define GAME_TRAIN_STATION_APPROACH_SPEED_TPT 0.01f
#define GAME_TRAIN_ENGINE_ACCELERATION_TPT 0.009f
#define GAME_TRAIN_BRAKE_ACCELERATION_TPT -0.016f
#define GAME_TRAIN_FRICTION 0.0002f
#define GAME_TRAIN_DISTANCE_TO_STAY_FROM_STOPPED_TRAIN_AHEAD 5
#define GAME_TRAIN_DISTANCE_NEEDED_PER_CAR 0.4f // additional distance per car of the stopped train ahead
#define GAME_ACCEL_MULT_PER_CAR 0.06f // accel is *= 1-(cars*this)
#define GAME_TRAIN_SPEED_DIFF_THESHOLD 0.07 // the difference between speed and target speed required to take action

// Capacity
#define GAME_MAX_CARS_IN_TRAIN 8
#define GAME_MAX_TRAINS_PER_LINE 25
#define GAME_MAX_TRAIN_LENGTH_WITHOUT_LONG_PLATFORM 4
#define GAME_TRAIN_PASSENGERS_PER_CAR 50

#define GAME_STATION_WALK_RADIUS_TILES 7 // the distance a passenger is willing to walk from a station, in tiles, to get around
#define GAME_STATION_CAR_RADIUS_TILES 16 // distance people are willing to drive to get to a station


#define GAME_WALK_SPEED_TPT 0.05f // how many tiles per tick people can walk on foot
#define GAME_CAR_AVERAGE_SPEED_TPT 0.2 // the average speed of a car (used for making decisions about whether to take the train)
#define GAME_CAR_PARKING_TIME_PER_DENSITY_UNIT 30 // how long it takes to park a car per density unit in a square
#define GAME_CAR_PARKING_TIME_BASE 60

// What factor taking transit is allowed to be longer by for us to still take it
static float GAME_DECISION_TIME_RATIO_ALLOWANCES[] = {1,1.75,2.75,INT_MAX}; // Split evenly. INT_MAX=always take transit

#define GAME_LOBBY_FED_MAX_FREQ (SECONDS_PER_DAY)
#define GAME_LOBBY_LOCAL_MAX_FREQ (SECONDS_PER_DAY/2)

// Odds of wanting to go res->com by hour
static float RES_TILE_ODDS_OF_DEMAND_GEN_BY_HOUR[24] = {
    0.01, // 12am
    0.01, // 1am
    0.01, // 2am
    0.01, // 3am
    0.01, // 4am
    0.1,  // 5am
    0.2,  // 6am
    0.4,  // 7am
    0.5,  // 8am
    0.4,  // 9am
    0.3,  // 10am
    0.2,  // 11am
    0.25, // 12pm
    0.2,  // 1pm
    0.2,  // 2pm
    0.2,  // 3pm
    0.2,  // 4pm
    0.1,  // 5pm
    0.3,  // 6pm
    0.3,  // 7pm
    0.2,  // 8pm
    0.2,  // 9pm
    0.1,  // 10pm
    0.01   // 11pm
};

// Odds of wanting to go com->res by hour
static float COM_TILE_ODDS_OF_DEMAND_GEN_BY_HOUR[24] = {
    0.01, // 12am
    0.01, // 1am
    0.01, // 2am
    0.01, // 3am
    0.01, // 4am
    0.15,  // 5am
    0.15,  // 6am
    0.15,  // 7am
    0.15,  // 8am
    0.15,  // 9am
    0.15,  // 10am
    0.25,  // 11am
    0.25, // 12pm
    0.15,  // 1pm
    0.15,  // 2pm
    0.15,  // 3pm
    0.15,  // 4pm
    0.5,  // 5pm
    0.6,  // 6pm
    0.4,  // 7pm
    0.2,  // 8pm
    0.2,  // 9pm
    0.15,  // 10pm
    0.1   // 11pm
};

#define GAME_START_NIGHT_HOUR 20
#define GAME_END_NIGHT_HOUR 6

#define GAME_PASSENGER_TRANSFERS_ALLOWED 1 // the max transfers a passenger will make on a trip


// Upgrades
#define StationUpgrade_Accessible @"accessible"
#define GAME_UPGRADE_ACCESSIBLE_COST 5000

#define StationUpgrade_ParkingLot @"parking"
#define GAME_UPGRADE_PARKING_MIN_COST 5000
#define GAME_UPGRADE_PARKING_COST_PER_DENSITY_UNIT_IN_RADIUS 70

#define StationUpgrade_LongPlatform @"long-platform"
#define GAME_UPRGRADE_LONG_PLATFORM_COST 40000


// Ledger stats. Keys used to store things in GameLedger
#define GameLedger_BoardTrain @"passengerBoardTrain" // passenger successfully boards the train

#define GameLedger_Prefix_Reject @"passengerReject"
#define GameLedger_Reject_NoDestStation @"passengerReject.noDest" // passenger rejects a ride because he can't get where he wants to
#define GameLedger_Reject_Walked @"passengerReject.walk" // passenger rejects a ride because the destination was in walking distance
#define GameLedger_Reject_TooLong @"passengerReject.tooLong" // passenger rejects because the train would take too much time

#define GameLedger_Reject_GiveUp @"passengerReject.wait_too_long"// passenger leaves a station he was waiting for a train in because it took too long
#define GameLedger_Transfer @"passengerTransfer"// passenger train to transfer at another station to get to their final dest
#define GameLedger_TrainWaitTime @"waitTime"// record a wait time (at a station)

#define GameLedger_Finance_Income_Fare @"income.fare"
#define GameLedger_Finance_Income_Subsidy @"income.subsidy"
#define GameLedger_Finance_Expense_Construction @"expense.construction"
#define GameLedger_Finance_Expense_Trains @"expense.trains"
#define GameLedger_Finance_Expense_DebtService @"expense.debtService"
#define GameLedger_Finance_Expense_Maintenence @"expense.maintenence"
#define GameLedger_Finance_Balance @"finance-balance"

#define GameLedger_NumberOfRunningTrains @"running-trains-count"
#define GameLedger_NumberOfStations @"stations-count"
#define GameLedger_MapServedProportion @"map-proportion-served"
#define GameLedger_PopulationServedProportion @"population-proportion-served"
#define GameLedger_TripsMadeOnSystemProportion @"trips-made-proportion"
#define GameLedger_TripsMadeOnSystemByPeopleNearStationsProportion @"trips-made-proportion-near-stations"


// Suppress compiler warnings about these because they actually are used
#pragma unused(COM_TILE_ODDS_OF_DEMAND_GEN_BY_HOUR, RES_TILE_ODDS_OF_DEMAND_GEN_BY_HOUR, GAME_DECISION_TIME_RATIO_ALLOWANCES)

