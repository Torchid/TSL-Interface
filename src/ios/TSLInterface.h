//
//  TSLInterface.h
//

#import <TSLAsciiCommands/TSLAsciiCommander.h>
#import <Cordova/CDV.h>

@interface TSLInterface : CDVPlugin

- (void)pair:(CDVInvokedUrlCommand*)cordovaComm;
- (void)read:(CDVInvokedUrlCommand*)cordovaComm;
- (void)write:(CDVInvokedUrlCommand*)cordovaComm;
- (NSInteger)getGunIndex;
@end
