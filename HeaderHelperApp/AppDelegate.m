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

- (void)showMultiplePlatformsFoundAlert:(NSArray *)platforms {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [NSAlert alertWithMessageText:@"Multiple platforms found!" defaultButton:@"One By One" alternateButton:@"Don't" otherButton:@"Process All" informativeTextWithFormat:@"How would you like to process them?"];
        NSModalResponse modalReturn = [alert runModal];
        switch (modalReturn) {
                
            case NSAlertDefaultReturn:
                [self processPlatforms:platforms mode:0];
                //[[NSWorkspace sharedWorkspace] openFile:[KBProfileHelper mobileDeviceLog]];
                break;
                
            case NSAlertAlternateReturn:
                
                break;
                
            case NSAlertOtherReturn:
                [self processPlatforms:platforms mode:1];
                break;
        }
    });
}

- (void)showAlertForPlatform:(NSDictionary *)platform {
    dispatch_async(dispatch_get_main_queue(), ^{
        NSAlert *alert = [NSAlert alertWithMessageText:@"Process platform" defaultButton:@"DO IT" alternateButton:@"Don't" otherButton:nil informativeTextWithFormat:@"Would you like to process '%@'", platform[@"name"]];
        NSModalResponse modalReturn = [alert runModal];
        switch (modalReturn) {
                
            case NSAlertDefaultReturn:
                [[HelperClass sharedInstance] processRootFolder:platform[@"path"]];
                //[self processPlatforms:platforms mode:0];
                //[[NSWorkspace sharedWorkspace] openFile:[KBProfileHelper mobileDeviceLog]];
                break;
                
            case NSAlertAlternateReturn:
                
                break;
                
        }
    });
}


- (void)processPlatforms:(NSArray *)platforms mode:(NSInteger)mode {
    //DLog(@"process platforms: %@ with mode: %lu", platforms, mode);
    if (mode == 0) { //prompt one by one
        [platforms enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            DLog(@"prompt for obj: %@", obj);
            [self showAlertForPlatform:obj];
            //[[HelperClass sharedInstance] processRootFolder:obj];
        }];
    } else if (mode == 1) { //process em all!
        [platforms enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            //need to make sure we only do one at a time...
            [[HelperClass sharedInstance] processRootFolder:obj[@"path"]];
        }];
    }
    
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    // Insert code here to initialize your application
    
    //NSArray *xcArray = [[HelperClass sharedInstance] simRuntimes];
    //DLog(@"xcArray: %@", xcArray);
    //return;
    
    NSOpenPanel *op = [NSOpenPanel new];
    [op setCanChooseDirectories:true];
    [op setCanChooseFiles:true];
    NSModalResponse resp = [op runModal];
    
    if (resp == NSModalResponseOK){
        
        NSString *file = [op filename];
        DLog(@"file: %@", file);
        //return;
        //HelperClass *hc = [HelperClass new];
        if ([[file lastPathComponent] containsString:@"Xcode"]){
            DLog(@"is some kind of xcode!");
            NSDictionary *runtimes = [[HelperClass sharedInstance] simRuntimesForXcode:file];
            file = runtimes[@"path"];
            //DLog(@"runtimes: %@", runtimes[@"platforms"]);
            [self showMultiplePlatformsFoundAlert:runtimes[@"platforms"]];
            return;
        }
        
        [[HelperClass sharedInstance] newGetFileEntitlementsOnMainThread:file withCompletion:^(NSDictionary *entitlements) {
            DLog(@"%@", entitlements);
        }];
        return;
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
