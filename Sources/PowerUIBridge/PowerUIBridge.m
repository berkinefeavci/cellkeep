#import "PowerUIBridge.h"
#import <objc/runtime.h>
#import <dlfcn.h>
#import <unistd.h>

@interface NSObject (ChargeMatePowerUI)
- (instancetype)initWithClientName:(NSString *)name;
- (BOOL)isMCLSupported;
- (NSUInteger)isMCLCurrentlyEnabled:(NSError **)error;
- (unsigned char)getMCLLimitWithError:(NSError **)error;
- (id)availableChargeLimitsWithError:(NSError **)error;
- (NSUInteger)currentChargeLimit:(NSError **)error;
- (BOOL)setMCLLimit:(unsigned char)limit error:(NSError **)error;
@end

static BOOL matches(Class cls, NSString *name, const char *signature) {
    Method method=class_getInstanceMethod(cls,NSSelectorFromString(name));
    return method && strcmp(method_getTypeEncoding(method),signature)==0;
}

static id client(void) {
    static void *framework;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ framework=dlopen("/System/Library/PrivateFrameworks/PowerUI.framework/PowerUI",RTLD_LAZY); });
    if(!framework) return nil;
    Class cls=NSClassFromString(@"PowerUISmartChargeClient");
    if(!cls || !matches(cls,@"initWithClientName:","@24@0:8@16") ||
       !matches(cls,@"isMCLSupported","B16@0:8") ||
       !matches(cls,@"isMCLCurrentlyEnabled:","Q24@0:8^@16") ||
       !matches(cls,@"getMCLLimitWithError:","C24@0:8^@16") ||
       !matches(cls,@"availableChargeLimitsWithError:","@24@0:8^@16") ||
       !matches(cls,@"currentChargeLimit:","Q24@0:8^@16")) return nil;
    return [[cls alloc] initWithClientName:@"Cellkeep"];
}

static NSDictionary *failure(NSString *message) { return @{@"error":message}; }

static NSDictionary *readState(id target) {
    if(!target || ![target isMCLSupported]) return failure(@"Bu macOS sürümünde yerel limit arayüzü kullanılamıyor.");
    NSError *error=nil;
    unsigned char limit=[target getMCLLimitWithError:&error];
    if(error || limit<80 || limit>100) return failure(@"Kayıtlı macOS limiti okunamadı.");
    id limits=[target availableChargeLimitsWithError:&error];
    if(error || ![limits isKindOfClass:[NSArray class]] || [limits count]==0) return failure(@"Desteklenen limitler okunamadı.");
    for(id value in limits) {
        if(![value isKindOfClass:[NSNumber class]] || [value intValue]<80 || [value intValue]>100)
            return failure(@"Beklenmeyen macOS limit listesi.");
    }
    NSUInteger enabled=[target isMCLCurrentlyEnabled:&error];
    if(error) return failure(@"macOS şarj durumu okunamadı.");
    NSUInteger current=[target currentChargeLimit:&error];
    if(error) return failure(@"Geçerli sistem limiti okunamadı.");
    return @{@"manualLimit":@(limit),@"availableLimits":limits,@"enabledRaw":@(enabled),@"currentLimit":@(current)};
}

@implementation CMPowerLimit
+ (NSDictionary *)readState { @autoreleasepool { return readState(client()); } }
+ (NSDictionary *)applyLimit:(uint8_t)limit { @autoreleasepool {
    id target=client();
    NSDictionary *before=readState(target);
    if(before[@"error"]) return before;
    if(![before[@"availableLimits"] containsObject:@(limit)] ||
       !matches([target class],@"setMCLLimit:error:","B28@0:8C16^@20"))
        return failure(@"Bu şarj limiti desteklenmiyor; değişiklik yapılmadı.");
    NSError *error=nil;
    BOOL accepted=[target setMCLLimit:limit error:&error];
    if(!accepted || error) return failure(error.localizedDescription ?: @"macOS limit değişikliğini kabul etmedi.");
    for(int attempt=0;attempt<20;attempt++) {
        NSDictionary *after=readState(target);
        if(!after[@"error"] && [after[@"manualLimit"] unsignedCharValue]==limit) return after;
        usleep(250000);
    }
    return failure(@"Limit değişikliği okuma ile doğrulanamadı.");
} }
@end
