#import <Foundation/Foundation.h>

// Mirror of ios/.../Support/NativeInterop.swift (@objc(CNUNativeInterop)).
// ffigen reads this header; the Swift class provides the implementation.
NS_ASSUME_NONNULL_BEGIN

@interface CNUNativeInterop : NSObject
+ (BOOL)isLiquidGlassSupported;
+ (void)clearPhotoCache;
+ (nullable NSData *)renderSymbolWithName:(NSString *)name
                                     size:(double)size
                                     argb:(NSInteger)argb
                                 hasColor:(BOOL)hasColor
                                   weight:(NSString *)weight
                              symbolScale:(NSString *)symbolScale
                                    scale:(double)scale;
+ (void)prewarmScaffoldWithRoutesJson:(NSString *)routesJson isDark:(BOOL)isDark;
+ (void)showAlertWithJson:(NSString *)json
               completion:(void (^)(NSString *_Nullable))completion;
+ (void)showActionSheetWithJson:(NSString *)json
                     completion:(void (^)(NSString *_Nullable))completion;
+ (nullable NSData *)invokeWithEngineId:(int64_t)engineId
                                channel:(NSString *)channel
                                 method:(NSString *)method
                                   args:(NSData *)args
                                  token:(int64_t)token;
+ (void)attachWithEngineId:(int64_t)engineId channel:(NSString *)channel;
+ (void)detachWithEngineId:(int64_t)engineId channel:(NSString *)channel;
+ (void)setEventSinkWithEngineId:(int64_t)engineId
                            sink:(void (^)(NSString *channel, NSString *method,
                                           NSData *args))sink;
+ (void)setReplySinkWithEngineId:(int64_t)engineId
                            sink:(void (^)(int64_t token, NSData *reply))sink;
@end

NS_ASSUME_NONNULL_END
