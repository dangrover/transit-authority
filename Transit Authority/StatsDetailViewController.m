//
//  StatsDetailViewController.m
//  Transit Authority
//
//  Created by Dan Grover on 7/19/13.
//
//

#import "StatsDetailViewController.h"
#import "GameState.h"
#import "CPTXYGraph.h"
#import "CPTTheme.h"
#import "CPTScatterPlot.h"
#import "CPTXYAxis.h"
#import "CPTUtilities.h"
#import "CPTXYAxisSet.h"
#import "CPTColor.h"
#import "CPTMutableLineStyle.h"
#import "CPTXYPlotSpace.h"
#import "CPTPlotRange.h"
#import "CPTBarPlot.h"
#import "CPTAxisLabel.h"
#import "CPTMutableTextStyle.h"
#import "NSDate+Helper.h"
#import "CPTPlotAreaFrame.h"
#import "CPTMutableLineStyle.h"
#import "CPTFill.h"
#import "HUDGraphTheme.h"

@implementation StatDisplay


@end

@interface StatsDetailViewController ()<CPTPlotDataSource, CPTPlotDelegate>
@property(strong, readwrite) GameState *gameState;
@property(strong, readwrite) StatDisplay *displayDescription;
@end


@implementation StatsDetailViewController{
    StatPeriod period;
    CPTGraph *graph;
    NSMutableArray *xRecords;
    NSMutableArray *yRecords;
}

- (id) initWithState:(GameState *)theGameState displayDescription:(StatDisplay *)theDisplay{
    if(self = [super initWithNibName:@"StatsDetailViewController" bundle:nil]){
        self.gameState = theGameState;
        self.displayDescription = theDisplay;
        self.title = theDisplay.title;
    }
    return self;
}

- (void)viewDidLoad{
    [super viewDidLoad];
    titleLabel.text = self.title;
    
    timeWindow.selectedSegmentIndex = 0;
    [self changedTimeWindow:nil];
}


- (IBAction)back:(id)sender{
    [self.navigationController popViewControllerAnimated:YES];
}

- (IBAction)changedTimeWindow:(id)sender{
    period = timeWindow.selectedSegmentIndex;
    [self _setUpGraph];
}

- (void) _setUpGraph{
    
    // let's load the data.
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    dateFormatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0]; 
    NSNumberFormatter *numberFormatter = self.displayDescription.yFormatter ? self.displayDescription.yFormatter : [[NSNumberFormatter alloc] init];
    NSTimeInterval timeInterval, start, end;
    unsigned labelingInterval = 1;
    unsigned tickInterval = 1;
    end = self.gameState.currentDate;
    if(period == StatPeriod_Day){
        timeInterval = SECONDS_PER_HOUR;
        start = [[[NSDate dateWithTimeIntervalSince1970:self.gameState.currentDate] dateAsDateWithoutTime] timeIntervalSince1970];
        end = start + (SECONDS_PER_HOUR*HOURS_PER_DAY);
        
        [dateFormatter setDateFormat:@"ha"];
        dateFormatter.AMSymbol = @"a";
        dateFormatter.PMSymbol = @"p";
        labelingInterval = tickInterval = 3;
    }
    else if(period == StatPeriod_Week){
        timeInterval = SECONDS_PER_HOUR * HOURS_PER_DAY;
        start = end - (SECONDS_PER_HOUR*HOURS_PER_DAY*7);
        labelingInterval = tickInterval = 1;
        [dateFormatter setDateFormat:@"M/d"];
    }
    else if(period == StatPeriod_Year){
        timeInterval = SECONDS_PER_HOUR*HOURS_PER_DAY*7;
        start = end - (SECONDS_PER_HOUR*HOURS_PER_DAY*365);
    }
    else if(period == StatPeriod_AllTime){
        start = self.gameState.originalScenario.startingDate.timeIntervalSince1970;
        timeInterval = SECONDS_PER_HOUR*HOURS_PER_DAY*7;
    }else{
        return;
    }
  
    xRecords = [NSMutableArray array];
    yRecords = [NSMutableArray array];
    double yMin = 0;
    double yMax = 0;
    NSTimeInterval timeAtRendering = self.gameState.currentDate;
    for(NSTimeInterval now = start; now < end; now += timeInterval){
        NSTimeInterval windowStart = now;
        NSTimeInterval windowEnd = now + timeInterval;
        
        NSNumber *record = [self.gameState.ledger getAggregate:self.displayDescription.type
                                                        forKey:self.displayDescription.key
                                                         start:windowStart
                                                           end:windowEnd
                                                   interpolate:self.displayDescription.interpolate];
        
        double recordDbl = (windowStart > timeAtRendering) ? 0 : [record doubleValue]; // arc4random() % 100
        
        if(self.displayDescription.yMultiplier){
            recordDbl *= [self.displayDescription.yMultiplier doubleValue];
        }
        
        yMin = MIN(yMin,recordDbl);
        yMax = MAX(yMax,recordDbl);
        
        [xRecords addObject:[NSDate dateWithTimeIntervalSince1970:now]];
        [yRecords addObject:@(recordDbl)];
    }
 
    
    CGFloat barTotalWidth = ceil(graphView.bounds.size.width / yRecords.count);
    NSLog(@"total width = %f. %d records, %f width",barTotalWidth,yRecords.count, graphView.bounds.size.width);
    CGFloat barPadding = 2;
    CGFloat barWidth = floor(barTotalWidth - barPadding);
    
    graph = [[CPTXYGraph alloc] initWithFrame:graphView.bounds];
    [graph applyTheme: [[HUDGraphTheme alloc] init]];
    
    graph.paddingBottom = graph.paddingRight = graph.paddingLeft = graph.paddingTop = 0;
    graph.plotAreaFrame.paddingBottom = 50;
    graph.plotAreaFrame.paddingLeft = 30;
    graph.plotAreaFrame.paddingTop = 15;
    graph.plotAreaFrame.paddingRight = 10;
    graph.plotAreaFrame.borderLineStyle = nil;

    
    
    CPTBarPlot *barPlot = [[CPTBarPlot alloc] init];
    barPlot.dataSource = self;
    barPlot.barWidth = CPTDecimalFromFloat(barWidth);
    barPlot.barCornerRadius = 2;
    
    CPTXYPlotSpace *plotSpace = (CPTXYPlotSpace *)graph.defaultPlotSpace;
    plotSpace.xRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(0)
                                                    length:CPTDecimalFromDouble(barTotalWidth*yRecords.count)];
    plotSpace.yRange = [CPTPlotRange plotRangeWithLocation:CPTDecimalFromDouble(yMin)
                                                    length:CPTDecimalFromDouble(yMax - yMin)];

    
    CPTXYAxis *x          = ((CPTXYAxisSet *)graph.axisSet).xAxis;
    CPTXYAxis *y          = ((CPTXYAxisSet *)graph.axisSet).yAxis;
    
    CPTMutableTextStyle *ts = [[CPTMutableTextStyle alloc] init];
    ts.fontName = @"Helvetica Neue";
    ts.fontSize = 9;
    
    NSMutableSet *labels = [NSMutableSet set];
    NSMutableSet *tickLocs = [NSMutableSet set];

    for(unsigned i = 0; i < xRecords.count; i++){
        CGFloat loc = (i+0.5)*barTotalWidth;
        if((i % tickInterval) == 0){
            [tickLocs addObject:@(loc)];
        }
        
        if((i % labelingInterval) == 0){
            CPTAxisLabel *l = [[CPTAxisLabel alloc] initWithText:[dateFormatter stringFromDate:xRecords[i]]
                                                       textStyle:ts];
            
            l.tickLocation = CPTDecimalFromFloat(loc);
            [labels addObject:l];
        }
    }
    
    x.majorTickLocations = tickLocs;
    x.majorTickLength = 3;
    x.axisLabels = labels;
    x.labelingPolicy = CPTAxisLabelingPolicyNone;
    y.labelingPolicy = CPTAxisLabelingPolicyAutomatic;
    y.labelFormatter = numberFormatter;
    y.labelOffset = 0;
    x.labelOffset = 0;
    y.labelTextStyle = ts;
    
    barPlot.fill = [CPTFill fillWithColor:[CPTColor whiteColor]];
    barPlot.borderWidth = 0;
    
    [graph addPlot:barPlot toPlotSpace:plotSpace];
    graphView.hostedGraph = graph;
}

-(NSUInteger)numberOfRecordsForPlot:(CPTPlot *)plot{
    return xRecords.count;
}

-(NSNumber *)numberForPlot:(CPTBarPlot *)plot field:(NSUInteger)fieldEnum recordIndex:(NSUInteger)index{
    if(fieldEnum == CPTBarPlotFieldBarLocation){
        return @(ceil((index + 0.5) * (CPTDecimalFloatValue(plot.barWidth) + 2)));
    }else if(fieldEnum == CPTBarPlotFieldBarTip){
        return yRecords[index];
    }
    return @(0);
}

@end
