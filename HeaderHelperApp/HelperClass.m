//
//  HelperClass.m
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "HelperClass.h"
#import "classdump.h"

#pragma GCC diagnostic ignored "-Wdeprecated-declarations"

@implementation NSString (extra)

- (id)dictionaryRepresentation {
    NSString *error = nil;
    NSPropertyListFormat format;
    NSData *theData = [self dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    id theDict = [NSPropertyListSerialization propertyListFromData:theData
                                                  mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                                            format:&format
                                                  errorDescription:&error];
    return theDict;
}

@end

@implementation HelperClass

+ (id)sharedInstance {
    
    static dispatch_once_t onceToken;
    static HelperClass *shared;
    if (!shared){
        dispatch_once(&onceToken, ^{
            shared = [HelperClass new];
        });
    }
    return shared;
}

- (void)getFileEntitlementsOnMainThread:(NSString *)inputFile withCompletion:(void(^)(NSString *entitlements))block {
    //DLog(@"checking file: %@", inputFile);
    if (![[NSFileManager defaultManager] fileExistsAtPath:inputFile]){
        //DLog(@"file doesnt exist: %@", inputFile);
        if (block){
            block(nil);
        }
        return;
    }
    NSString *fileContents = [NSString stringWithContentsOfFile:inputFile encoding:NSASCIIStringEncoding error:nil];
    NSUInteger fileLength = [fileContents length];
    if (fileLength == 0) {
        fileContents = [NSString stringWithContentsOfFile:inputFile]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
    }
    fileLength = [fileContents length];
    if (fileLength == 0){
        if (block){
            DLog(@"file length is 0, failed: %@", inputFile);
            block(nil);
            return;
        }
    }
    NSScanner *theScanner;
    NSString *text = nil;
    NSString *returnText = nil;
    theScanner = [NSScanner scannerWithString:fileContents];
    while ([theScanner isAtEnd] == NO) {
        [theScanner scanUpToString:@"<?xml" intoString:NULL];
        [theScanner scanUpToString:@"</plist>" intoString:&text];
        text = [text stringByAppendingFormat:@"</plist>"];
        //DLog(@"text: %@", [text dictionaryRepresentation]);
        NSDictionary *dict = [text dictionaryRepresentation];
        if (dict && [dict allKeys].count > 0) {
            if (![[dict allKeys] containsObject:@"CFBundleIdentifier"] && ![[dict allKeys] containsObject:@"cdhashes"]){
                //DLog(@"got im: %@", [[inputFile lastPathComponent] stringByDeletingPathExtension]);
                returnText = text;
                break;
            }
        } else {
            DLog(@"no entitlements found: %@", inputFile);
        }
    }
    if (block){
        block(returnText);
    }
}

- (void)getFileEntitlements:(NSString *)inputFile withCompletion:(void(^)(NSString *entitlements))block {
    //DLog(@"checking file: %@", inputFile.lastPathComponent);
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        if (![[NSFileManager defaultManager] fileExistsAtPath:inputFile]){
            //DLog(@"file doesnt exist: %@", inputFile);
            if (block){
                block(nil);
            }
            return;
        }
        NSString *fileContents = [NSString stringWithContentsOfFile:inputFile encoding:NSASCIIStringEncoding error:nil];
        NSUInteger fileLength = [fileContents length];
        if (fileLength == 0) {
            fileContents = [NSString stringWithContentsOfFile:inputFile]; //if ascii doesnt work, have to use the deprecated (thankfully not obsolete!) method
        }
        fileLength = [fileContents length];
        if (fileLength == 0){
            if (block){
                block(nil);
                return;
            }
        }
        NSScanner *theScanner;
        NSString *text = nil;
        NSString *returnText = nil;
        theScanner = [NSScanner scannerWithString:fileContents];
        while ([theScanner isAtEnd] == NO) {
            [theScanner scanUpToString:@"<?xml" intoString:NULL];
            [theScanner scanUpToString:@"</plist>" intoString:&text];
            text = [text stringByAppendingFormat:@"</plist>"];
            //DLog(@"text: %@", [text dictionaryRepresentation]);
            NSDictionary *dict = [text dictionaryRepresentation];
            if (dict && [dict allKeys].count > 0) {
                if (![[dict allKeys] containsObject:@"CFBundleIdentifier"] && ![[dict allKeys] containsObject:@"cdhashes"]){
                    //DLog(@"got im: %@", [[inputFile lastPathComponent] stringByDeletingPathExtension]);
                    returnText = text;
                    break;
                }
            } else {
                DLog(@"no entitlements found: %@", inputFile);
            }
        }
        if (block){
            block(returnText);
        }
    });
}


- (void)processRootFolder:(NSString *)rootFolder {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        
        NSString *systemVersionFile = [rootFolder stringByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
        NSDictionary *sysVers = [NSDictionary dictionaryWithContentsOfFile:systemVersionFile];
        NSString *productName = sysVers[@"ProductName"];
        NSString *productVersion = sysVers[@"ProductVersion"];
        NSString *folderName = [[NSString stringWithFormat:@"%@_%@", productName, productVersion] stringByReplacingOccurrencesOfString:@" " withString:@"_"];
        NSString *outputFolder = [[NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/export"] stringByAppendingPathComponent:folderName];
        DLog(@"outputFolder: %@" ,outputFolder);
        NSFileManager *man = [NSFileManager defaultManager];
        if (![man fileExistsAtPath:outputFolder]){
            [man createDirectoryAtPath:outputFolder withIntermediateDirectories:true attributes:nil error:nil];
        }
        NSArray *paths = [self rawDaemonPathsForPath:rootFolder];
        DLog(@"%@", paths);
        NSString *entOutput = [outputFolder stringByAppendingPathComponent:@"Entitlements"];
        if (![man fileExistsAtPath:entOutput]){
            [man createDirectoryAtPath:entOutput withIntermediateDirectories:true attributes:nil error:nil];
        }
        [paths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSString *fullFilePath = [rootFolder stringByAppendingPathComponent:obj];
            [self getFileEntitlementsOnMainThread:fullFilePath withCompletion:^(NSString *entitlements) {
                if (entitlements) {
                    NSString *fileName = [[entOutput stringByAppendingPathComponent:[obj lastPathComponent]] stringByAppendingPathExtension:@"plist"];
                    //DLog(@"valid ents for %@ writing to file: %@", [obj lastPathComponent], fileName);
                    [entitlements writeToFile:fileName atomically:true encoding:NSUTF8StringEncoding error:nil];
                }
            }];
        }];
        
        [self processDaemons:paths inRoot:rootFolder toFolder:outputFolder];
        
        //done with daemons et al
        
        NSArray *exportPaths = @[@"Applications", @"System/Library/Frameworks", @"System/Library/PrivateFrameworks", @"System/Library/HIDPlugins/ServicePlugins", @"System/Library/TVSystemMenuModules"];
        [exportPaths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self classDumpBundlesInFolder:[rootFolder stringByAppendingPathComponent:obj] toPath:[outputFolder stringByAppendingPathComponent:obj]];
        }];
        //NSString *outputFile = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/daemons.plist"];
        //[rawDaemonDetails writeToFile:outputFile atomically:true];
    });
}

- (void)processDaemons:(NSArray *)daemons inRoot:(NSString *)rootFolder toFolder:(NSString *)rootOutputFolder {
    NSString *outputFolder = [rootOutputFolder stringByAppendingPathComponent:@"usr/libexec"];
    NSFileManager *man = [NSFileManager defaultManager];
    [man createDirectoryAtPath:outputFolder withIntermediateDirectories:true attributes:nil error:nil];
    [daemons enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSString *fullPath = [rootFolder stringByAppendingPathComponent:obj];
        NSString *headerPath = [outputFolder stringByAppendingPathComponent:[[obj lastPathComponent] stringByDeletingPathExtension]];
        //DLog(@"make header path: %@", headerPath);
        [man createDirectoryAtPath:headerPath withIntermediateDirectories:true attributes:nil error:nil];
        DLog(@"[%lu of %lu] Dumping binary: %@ ...", idx, daemons.count ,[obj lastPathComponent]);
        classdump *cd = [classdump new];
        [cd performClassDumpOnFile:fullPath toFolder:headerPath];
        NSArray *contents = [man contentsOfDirectoryAtPath:headerPath error:nil];
        
        if (contents.count < 2) {
            //DLog(@"output folder count after class dump: %lu is less than 2, torch the folder!", contents.count);
            [man removeItemAtPath:headerPath error:nil];
        }
    }];
}

- (void)doStuffWithFile:(NSString *)file {
    NSString *outputFolder = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/HHT"];
    [[NSFileManager defaultManager] createDirectoryAtPath:outputFolder withIntermediateDirectories:true attributes:nil error:nil];
    DLog(@"performing class dump on file: %@ to folder: %@", file, outputFolder);
    classdump *cd = [classdump new];
    [cd performClassDumpOnFile:file toFolder:outputFolder];
}

- (void)classDumpBundlesInFolder:(NSString *)folderPath toPath:(NSString *)outputPath {
    
    if (![[NSFileManager defaultManager] fileExistsAtPath:folderPath]){
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        NSFileManager *man = [NSFileManager defaultManager];
        NSArray *dirContents = [man contentsOfDirectoryAtPath:folderPath error:nil];
        //NSString *lastPath = [folderPath lastPathComponent];
        //NSString *outputPath = [folderPath stringByAppendingPathComponent:lastPath];
        [man createDirectoryAtPath:outputPath withIntermediateDirectories:TRUE attributes:nil error:nil];
        //DLog(@"dir contents: %@", dirContents);
        [dirContents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSString *fullPath = [folderPath stringByAppendingPathComponent:obj];
            NSString *headerPath = [outputPath stringByAppendingPathComponent:[obj stringByDeletingPathExtension]];
            if ([man fileExistsAtPath:headerPath]) {
                NSArray *contents = [man contentsOfDirectoryAtPath:headerPath error:nil];
                //DLog(@"%@ already exists, should we skip it? content count: %lu", headerPath, contents.count);
            } else {
                [man createDirectoryAtPath:headerPath withIntermediateDirectories:TRUE attributes:nil error:nil];
                NSString *plistPath = [fullPath stringByAppendingPathComponent:@"Info.plist"];
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                NSString *exeName = dict[@"CFBundleExecutable"];
                NSString *exePath = [fullPath stringByAppendingPathComponent:exeName];
                
                //NSString *classDumpPath = [[NSBundle mainBundle] pathForResource:@"classdumpios" ofType:@""];
                
                //NSString *runLine = [NSString stringWithFormat:@"%@ -a -A -H -o '%@' '%@'",classDumpPath, headerPath, exePath];
                //DLog(@"%@", runLine);
                //[self runCommand: runLine];
                //class-dump -a -A -H -I -o PrivateHeaders
                //
                DLog(@"[%lu of %lu] Dumping [%@] bundle: %@ ...", idx, dirContents.count,folderPath.lastPathComponent ,exePath.lastPathComponent);
                classdump *cd = [classdump new];
                [cd performClassDumpOnFile:exePath toFolder:headerPath];
            }
            
        }];
        DLog(@"Finished: %@", folderPath);
    });
}

+ (NSArray *)arrayReturnForTask:(NSString *)taskBinary withArguments:(NSArray *)taskArguments {
    DLog(@"%@ %@", taskBinary, [taskArguments componentsJoinedByString:@" "]);
    NSTask *task = [[NSTask alloc] init];
    NSPipe *pipe = [[NSPipe alloc] init];
    NSFileHandle *handle = [pipe fileHandleForReading];
    [task setLaunchPath:taskBinary];
    [task setArguments:taskArguments];
    [task setStandardOutput:pipe];
    [task setStandardError:pipe];
    [task launch];
    NSData *outData = nil;
    NSString *temp = nil;
    while((outData = [handle readDataToEndOfFile]) && [outData length]) {
        temp = [[NSString alloc] initWithData:outData encoding:NSASCIIStringEncoding];
    }
    [handle closeFile];
    task = nil;
    return [temp componentsSeparatedByString:@"\n"];
}


+ (NSArray *)returnForProcess:(NSString *)call {
    if (call==nil)
        return 0;
    char line[200];
    DLog(@"running process: %@", call);
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp) {
        while (fgets(line, sizeof line, fp)) {
            NSString *s = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [lines addObject:s];
        }
    }
    pclose(fp);
    return lines;
}

- (NSArray *)rawDaemonPathsForPath:(NSString *)path {
    NSArray *fullDaemonList = [HelperClass rawDaemonListAtPath:path];
    __block NSMutableArray *programList = [NSMutableArray new];
    [fullDaemonList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([[obj pathExtension] isEqualToString:@"plist"]){
            NSDictionary *dirtyDeeds = [NSDictionary dictionaryWithContentsOfFile:obj];
            if (dirtyDeeds){
                NSString *programPath = nil;
                if ([[dirtyDeeds allKeys] containsObject:@"Program"]){
                    programPath = dirtyDeeds[@"Program"];
                    //DLog(@"program: %@", programPath);
                } else if ([[dirtyDeeds allKeys] containsObject:@"ProgramArguments"]){
                    programPath = [dirtyDeeds[@"ProgramArguments"] firstObject];
                    //DLog(@"program: %@", programPath);
                }
                //DLog(@"dictKey: %@", dictKey);
                if (programPath != nil){
                    [programList addObject:programPath];
                }
            }
        }
    }];
    return programList;
}

- (NSDictionary *)rawDaemonDetailsForPath:(NSString *)path {
    
    NSArray *fullDaemonList = [HelperClass rawDaemonListAtPath:path];
    
    //DLog(@"fullDaemonList: %@", fullDaemonList);
    NSMutableDictionary *finalDict = [NSMutableDictionary new];
    [fullDaemonList enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        
        if ([[obj pathExtension] isEqualToString:@"plist"]){
            NSDictionary *dirtyDeeds = [NSDictionary dictionaryWithContentsOfFile:obj];
            if (dirtyDeeds){
                NSString *dictKey = nil;
                if ([[dirtyDeeds allKeys] containsObject:@"Program"]){
                    dictKey = [dirtyDeeds[@"Program"] lastPathComponent];
                    DLog(@"program: %@", dirtyDeeds[@"Program"]);
                } else if ([[dirtyDeeds allKeys] containsObject:@"ProgramArguments"]){
                    dictKey = [[dirtyDeeds[@"ProgramArguments"] firstObject] lastPathComponent];
                    DLog(@"program: %@", [dirtyDeeds[@"ProgramArguments"] firstObject]);
                }
                //DLog(@"dictKey: %@", dictKey);
                if (dictKey != nil && dirtyDeeds != nil){
                    finalDict[dictKey] = dirtyDeeds;
                }
                
            }
            
        }
    }];
    return finalDict;
}

+ (NSArray *)rawDaemonListAtPath:(NSString *)path {
    
    NSString *task = @"/usr/bin/find";
    NSArray *returnValue = [self arrayReturnForTask:task withArguments:@[path, @"-name", @"com.*.plist"]];
    //DLog(@"find return: %@", returnValue);
    return returnValue;
}

- (int)runCommand:(NSString *)call {
    if (call==nil)
        return 0;
    char line[200];
    DLog(@"running process: %@", call);
    FILE* fp = popen([call UTF8String], "r");
    NSMutableArray *lines = [[NSMutableArray alloc]init];
    if (fp) {
        while (fgets(line, sizeof line, fp)) {
            NSString *s = [NSString stringWithCString:line encoding:NSUTF8StringEncoding];
            s = [s stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            [lines addObject:s];
        }
    }
    int returnStatus = pclose(fp);
    return returnStatus;
}

@end
