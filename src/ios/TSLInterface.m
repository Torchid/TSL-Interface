//
//  TSLInterface.m
//

#import <TSLAsciiCommands/TSLAsciiCommander.h>
#import <TSLAsciiCommands/TSLInventoryCommand.h>
#import <TSLAsciiCommands/TSLLoggerResponder.h>
#import <TSLAsciiCommands/TSLFactoryDefaultsCommand.h>
#import <TSLAsciiCommands/TSLVersionInformationCommand.h>
#import <TSLAsciiCommands/TSLBinaryEncoding.h>
#import <TSLAsciiCommands/TSLWriteSingleTransponderCommand.h>
#import <TSLAsciiCommands/TSLReadTransponderCommand.h>
#import <Cordova/CDV.h>
#import "TSLInterface.h"

@interface TSLInterface ()
{
    //Controls connection to TSL Reader
    TSLAsciiCommander* _commander;
    TSLInventoryCommand* _inventoryResponder;
    TSLReadTransponderCommand* _readCommand;
    EAAccessory* _rfidGun;
    BOOL _inWriteMode;
    
    CDVInvokedUrlCommand* _command;
    CDVPluginResult* _pluginResult;
    
    //List of available devices connected to phone via Bluetooth
    NSArray * _accessoryList;
    //List of compatable devices
    NSArray * _rfidScanners;
    //Index of device that commander will connect to
    NSInteger _chosenDeviceIndex;
    //Number of tags read in a scan
    NSInteger _transpondersSeen;
    //String to hold tag data to be returned to main app
    NSString* _resultMessage;
    NSMutableDictionary *_transpondersRead;
}

@end

@implementation TSLInterface

//Pair the app to a Bluetooth-connected RFID device and send the inventory command
//to the device.  The inventory command allows the gun's trigger to be pulled to
//identify all nearby tags.
-(void)pair:(CDVInvokedUrlCommand*)cordovaComm
{
    //[self.commandDelegate runInBackground:^{
        _pluginResult = nil;
        _resultMessage = @"";
        _transpondersSeen = 0;
        _rfidScanners = @[@"1128"];
        _inWriteMode = false;
        //Store the command so the transponder receiver can access it to
        //send back tag data to the main app.
        _command = cordovaComm;
        
        // Create the TSLAsciiCommander used to communicate with the TSL Reader
        _commander = [[TSLAsciiCommander alloc] init];
        _accessoryList = [[EAAccessoryManager sharedAccessoryManager] connectedAccessories];
        _transpondersRead = [[NSMutableDictionary alloc] init];
        
        do
        {
            // Disconnect from the current reader, if any
            [_commander disconnect];
            
            _accessoryList = [[EAAccessoryManager sharedAccessoryManager] connectedAccessories];
            NSLog(@"Accessory list has %ld items", _accessoryList.count);
            
            //Find the first RFID scanner in the array
            _chosenDeviceIndex = [self getGunIndex];
            
            if(_chosenDeviceIndex != -1)
            {
                // Connect to the chosen TSL Reader
                _rfidGun = _accessoryList[_chosenDeviceIndex];
                [_commander connect:_rfidGun];
            }
            else{
                _resultMessage = @"Scanner not found.";
                NSLog(@"Scanner not found.");
                _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:_resultMessage];
                [_pluginResult setKeepCallbackAsBool:YES];
                [self.commandDelegate sendPluginResult:_pluginResult callbackId:cordovaComm.callbackId];
                _resultMessage = @"";
                [NSThread sleepForTimeInterval:2.0f];
            }
        }while(!_commander.isConnected);
        
        // Issue commands to the reader
        NSLog(@"Commander is connected!");
        
        // Add a logger to the commander to output all reader responses to the log file
        [_commander addResponder:[[TSLLoggerResponder alloc] init]];
        
        // Some synchronous commands will be used in the app
        [_commander addSynchronousResponder];
        
        // The TSLInventoryCommand is a TSLAsciiResponder for inventory responses and can have a delegate
        // (id<TSLInventoryCommandTransponderReceivedDelegate>) that is informed of each transponder as it is received
        
        // Create a TSLInventoryCommand
        _inventoryResponder = [[TSLInventoryCommand alloc] init];
        
        // Add self as the transponder delegate
        _inventoryResponder.transponderReceivedDelegate = (id) self;
        
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
        
        _resultMessage = [NSString stringWithFormat:@"%@ is connected.", versionCommand.serialNumber];
        _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:_resultMessage];
        [_pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:_pluginResult callbackId:cordovaComm.callbackId];
        _resultMessage = @"";
        
   // }];
}

//Once tags have been identified by the inventory command, the retrieved EPC numbers can be passed
//to the read function to pull more detailed data off the tags.  This function is reading the
//tag's user data.
- (void)read:(CDVInvokedUrlCommand*)cordovaComm
{
    //  [self.commandDelegate runInBackground:^{
    // BOOL parametersValid = [self extractAndValidateTransponderInformation:YES];
    
    NSString* epc = [cordovaComm.arguments objectAtIndex:0];
    NSString* readResult = @"";
    
    // Display the target transponder
    NSLog(@"Read from: %@", epc);
    
    @try
    {
        _readCommand = [[TSLReadTransponderCommand alloc] init];
        _readCommand = [TSLReadTransponderCommand synchronousCommand];
        //_readCommand = [[TSLReadTransponderCommand alloc] init];
        
        // Configure the command
        
        // Use the select parameters to write to a single tag
        // Set the match pattern to the full EPC
        _readCommand.selectBank = TSL_DataBank_ElectronicProductCode;
        _readCommand.selectData = epc;
        _readCommand.selectOffset = 32;                                  // This offset is in bits
        _readCommand.selectLength = (int)epc.length * 4;   // This length is in bits
        
        
        // Set the locations to read from
        _readCommand.offset = 0;
        _readCommand.length = 8;
        
        // This demo only works with open tags
        _readCommand.accessPassword = 0;
        
        // Set the bank to be used
        _readCommand.bank = TSL_DataBank_User;
        
        // Set self as delgate to listen for each transponder read - there may be more than one that can match
        // the given EPC
        // Note: this demo is not designed to differentiate multiple responses
        _readCommand.transponderReceivedDelegate = (id)self;
        
        // Collect the responses in a dictionary
        _transpondersRead = [NSMutableDictionary dictionary];
        
        //_readCommand.transponderReceivedBlock = ^(NSString *epc, NSNumber *crc, NSNumber *pc, NSNumber *rssi, NSNumber *index, NSData *readData, BOOL moreAvailable)
        //{
        //   NSLog(@"Block called");
        //};
        
        // Execute the command
        
        //BOOL readWasExecuted = false;
        
        //     do{
        //       if([_commander isResponsive]){
        [_commander executeCommand:_readCommand];
        //         readWasExecuted = true;
        //   }
        // }while(!readWasExecuted);
        
        // Display the data returned
        if( _transpondersRead.count == 0 )
        {
            readResult = @"Transponder not found.";
        }
        else
        {
            // There should only be one response in the dictionary
            for( NSData *tagData in [_transpondersRead objectEnumerator] )
            {
                if( tagData.length != 0 )
                {
                    readResult = [readResult stringByAppendingString:[TSLBinaryEncoding toBase16String:tagData]];
                }
                else
                {
                    readResult = @"None defined.";
                }
            }
        }
        // }
        //        else
        //        {
        //            self.resultsTextView.text = [self.resultsTextView.text stringByAppendingString:@"Check the parameters!"];
        //
        //        }
    }
    @catch (NSException *exception)
    {
        NSLog(@"Exception: %@\n\n", exception.reason);
    }
    
    NSLog(@"Final read result: %@", readResult);
    _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:readResult];
    [_pluginResult setKeepCallbackAsBool:NO];
    [self.commandDelegate sendPluginResult:_pluginResult callbackId:cordovaComm.callbackId];
    // }];
}

//Tags that have been identified by the inventory command with an EPC number can now be written to
//with this function.  It overwrites the user data field.
-(void)write:(CDVInvokedUrlCommand*)cordovaComm
{
  //  [self.commandDelegate runInBackground:^{
        @try
        {
            NSString* epc = [cordovaComm.arguments objectAtIndex:0];
            NSString* writeData = [cordovaComm.arguments objectAtIndex:1];
            //Creates a command for writing to a tag, but it must be configured
            TSLWriteSingleTransponderCommand* command = [TSLWriteSingleTransponderCommand synchronousCommand];
            
            NSLog(@"epc to find: %@", epc);
            NSLog(@"data to write: %@", writeData);
            
            // Use the select parameters to write to a single tag
            // Set the match pattern to the full EPC
            command.selectBank = TSL_DataBank_ElectronicProductCode;
            command.selectData = epc;
            command.selectOffset = 32;                                  // This offset is in bits
            command.selectLength = (int)epc.length * 4;   // This length is in bits
            
            //Default password for open tag
            command.accessPassword = 0;
            
            //Set bank to EPC
            command.bank = TSL_DataBank_User;
            
            //Set the data to be written
            command.data = [TSLBinaryEncoding fromBase16String:writeData];
            
            // Set the locations to write to - this demo writes all the data supplied
            command.offset = 0;
            command.length = (int)command.data.length / 2;       // This length is in words
            
            // Execute the command
            [_commander executeCommand:command];
            
            
            // Display the target transponder
            NSLog(@"Write to: %@\n", epc);
         //   NSLog(@"%@",transponderDetailsMessage);
            
            // Display the outcome of the
            if( command.isSuccessful )
            {
                NSLog(@"Data written successfully");
            }
            else
            {
                NSLog(@"Data write FAILED\n");
                for (NSString *msg in command.messages)
                {
                    NSLog(@"Command message: %@", msg);
                }
            }
        }
        @catch (NSException *exception)
        {
            NSLog(@"Exception: %@\n\n", exception.reason);
        }
        
        _resultMessage = @"Write callback";
        _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:_resultMessage];
        [_pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:_pluginResult callbackId:cordovaComm.callbackId];
        _resultMessage = @"";
   // }];
}

-(NSInteger)getGunIndex
{
    for (int i = 0; i < _accessoryList.count; i++) {
        if([_rfidScanners containsObject:((EAAccessory*) _accessoryList[i]).name])
            return i;
    }
    return -1;
}

//Receiver method for the inventory command (specified in the pair function)
//Each transponder received from the reader is passed to this method
//Parameters epc, crc, pc, and rssi may be nil
//
//Note: This is an asynchronous call from a separate thread
//
-(void)transponderReceived:(NSString *)epc crc:(NSNumber *)crc pc:(NSNumber *)pc rssi:(NSNumber *)rssi fastId:(NSData *)fastId moreAvailable:(BOOL)moreAvailable
{
    // Append the transponder EPC identifier and RSSI to the results
    //_partialResultMessage = [_partialResultMessage stringByAppendingFormat:@"%-28s  %4d\n", [epc UTF8String], [rssi intValue]];
    
    // unsigned int baseTenVal;
    //NSScanner* scanner = [NSScanner scannerWithString:epc];
    //[scanner scanHexInt:&baseTenVal];
    
    // _partialResultMessage = @"";
    _resultMessage = [_resultMessage stringByAppendingFormat:@"%-24s", [epc UTF8String]];
//    NSString* epcConvert = @"";
//    epcConvert = [epcConvert stringByAppendingFormat:@"%-24s", [epc UTF8String]];

    if (moreAvailable) {
        _resultMessage = [_resultMessage stringByAppendingFormat:@"--"];
    }
    _transpondersSeen++;
    
    // If this is the last transponder send the results back to the app
    if( !moreAvailable )
    {
        NSLog(@"Result Message: %@", _resultMessage);
        if (_resultMessage != nil && [_resultMessage length] > 0) {
            _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:_resultMessage];
        } else {
            _pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR];
        }
        
        [_pluginResult setKeepCallbackAsBool:YES];
        [self.commandDelegate sendPluginResult:_pluginResult callbackId:_command.callbackId];
        
        _transpondersSeen = 0;
        _resultMessage = @"";
    }
}

//
//Receiver method for the read command, specified in the read function
//
// (If a partial EPC match is used then more than one transponder may be returned)
//
-(void)transponderReceivedFromRead:(NSString *)epc crc:(NSNumber *)crc pc:(NSNumber *)pc rssi:(NSNumber *)rssi index:(NSNumber *)index data:(NSData *)readData moreAvailable:(BOOL)moreAvailable
{
    if( epc != nil )
    {
        if( readData != nil )
        {
            [_transpondersRead setObject:readData forKey:epc];
        }
        else
        {
            NSLog(@"No data for transponder: %@", epc);
        }
    }
}


//The following methods control commander when app enters and exits background.  Not yet sure if these
//are helpful for a Cordova project.

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    [_commander disconnect];
    NSLog(@"Application became inactive");
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    // Attempt to reconnect to the last used accessory
    [_commander connect:nil];
    NSLog(@"Application became active");
}


@end
