//
//  TSLInterface.h
//
//  Parameters of CDVInvokedUrl Command should be:
// 	1.  Java function that takes in a string as a parameter

#import <TSLAsciiCommands/TSLAsciiCommander.h>
#import <Cordova/CDV.h>

@interface TSLInterface : CDVPlugin

- (void)pair:(CDVInvokedUrlCommand*)command;
- (NSInteger)getGunIndex;
@end
