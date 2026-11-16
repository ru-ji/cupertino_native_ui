#import <Foundation/Foundation.h>

// Mirror of ios/.../Support/NativeInterop.swift (@objc(CNUNativeInterop)).
// ffigen reads this header; the Swift class provides the implementation.
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
@end
