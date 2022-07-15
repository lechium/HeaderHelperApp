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
    
    NSArray *xcArray = [[HelperClass sharedInstance] simRuntimes];
    DLog(@"xcArray: %@", xcArray);
    return;
    
    NSOpenPanel *op = [NSOpenPanel new];
    [op setCanChooseDirectories:true];
    [op setCanChooseFiles:false];
    NSModalResponse resp = [op runModal];
    
    if (resp == NSModalResponseOK){
        
        NSString *file = [op filename];
        //HelperClass *hc = [HelperClass new];
        
        //[[HelperClass sharedInstance] doStuffWithFile:file];
        [[HelperClass sharedInstance] setSkipDaemons:true];
        [[HelperClass sharedInstance] processRootFolder:file];
        //NSString *outputPath = [NSHomeDirectory() stringByAppendingPathComponent:@"Headers"];
        //[hc classDumpBundlesInFolder:file toPath:outputPath];
        //[hc doStuffWithFile:file];
    }
    
    
}


- (void)applicationWillTerminate:(NSNotification *)aNotification {
    // Insert code here to tear down your application
}


@end
