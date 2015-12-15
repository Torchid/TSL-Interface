//
//  TSLInterface.m
//

#import <TSLAsciiCommands/TSLAsciiCommander.h>
#import <TSLAsciiCommands/TSLInventoryCommand.h>
#import <TSLAsciiCommands/TSLLoggerResponder.h>
#import <TSLAsciiCommands/TSLFactoryDefaultsCommand.h>
#import <TSLAsciiCommands/TSLVersionInformationCommand.h>
#import <TSLAsciiCommands/TSLBinaryEncoding.h>
#import <Cordova/CDV.h>
#import "TSLInterface.h"

@interface TSLInterface ()
{
    //Controls connection to TSL Reader
    TSLAsciiCommander* _commander;
    TSLInventoryCommand* _inventoryResponder;
    EAAccessory* _rfidGun;
    
    CDVPluginResult* _pluginResult;
    CDVInvokedUrlCommand* _command;
    
    //List of available devices connected to phone via Bluetooth
    NSArray * _accessoryList;
    //List of compatable devices
    NSArray * _rfidScanners;
    //Index of device that commander will connect to
    NSInteger _chosenDeviceIndex;
    //Number of tags read in a scan
    NSInteger _transpondersSeen;
    //String to hold tag data to be returned to main app
    NSString* _partialResultMessage;
}

@end

@implementation TSLInterface

-(void)pair:(CDVInvokedUrlCommand*)command
{
    _pluginResult = nil;
    _command = command;
    _partialResultMessage = @"";
    _transpondersSeen = 0;
    _rfidScanners = @[@"1128"];
    
    NSLog(@"Entered pair functions!");
    
    // Create the TSLAsciiCommander used to communicate with the TSL Reader
    _commander = [[TSLAsciiCommander alloc] init];
    _accessoryList = [[EAAccessoryManager sharedAccessoryManager] connectedAccessories];
    _chosenDeviceIndex = [self getGunIndex];
    
    if(_chosenDeviceIndex != -1) {
        
        NSLog(@"Accessory list has %ld items", _accessoryList.count);
        
        // Connect to the chosen TSL Reader
        _rfidGun = _accessoryList[_chosenDeviceIndex];
        
        do
        {
            // Disconnect from the current reader, if any
            [_commander disconnect];
            [_commander connect:_rfidGun];
        }while(!_commander.isConnected);
        
        // Issue commands to the reader
        NSLog(@"Commander is connected!");
        
        // Add a logger to the commander to output all reader responses to the log file
        [_commander addResponder:[[TSLLoggerResponder alloc] init]];
        
        // Some synchronous commands will be used in the app
        [_commander addSynchronousResponder];
        
        // Performing an inventory could potentially take a long time if many transponders are in range so it is best to handle responses asynchronously
        //
        // The TSLInventoryCommand is a TSLAsciiResponder for inventory responses and can have a delegate
        // (id<TSLInventoryCommandTransponderReceivedDelegate>) that is informed of each transponder as it is received
        
        // Create a TSLInventoryCommand
        _inventoryResponder = [[TSLInventoryCommand alloc] init];
        
        // Add self as the transponder delegate
        _inventoryResponder.transponderReceivedDelegate = self;
        
        // Pulling the Reader trigger will generate inventory responses that are not from the library.
        // To ensure these are also seen requires explicitly requesting handling of non-library command responses
        _inventoryResponder.captureNonLibraryResponses = YES;
        
        // Add the inventory responder to the commander's responder chain
        [_commander addResponder:_inventoryResponder];
        
        // Ensure the reader is in a known (default) state
        // No information is returned by the reset command other than its succesful completion
        TSLFactoryDefaultsCommand * resetCommand = [TSLFactoryDefaultsCommand synchronousCommand];
        
        [_commander executeCommand:resetCommand];
        
        // Notify user device has been reset
        if( resetCommand.isSuccessful )
        {
            NSLog(@"Reader reset to Factory Defaults\n");
        }
        else
        {
            NSLog(@"!!! Unable to reset reader to Factory Defaults !!!\n");
        }
        
        // Get version information for the reader
        // Use the TSLVersionInformationCommand synchronously as the returned information is needed below
        TSLVersionInformationCommand * versionCommand = [TSLVersionInformationCommand synchronousCommand];
        
        [_commander executeCommand:versionCommand];
        
        // Log some of the values obtained
        NSLog( @"\n%-16s %@\n%-16s %@\n%-16s %@\n\n\n",
              "Manufacturer:", versionCommand.manufacturer,
              "Serial Number:", versionCommand.serialNumber,
              "Antenna SN:", versionCommand.antennaSerialNumber
              );
        
        
        _partialResultMessage = [NSString stringWithFormat:@"%@ is connected.", versionCommand.serialNumber];
        _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:_partialResultMessage];
        [_pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:_pluginResult callbackId:_command.callbackId];
        _partialResultMessage = @"";
    }
}

-(NSInteger)getGunIndex
{
    for (int i = 0; i < _accessoryList.count; i++) {
        if([_rfidScanners containsObject:((EAAccessory*) _accessoryList[i]).name])
            return i;
    }
    return -1;
}

//
// Each transponder received from the reader is passed to this method
//
// Parameters epc, crc, pc, and rssi may be nil
//
// Note: This is an asynchronous call from a separate thread
//
// TEST: Currently only looking at epc result
-(void)transponderReceived:(NSString *)epc crc:(NSNumber *)crc pc:(NSNumber *)pc rssi:(NSNumber *)rssi fastId:(NSData *)fastId moreAvailable:(BOOL)moreAvailable
{
    NSLog(@"transponderReceived Called");
    // Append the transponder EPC identifier and RSSI to the results
    //_partialResultMessage = [_partialResultMessage stringByAppendingFormat:@"%-28s  %4d\n", [epc UTF8String], [rssi intValue]];
    
    // _partialResultMessage = @"";
    _partialResultMessage = [_partialResultMessage stringByAppendingFormat:@"%-24s", [epc UTF8String]];
    
    if (moreAvailable) {
        _partialResultMessage = [_partialResultMessage stringByAppendingFormat:@"--"];
    }
    _transpondersSeen++;
    
    // If this is the last transponder send the results back to the app
    if( !moreAvailable )
    {
        NSLog(@"Result Message: %@", _partialResultMessage);
        if (_partialResultMessage != nil && [_partialResultMessage length] > 0) {
            _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:_partialResultMessage];
        } else {
            _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        }
        
        [_pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:_pluginResult callbackId:_command.callbackId];
        
        _transpondersSeen = 0;
        _partialResultMessage = @"";
    }
}

//Following methods control commander when app enters and exits background.  Not yet sure if these
//are helpful for a Cordova project.

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [_commander disconnect];
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Attempt to reconnect to the last used accessory
    [_commander connect:nil];
}


@end
