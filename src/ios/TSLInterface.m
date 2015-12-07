//
//  TSLInterface.m
//  
//  Parameters of CDVInvokedUrl Command should be:
// 	1.  Java function that takes in a string as a parameter


#import <TSLAsciiCommands/TSLAsciiCommander.h>
#import <Cordova/CDV.h>
#import "TSLInterface.h"

@interface TSLInterface ()
{
    NSString* javaScriptMethod;
}

@end

@implementation TSLInterface

-(void)pair:(CDVInvokedUrlCommand*)command
{
    CDVPluginResult* pluginResult = nil;
    NSString* echo = [command.arguments objectAtIndex:0];

    if (echo != nil && [echo length] > 0) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:echo];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

// -(void)writeTagData:(NSString*)tagData
// {
    // NSString* jsMethodCall = [NSString stringWithFormat:@"%@(\"%@\")", javaScriptMethod, tagData];
	//[webAView stringByEvaluatingJavaScriptFromString:jsMethodCall];
// }

@end