//
//  AppDelegate.m
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "AppDelegate.h"
#import "HelperClass.h"

@interface AppDelegate ()

@property (weak) IBOutlet NSWindow *window;
@end

@implementation AppDelegate

#define LOG_FILE_LINE NSLog(@"[%@ at %i]", [[NSString stringWithUTF8String:__FILE__] lastPathComponent], __LINE__);

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    NSOpenPanel *op = [NSOpenPanel new];
    [op setCanChooseDirectories:FALSE];
    [op setCanChooseFiles:TRUE];
    NSModalResponse resp = [op runModal];
    
    if (resp == NSModalResponseOK){
        
        NSString *file = [op filename];
        HelperClass *hc = [HelperClass new];
        //[hc doStuffWithFolder:file];
        [hc doStuffWithFile:file];
        
    }
    
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
