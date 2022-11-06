//
//  HelperClass.m
//  HeaderHelperApp
//
//  Created by Kevin Bradley on 5/31/19.
//  Copyright © 2019 nito. All rights reserved.
//

#import "HelperClass.h"
#import "classdump.h"
#import "NSString-CDExtensions.h"
#import <sys/stat.h>
#include <sys/param.h>
#include <sys/mount.h>
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

@interface HelperClass() {
    NSMetadataQuery *query_;
    NSMutableArray *results;
}

@end

@implementation HelperClass

- (NSDictionary *)libraryRuntimes {
    NSFileManager *man = [NSFileManager defaultManager];
    NSString *libPath = @"/Library/Developer/CoreSimulator/Profiles/Runtimes";
    if (![man fileExistsAtPath:libPath]){
        //return nil;
        libPath = @"/Library/Developer/CoreSimulator/Volumes";
        if (![man fileExistsAtPath:libPath]){
            return nil;
        }
    }
    NSArray *runtimes = [man contentsOfDirectoryAtPath:libPath error:nil];
    __block NSMutableArray *fullRuntimes = [NSMutableArray new];
    [runtimes enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        NSDictionary *rt = [self runtimeAtPath:[libPath stringByAppendingPathComponent:obj]];
        if (rt) {
            [fullRuntimes addObject:rt];
        }
    }];
    if (fullRuntimes.count > 0){
        return @{@"name": @"Library Runtimes", @"path": libPath, @"runtimes": fullRuntimes};
    }
    return nil;
}

- (NSArray *)driveArray {
    NSMutableArray *deviceArray = [[NSMutableArray alloc] init];
    struct statfs *buf = NULL;
    unsigned i, count = 0;
    
    count = getmntinfo(&buf, 0);
    for (i=0; i<count; i++) {
        char *devName = buf[i].f_mntfromname;
        char *volName = buf[i].f_mntonname;
        
        unsigned long long freeSize = buf[i].f_blocks;
        long blockSize = buf[i].f_bsize;
        unsigned long long bytesAvailable = (freeSize * blockSize)/1024;
        float mb = bytesAvailable/1024;
        float gb = mb/1024;
        if ( (buf[i].f_flags & MNT_LOCAL) > 0 ) {
            //NSLog(@"volName: %s", volName);
            
            //if((buf[i].f_flags & MNT_DONTBROWSE ) == 0) {
            if(((buf[i].f_flags & MNT_ROOTFS ) == 0) ) {
                //  if ( (buf[i].f_flags & MNT_RDONLY) == 0 ) {
                NSString *device = [NSString stringWithUTF8String:devName];
                NSString *name = [NSString stringWithUTF8String:volName];
                
                id plist = [self dictionaryForVolume:device];
                //NSLog(@"plist: %@", plist);
                NSString *content = [plist valueForKey:@"FilesystemUserVisibleName"];
                NSString *parentWholeDisk = [plist valueForKey:@"ParentWholeDisk"];
                NSString *mountPoint = plist[@"MountPoint"];
                NSString *runtime = [mountPoint stringByAppendingPathComponent:@"Library/Developer/CoreSimulator/Profiles/Runtimes"];
                
                NSMutableDictionary *deviceDict = [[NSMutableDictionary alloc] init];
                deviceDict[@"MountPoint"] = mountPoint;
                deviceDict[@"VolumeName"] = plist[@"VolumeName"];
                [deviceDict setObject:device forKey:@"device"];
                [deviceDict setObject:[name lastPathComponent] forKey:@"name"];
                [deviceDict setObject:[NSString stringWithFormat:@"%d", bytesAvailable] forKey:@"bytesAvailable"];
                [deviceDict setObject:[NSString stringWithFormat:@"%.0fM", mb] forKey:@"size"];
                if (content != nil)
                    [deviceDict setObject:content forKey:@"FilesystemType"];
                
                if (parentWholeDisk != nil)
                    [deviceDict setObject:[NSString stringWithFormat:@"/dev/%@", parentWholeDisk] forKey:@"ParentWholeDisk"];
                
                //if (gb < 128)
                if ([[NSFileManager defaultManager] fileExistsAtPath:runtime]){
                    deviceDict[@"runtimePath"] = runtime;
                    deviceDict[@"runtime"] = [self runtimeAtRelativePath:runtime];
                    [deviceArray addObject:deviceDict];
                }
               
                //}
            }
            //}
        }
        
    }
    
    return deviceArray;
}

- (NSDictionary *)dictionaryForVolume:(NSString *)volume {
    //        NSLog(@"volume clip: %@", volume);
    NSTask *irTask = [[NSTask alloc] init];
    NSPipe *hdip = [[NSPipe alloc] init];
    NSFileHandle *hdih = [hdip fileHandleForReading];
    NSMutableArray *irArgs = [[NSMutableArray alloc] init];
    [irArgs addObject:@"info"];
    [irArgs addObject:@"-plist"];
    [irArgs addObject:volume];
    [irTask setLaunchPath:@"/usr/sbin/diskutil"];
    [irTask setArguments:irArgs];
    //[irTask setStandardError:hdip];
    [irTask setStandardOutput:hdip];
    //NSLog(@"diskutil %@", [[irTask arguments] componentsJoinedByString:@" "]);
    [irTask launch];
    NSData *outData = [hdih readDataToEndOfFile];
    NSString *error;
    NSPropertyListFormat format;
    id plist = [NSPropertyListSerialization propertyListFromData:outData mutabilityOption:kCFPropertyListMutableContainersAndLeaves format:&format errorDescription:&error];
    //    NSLog(@"error: %@", error);
    return plist;
}

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

- (void)xcodeSearchWithCompletion:(void(^)(NSArray <NSDictionary *>*results))block {
    _xcodeResultsBlock = block;
    results = [NSMutableArray new];
    query_ = [[NSMetadataQuery alloc] init];
    NSDictionary *libRt = [self libraryRuntimes];
    if (libRt){
        [results addObject:libRt];
    }
    NSPredicate *predicate = [NSPredicate predicateWithFormat:kApplicationSourcePredicateString];
    NSArray *scope = [NSArray arrayWithObject:NSMetadataQueryLocalComputerScope];
    [query_ setSearchScopes:scope];
    NSSortDescriptor *desc
    = [[NSSortDescriptor alloc] initWithKey:(id)kMDItemLastUsedDate
                                  ascending:NO];
    [query_ setSortDescriptors:[NSArray arrayWithObject:desc]];
    [query_ setPredicate:predicate];
    [query_ setNotificationBatchingInterval:10];
    
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(queryNotification:)
               name:nil
             object:query_];
    
    [query_ startQuery];
}

- (BOOL)bundleShouldBeSuppressed:(NSString *)bundleID {
    return ![bundleID isEqualToString:@"com.apple.dt.Xcode"];
}

- (void)parseResultsOperation:(NSMetadataQuery *)query {
    NSArray *mdAttributeNames = [NSArray arrayWithObjects:
                                 (NSString *)kMDItemDisplayName,
                                 (NSString *)kMDItemPath,
                                 (NSString *)kMDItemContentCreationDate,
                                 (NSString *)kMDItemCFBundleIdentifier,
                                 (NSString *)kMDItemVersion,
                                 nil];
    NSUInteger resultCount = [query resultCount];
    for (NSUInteger i = 0; i < resultCount; ++i) {
        NSMetadataItem *result = [query resultAtIndex:i];
        NSDictionary *mdAttributes = [result valuesForAttributes:mdAttributeNames];
        NSString *path = [mdAttributes objectForKey:(NSString*)kMDItemPath];
        NSString *bundleID = [mdAttributes objectForKey:(NSString *)kMDItemCFBundleIdentifier];
        NSString *version = [mdAttributes objectForKey:(NSString *)kMDItemVersion];
        if (bundleID) {
            if ([self bundleShouldBeSuppressed:bundleID])
                continue;
        } else {
            continue; //if it doesn't have a bundleID were not interested
        }
        
        NSString *name = [mdAttributes objectForKey:(NSString*)kMDItemDisplayName];
        NSArray *components = [path pathComponents];
        
        NSString *fileSystemName = [components objectAtIndex:[components count] - 1];
        if (!name) {
            name = fileSystemName;
        }
        
        NSMutableDictionary *attributes = [NSMutableDictionary new];
        
        
        if ([[path pathExtension] caseInsensitiveCompare:@"app"] == NSOrderedSame) {
            name = [name stringByDeletingPathExtension];
        }
        
        // set last used date
        NSDate *date = [mdAttributes objectForKey:(NSString*)kMDItemContentCreationDate];
        if (!date) {
            date = [NSDate distantPast];
        }
        
        [attributes setObject:date forKey:@"createdDate"];
        
        if (version){
            attributes[@"version"] = version;
        }
        attributes[@"path"] = path;
        attributes[@"name"] = name;
        attributes[@"fsName"] = fileSystemName;
        NSDictionary *runtimes = [self simRuntimesForXcode:path];
        if (runtimes){
            attributes[@"runtimes"] = runtimes[@"platforms"];
        }
        [results addObject:attributes];
        
    }
    if(_xcodeResultsBlock) {
        _xcodeResultsBlock(results);
    }
    //DLog(@"results: %@", results);
    //[query enableUpdates];
}

- (void)queryNotification:(NSNotification *)notification {
  NSString *name = [notification name];
  if ([name isEqualToString:NSMetadataQueryDidFinishGatheringNotification]
      || [name isEqualToString:NSMetadataQueryDidUpdateNotification] ) {
    NSMetadataQuery *query = [notification object];
    [query_ disableUpdates];
    NSOperation *op
      = [[NSInvocationOperation alloc] initWithTarget:self
                                             selector:@selector(parseResultsOperation:)
                                               object:query];
    [[NSOperationQueue mainQueue] addOperation:op];
  }
}

- (void)getFileEntitlementsOnMainThread:(NSString *)inputFile withCompletion:(void(^)(NSDictionary *entitlements))block {
    //DLog(@"checking file: %@", inputFile);
    if (![[NSFileManager defaultManager] fileExistsAtPath:inputFile]){
        //DLog(@"file doesnt exist: %@", inputFile);
        if (block){
            block(nil);
        }
        return;
    }
    NSDictionary *dict = [[classdump sharedInstance] getFileEntitlements:inputFile];
    if (block) {
        block(dict);
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
        NSDictionary *dict = [[classdump sharedInstance] getFileEntitlements:inputFile];
        if (block) {
            block([dict stringRepresentation]);
        }
    });
}


- (void)processRootFolder:(NSString *)rootFolder withCompletion:(void(^)(BOOL success))block {
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
        if (!self.skipDaemons){
            NSArray *paths = [self rawDaemonPathsForPath:rootFolder];
            DLog(@"%@", paths);
            NSString *entOutput = [outputFolder stringByAppendingPathComponent:@"Entitlements"];
            if (![man fileExistsAtPath:entOutput]){
                [man createDirectoryAtPath:entOutput withIntermediateDirectories:true attributes:nil error:nil];
            }
            [paths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                NSString *fullFilePath = [rootFolder stringByAppendingPathComponent:obj];
                [self getFileEntitlementsOnMainThread:fullFilePath withCompletion:^(NSDictionary *entitlements) {
                    if (entitlements) {
                        NSString *fileName = [[entOutput stringByAppendingPathComponent:[obj lastPathComponent]] stringByAppendingPathExtension:@"plist"];
                        //DLog(@"valid ents for %@ writing to file: %@", [obj lastPathComponent], fileName);
                        [entitlements writeToFile:fileName atomically:true];
                        //[entitlements writeToFile:fileName atomically:true encoding:NSUTF8StringEncoding error:nil];
                    }
                }];
            }];
            
            [self processDaemons:paths inRoot:rootFolder toFolder:outputFolder];
        }
        
        //done with daemons et al
        __block NSInteger completedFolders = 0;
        NSArray *exportPaths = @[@"Applications", @"System/Library/Frameworks", @"System/Library/PrivateFrameworks", @"System/Library/HIDPlugins/ServicePlugins", @"System/Library/TVSystemMenuModules"];
        [exportPaths enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [self classDumpBundlesInFolder:[rootFolder stringByAppendingPathComponent:obj] toPath:[outputFolder stringByAppendingPathComponent:obj] completion:^{
                completedFolders++;
                DLog(@"completed folders: %lu count: %lu", completedFolders, exportPaths.count);
                if (completedFolders == exportPaths.count){
                    if (block) {
                        block(TRUE);
                    }
                }
            }];
        }];
        //NSString *outputFile = [NSHomeDirectory() stringByAppendingPathComponent:@"Desktop/daemons.plist"];
        //[rawDaemonDetails writeToFile:outputFile atomically:true];
    });
}

//com.apple.dt.Xcode

// /Applications/Xcode.app/Contents/Developer/Platforms/AppleTVOS.platform/Library/Developer/CoreSimulator/Profiles/Runtimes/tvOS.simruntime/Contents/Resources/RuntimeRoot/System

- (NSArray *)findXcodes {
    char xcPath[MAXPATHLEN];
    long i, n;
    NSMutableArray *xcArray = [NSMutableArray new];
    CFArrayRef appRefs = NULL;
    
    CFStringRef bundleID = CFSTR("com.apple.dt.Xcode");
    
    // LSCopyApplicationURLsForBundleIdentifier is not available before OS 10.10,
    // but this app is used only for OS 10.13 and later
    appRefs = LSCopyApplicationURLsForBundleIdentifier(bundleID, NULL);
    if (appRefs == NULL) {
        //DLog(@"Call to LSCopyApplicationURLsForBundleIdentifier returned NULL");
        return xcArray;
    }
    n = CFArrayGetCount(appRefs);   // Returns all results at once, in database order
    //DLog(@"LSCopyApplicationURLsForBundleIdentifier returned %ld results", n);
    
    for (i=0; i<n; ++i) {     // Prevent infinite loop
        CFURLRef appURL = (CFURLRef)CFArrayGetValueAtIndex(appRefs, i);
        xcPath[0] = '\0';
        if (appURL) {
            CFRetain(appURL);
            CFStringRef CFPath = CFURLCopyFileSystemPath(appURL, kCFURLPOSIXPathStyle);
            CFStringGetCString(CFPath, xcPath, sizeof(xcPath), kCFStringEncodingUTF8);
            if (CFPath) CFRelease(CFPath);
            CFRelease(appURL);
            appURL = NULL;
        }
        //DLog(@"**** Found %s", xcPath);
        NSString *xPath = [NSString stringWithUTF8String:xcPath];
        [xcArray addObject:xPath];
    }
    if (appRefs) CFRelease(appRefs);
    
    return xcArray;
    
}

- (NSDictionary *)runtimeAtPath:(NSString *)path {
    NSString *runtimesPath = [path stringByAppendingPathComponent:@"Contents/Resources/RuntimeRoot"];
    NSString *systemVersionFile = [runtimesPath stringByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
    NSDictionary *sysVers = [NSDictionary dictionaryWithContentsOfFile:systemVersionFile];
    NSString *productName = sysVers[@"ProductName"];
    NSString *productVersion = sysVers[@"ProductVersion"];
    NSString *productBuildVersion = sysVers[@"ProductBuildVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@ %@ (%@)", productName, productVersion, productBuildVersion];
    //DLog(@"found a runtime: %@ at %@", versionString, runtimesPath);
    NSDictionary *platformDict = @{@"name": versionString, @"path": runtimesPath};
    return platformDict;
}

- (NSDictionary *)runtimeAtRelativePath:(NSString *)runtimesPath {
    NSFileManager *man = [NSFileManager defaultManager];
    NSString *relativeRuntime = [[man contentsOfDirectoryAtPath:runtimesPath error:nil] firstObject];
    //NSArray *contents = [man contentsOfDirectoryAtPath:runtimesPath error:nil];
    runtimesPath = [runtimesPath stringByAppendingPathComponent:relativeRuntime];
    runtimesPath = [runtimesPath stringByAppendingPathComponent:@"Contents/Resources/RuntimeRoot"];
    NSString *systemVersionFile = [runtimesPath stringByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
    NSDictionary *sysVers = [NSDictionary dictionaryWithContentsOfFile:systemVersionFile];
    NSString *productName = sysVers[@"ProductName"];
    NSString *productVersion = sysVers[@"ProductVersion"];
    NSString *productBuildVersion = sysVers[@"ProductBuildVersion"];
    NSString *versionString = [NSString stringWithFormat:@"%@ %@ (%@)", productName, productVersion, productBuildVersion];
    //DLog(@"found a runtime: %@ at %@", versionString, runtimesPath);
    NSDictionary *platformDict = @{@"name": versionString, @"path": runtimesPath};
    return platformDict;
}

- (NSDictionary *)simRuntimesForXcode:(NSString *)xcode {
    NSFileManager *man = [NSFileManager defaultManager];
    NSMutableDictionary *currentXC = [NSMutableDictionary new];
    currentXC[@"path"] = xcode;
    NSMutableArray *currentPlatforms = [NSMutableArray new];
    NSString *platformPath = [xcode stringByAppendingPathComponent:@"Contents/Developer/Platforms"];
    NSArray *platforms = [man contentsOfDirectoryAtPath:platformPath error:nil];
    //DLog(@"checking platform path: %@ contents: %@", platformPath, platforms);
    [platforms enumerateObjectsUsingBlock:^(id  _Nonnull platform, NSUInteger pi, BOOL * _Nonnull stop) {
       //Library/Developer/CoreSimulator/Profiles/Runtimes/
        NSString *platformed = [platformPath stringByAppendingPathComponent:platform];
        NSString *runtimesPath = [platformed stringByAppendingPathComponent:@"Library/Developer/CoreSimulator/Profiles/Runtimes"];
        if ([man fileExistsAtPath:runtimesPath]) {
            NSString *relativeRuntime = [[man contentsOfDirectoryAtPath:runtimesPath error:nil] firstObject];
            //NSArray *contents = [man contentsOfDirectoryAtPath:runtimesPath error:nil];
            runtimesPath = [runtimesPath stringByAppendingPathComponent:relativeRuntime];
            runtimesPath = [runtimesPath stringByAppendingPathComponent:@"Contents/Resources/RuntimeRoot"];
            NSString *systemVersionFile = [runtimesPath stringByAppendingPathComponent:@"System/Library/CoreServices/SystemVersion.plist"];
            NSDictionary *sysVers = [NSDictionary dictionaryWithContentsOfFile:systemVersionFile];
            NSString *productName = sysVers[@"ProductName"];
            NSString *productVersion = sysVers[@"ProductVersion"];
            NSString *productBuildVersion = sysVers[@"ProductBuildVersion"];
            NSString *versionString = [NSString stringWithFormat:@"%@ %@ (%@)", productName, productVersion, productBuildVersion];
            //DLog(@"found a runtime: %@ at %@", versionString, runtimesPath);
            NSDictionary *platformDict = @{@"name": versionString, @"path": runtimesPath};
            [currentPlatforms addObject:platformDict];
        }
    }];
    currentXC[@"platforms"] = currentPlatforms;
    return currentXC;
}

- (NSArray *)simRuntimes {
    NSArray <NSString *> *xcodes = [self findXcodes];
    __block NSMutableArray *runtimes = [NSMutableArray new];
    [xcodes enumerateObjectsUsingBlock:^(NSString * _Nonnull xcode, NSUInteger xi, BOOL * _Nonnull stop) {
        NSDictionary *simR = [self simRuntimesForXcode:xcode];
        if (simR){
            [runtimes addObject:simR];
        }
    }];
    return runtimes;
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

- (void)classDumpBundlesInFolder:(NSString *)folderPath toPath:(NSString *)outputPath completion:(void(^)(void))completed {
    NSFileManager *man = [NSFileManager defaultManager];
    __block NSArray *dirContents = [man contentsOfDirectoryAtPath:folderPath error:nil];
    if (![[NSFileManager defaultManager] fileExistsAtPath:folderPath]){
        DLog(@"file exists at path: %@ check count: %lu", folderPath, dirContents.count);
        if (completed){
            completed();
        }
        return;
    }
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), ^{
        //NSArray *dirContents = [man contentsOfDirectoryAtPath:folderPath error:nil];
        //NSString *lastPath = [folderPath lastPathComponent];
        //NSString *outputPath = [folderPath stringByAppendingPathComponent:lastPath];
        [man createDirectoryAtPath:outputPath withIntermediateDirectories:TRUE attributes:nil error:nil];
        //DLog(@"dir contents: %@", dirContents);
        [dirContents enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            
            NSString *fullPath = [folderPath stringByAppendingPathComponent:obj];
            NSString *headerPath = [outputPath stringByAppendingPathComponent:[obj stringByDeletingPathExtension]];
            NSArray *contents = [man contentsOfDirectoryAtPath:headerPath error:nil]; //i know i know...
            if ([man fileExistsAtPath:headerPath] && contents.count > 0) {
                DLog(@"%@ already exists, should we skip it? content count: %lu", headerPath, contents.count);
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
        if (completed){
            completed();
        }
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
