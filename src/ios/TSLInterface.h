//
//  TSLInterface.h
//

#import <TSLAsciiCommands/TSLAsciiCommander.h>
#import <Cordova/CDV.h>

@interface TSLInterface : CDVPlugin

- (void)pair:(CDVInvokedUrlCommand*)cordovaComm;
- (void)read:(CDVInvokedUrlCommand*)cordovaComm;
- (void)write:(CDVInvokedUrlCommand*)cordovaComm;
- (void)reconnect:(CDVInvokedUrlCommand*)cordovaComm;
- (void)disconnect:(CDVInvokedUrlCommand*)cordovaComm;
- (NSInteger)getGunIndex;
@end
