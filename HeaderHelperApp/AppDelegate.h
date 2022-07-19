//
//  AppDelegate.h
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (nonatomic, assign) IBOutlet NSProgressIndicator *progressBar;
@property (nonatomic, assign) IBOutlet NSArrayController *xcodeController;
@property (nonatomic, assign) IBOutlet NSArrayController *runtimeController;
@property (nonatomic, assign) IBOutlet NSTextField *progressLabel;
@property (nonatomic, strong) NSArray *xcodeArray;
@property (nonatomic, strong) NSArray *runtimeArray;
@end

