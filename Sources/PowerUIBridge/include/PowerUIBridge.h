#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Apple's installed private API, checked at runtime. No policy enable/disable calls.
@interface CMPowerLimit : NSObject
+ (NSDictionary<NSString *, id> *)readState;
+ (NSDictionary<NSString *, id> *)applyLimit:(uint8_t)limit;
@end
NS_ASSUME_NONNULL_END
