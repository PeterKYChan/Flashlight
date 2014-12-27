//
//  _FlashlightPluginEngine.m
//  SpotlightSIMBL
//
//  Created by Nate Parrott on 12/26/14.
//  Copyright (c) 2014 Nate Parrott. All rights reserved.
//

#import "_FlashlightPluginEngine.h"
#import <AppKit/AppKit.h>
#import "SPResultViewController.h"
#import "_SS_PluginRunner.h"
#import "SPOpenAPIResult.h"
#import "SPResult.h"
#import "SPOpenAPIQuery.h"
#import "SPGroupHeadingResult.h"

@interface _FlashlightPluginEngine ()

@property (nonatomic) NSArray *results;

@end

@implementation _FlashlightPluginEngine

+ (_FlashlightPluginEngine *)shared {
    static _FlashlightPluginEngine *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [_FlashlightPluginEngine new];
    });
    return shared;
}

- (void)setQuery:(NSString *)query {
    _query = query;
    self.results = nil;
    
    if (!query) return;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSDictionary *resultsByPlugin = [_SS_PluginRunner resultDictionariesFromPluginsForQuery:query];
        NSMutableArray *resultItems = [NSMutableArray new];
        for (NSString *pluginName in resultsByPlugin) {
            for (NSDictionary *resultInfo in resultsByPlugin[pluginName]) {
                id result = [[__SS_SPOpenAPIResultClass() alloc] initWithQuery:query json:resultInfo sourcePlugin:pluginName];
                if (result) {
                    [resultItems addObject:result];
                }
            }
        }
        BOOL sortAscending = !_Flashlight_Is_10_10_2_Spotlight();
        [resultItems sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"rank" ascending:sortAscending]]];
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([query isEqualToString:self.query]) {
                self.results = resultItems;
                [self reloadResultsViews];
            }
        });
    });
}

- (void)reloadResultsViews {
    id appDelegate = [[NSApplication sharedApplication] delegate];
    SPResultViewController *resultVC = [appDelegate performSelector:NSSelectorFromString(@"currentViewController")];
    [resultVC setResults:resultVC.results];
    [resultVC reloadResultsSelectingTopResult:YES animate:NO];
}

- (NSArray *)mergeFlashlightResultsWithSpotlightResults:(NSArray *)spotlightResults {
    NSMutableArray *pluginTopHits = [NSMutableArray new];
    NSMutableArray *pluginNonTopHits = [NSMutableArray new];
    for (id pluginHit in self.results) {
        if ([pluginHit shouldNotBeTopHit]) {
            [pluginNonTopHits addObject:pluginHit];
        } else {
            [pluginTopHits addObject:pluginHit];
        }
    }
    
    
    NSMutableArray *mainResults = [NSMutableArray new];
    NSMutableArray *showAllInFinderResults = [NSMutableArray new];
    NSMutableArray *topHitHeaders = [NSMutableArray new];
    NSMutableArray *topHitItems = [NSMutableArray new];
    BOOL lastHeaderWasTopHit = NO;
    
    for (id item in spotlightResults) {
        if ([item isKindOfClass:NSClassFromString(@"SPOpenAPIResult")]) {
            // do nothing
        } else if ([item isGroupHeading]) {
            if (topHitHeaders.count == 0) {
                // this is the top-hit header:
                lastHeaderWasTopHit = YES;
                [topHitHeaders addObject:item];
            } else {
                lastHeaderWasTopHit = NO;
                [mainResults addObject:item];
            }
        } else if (lastHeaderWasTopHit) {
            [topHitItems addObject:item];
        } else {
            [mainResults addObject:item];
        }
    }
    
    [topHitItems insertObjects:pluginTopHits atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, pluginTopHits.count)]];
    if (pluginNonTopHits.count) {
        [pluginNonTopHits insertObject:[[NSClassFromString(@"SPGroupHeadingResult") alloc] initWithDisplayName:@"FLASHLIGHT" focusString:nil] atIndex:0];
        [mainResults insertObjects:pluginNonTopHits atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, pluginNonTopHits.count)]];
    }
    
    NSMutableArray *toPrepend = [NSMutableArray new];
    [toPrepend addObjectsFromArray:topHitHeaders];
    [toPrepend addObjectsFromArray:topHitItems];
    [mainResults insertObjects:toPrepend atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(0, toPrepend.count)]];
    [mainResults addObjectsFromArray:showAllInFinderResults];
    return mainResults;
}

@end