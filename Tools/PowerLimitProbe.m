#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <dlfcn.h>
#import <signal.h>
#import <unistd.h>

// Selectors and their exact ABI were inspected in the installed macOS 27 framework.
// This private Apple API is version-dependent. No AlDente code or helper is used.
@interface NSObject (ChargeMatePowerLimit)
- (instancetype)initWithClientName:(NSString *)name;
- (BOOL)isMCLSupported;
- (NSUInteger)isMCLCurrentlyEnabled:(NSError **)error;
- (unsigned char)getMCLLimitWithError:(NSError **)error;
- (id)availableChargeLimitsWithError:(NSError **)error;
- (NSUInteger)currentChargeLimit:(NSError **)error;
- (BOOL)setMCLLimit:(unsigned char)limit error:(NSError **)error;
@end

static volatile sig_atomic_t interrupted=0;
static void interruptTest(int signalNumber) { interrupted=signalNumber; }

static BOOL verifyMethod(Class cls, NSString *name, const char *type) {
    Method method=class_getInstanceMethod(cls,NSSelectorFromString(name));
    return method && strcmp(method_getTypeEncoding(method),type)==0;
}

static NSNumber *readLimit(id client) {
    NSError *error=nil;
    unsigned char limit=[client getMCLLimitWithError:&error];
    if(error || limit<80 || limit>100) {
        fprintf(stderr,"Manual limit read failed: %s\n",error?error.localizedDescription.UTF8String:"out of range");
        return nil;
    }
    return @(limit);
}

static BOOL observeLimit(id client, unsigned char target, BOOL allowInterruption) {
    for(int attempt=0;attempt<20;attempt++) {
        NSNumber *limit=readLimit(client);
        if(limit && limit.unsignedCharValue==target) return YES;
        if(allowInterruption && interrupted) break;
        usleep(250000);
    }
    return NO;
}

int main(int argc,const char *argv[]) { @autoreleasepool {
    BOOL test=argc==2 && strcmp(argv[1],"--test-85-restore")==0;
    if(argc!=2 || (!test && strcmp(argv[1],"--read")!=0)) {
        fprintf(stderr,"Usage: power-limit-probe --read | --test-85-restore\n");
        return 2;
    }
    if(!dlopen("/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI",RTLD_LAZY)) {
        fprintf(stderr,"PowerUI unavailable\n");return 3;
    }
    Class cls=NSClassFromString(@"PowerUISmartChargeClient");
    if(!cls ||
       !verifyMethod(cls,@"initWithClientName:","@24@0:8@16") ||
       !verifyMethod(cls,@"isMCLSupported","B16@0:8") ||
       !verifyMethod(cls,@"isMCLCurrentlyEnabled:","Q24@0:8^@16") ||
       !verifyMethod(cls,@"getMCLLimitWithError:","C24@0:8^@16") ||
       !verifyMethod(cls,@"availableChargeLimitsWithError:","@24@0:8^@16") ||
       !verifyMethod(cls,@"currentChargeLimit:","Q24@0:8^@16")) {
        fprintf(stderr,"Unsupported PowerUI method signatures; no action taken\n");return 3;
    }
    id client=[[cls alloc] initWithClientName:@"ChargeMate"];
    if(!client || ![client isMCLSupported]) { fprintf(stderr,"Manual charge limit unsupported\n");return 3; }
    NSNumber *original=readLimit(client);
    if(!original) return 3;
    NSError *error=nil;
    id limits=[client availableChargeLimitsWithError:&error];
    if(error || ![limits isKindOfClass:[NSArray class]]) { fprintf(stderr,"Available limits unavailable\n");return 3; }
    error=nil;
    NSUInteger enabled=[client isMCLCurrentlyEnabled:&error];
    if(error) { fprintf(stderr,"MCL state unavailable\n");return 3; }
    error=nil;
    NSUInteger current=[client currentChargeLimit:&error];
    if(error) { fprintf(stderr,"Current limit unavailable\n");return 3; }
    NSDictionary *state=@{@"mode":test?@"test":@"read-only",@"manualLimit":original,
                          @"availableLimits":limits,@"enabledRaw":@(enabled),@"currentLimit":@(current)};
    NSData *json=[NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingSortedKeys error:nil];
    puts([[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding].UTF8String);
    fflush(stdout);
    if(!test) return 0; // The default runner uses only this read branch.

    // A narrow, explicitly opt-in diagnostic; never enables/disables MCL or changes its policy.
    if(original.unsignedCharValue!=80 || ![limits containsObject:@80] || ![limits containsObject:@85] ||
       !verifyMethod(cls,@"setMCLLimit:error:","B28@0:8C16^@20")) {
        fprintf(stderr,"Test requires an existing 80%% manual limit and verified 85%% support; no write\n");return 4;
    }
    signal(SIGINT,interruptTest); signal(SIGTERM,interruptTest); signal(SIGHUP,interruptTest);
    BOOL attempted=NO,verified=NO,restored=NO;
    @try {
        if(!interrupted) {
            attempted=YES;
            error=nil;
            BOOL accepted=[client setMCLLimit:85 error:&error];
            verified=accepted && !error && observeLimit(client,85,YES);
            printf("85%% configuration readback: %s\n",verified?"verified":"failed");
            if(error) fprintf(stderr,"Set error: %s\n",error.localizedDescription.UTF8String);
        }
    } @finally {
        if(attempted) {
            NSError *restoreError=nil;
            BOOL accepted=[client setMCLLimit:80 error:&restoreError];
            restored=accepted && !restoreError && observeLimit(client,80,NO);
            printf("80%% restoration readback: %s\n",restored?"verified":"FAILED — restore in System Settings > Battery");
            if(restoreError) fprintf(stderr,"Restore error: %s\n",restoreError.localizedDescription.UTF8String);
        }
    }
    // Successful configuration round-trip does not by itself prove charge-current behavior.
    return !attempted ? 5 : !restored ? 6 : !verified ? 7 : 0;
} }
