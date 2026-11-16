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
@end

NS_ASSUME_NONNULL_END
