//
//  InputReceiver.m
//  Mouse Remap Helper
//
//  Created by Noah Nübling on 19.11.18.
//  Copyright © 2018 Noah Nuebling Enterprises Ltd. All rights reserved.
//

#import "InputReceiver.h"
#import "IOKit/hid/IOHIDManager.h"
#import "InputParser.h"
#import "AppDelegate.h"
#import <ApplicationServices/ApplicationServices.h>

#import "MomentumScroll.h"

@implementation InputReceiver



// global variables
static BOOL _relevantDevicesAreAttached;
+ (BOOL)relevantDevicesAreAttached {
    return _relevantDevicesAreAttached;
}

BOOL inputSourceIsDeviceOfInterest;
CGEventSourceRef eventSource;
CFMachPortRef eventTap;
IOHIDManagerRef _hidManager;

+ (void) start {
    // initialize global variables
    inputSourceIsDeviceOfInterest = false;
    eventSource = CGEventSourceCreate(kCGEventSourceStatePrivate);

    // setup callbacks for mouse input
    setupMouseInputCallbacks();
    // setup modifier key callback
    setupModifierKeyCallback();
}

static void setupModifierKeyCallback() {
    /* Register event Tap Callback */
    CGEventMask mask = CGEventMaskBit(kCGEventFlagsChanged);
    eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, Handle_ModifierChanged, NULL);
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
}

CGEventRef Handle_ModifierChanged(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
    
    AppDelegate *appDelegate = [NSApp delegate];
    
    int64_t keycode = CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    CGEventFlags flags = CGEventGetFlags(event);
    
    if ( (keycode == 56) || (keycode == 60) ) {
        if (flags != 256) {
            [appDelegate setHorizontalScroll: TRUE];
        } else if (flags == 256) {
            [appDelegate setHorizontalScroll: FALSE];
        }
     }
    
    
    return event;
}

CGEventRef Handle_MouseEvent(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo) {
 
    /*
    NSLog(@"HANDLE EVENT");
    NSLog(@"current button: %d", currentButton);
    NSLog(@"inputSourceIsDeviceOfInterest: %d", inputSourceIsDeviceOfInterest);
     */
    
    int currentButton = (int) CGEventGetIntegerValueField(event, kCGMouseEventButtonNumber) + 1;
    int currentButtonState = (int) CGEventGetIntegerValueField(event, kCGMouseEventPressure);
    if (currentButtonState == 255) {
        currentButtonState = 1;
    }

    
    
    if (inputSourceIsDeviceOfInterest ) {
        if ( (3 <= currentButton) && (currentButton <= 5) ) {
            
            CGEventRef eventPass = [InputParser parse:currentButton state:currentButtonState event:event];
            return eventPass;
        }
    }
    
    return event;
}


static void setupMouseInputCallbacks() {
    /* Register event Tap Callback */
    CGEventMask mask = CGEventMaskBit(kCGEventLeftMouseDown) | CGEventMaskBit(kCGEventRightMouseDown)                               |CGEventMaskBit(kCGEventOtherMouseDown)
    | CGEventMaskBit(kCGEventLeftMouseUp) | CGEventMaskBit(kCGEventRightMouseUp)                               |CGEventMaskBit(kCGEventOtherMouseUp);
    eventTap = CGEventTapCreate(kCGHIDEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, mask, Handle_MouseEvent, NULL);
    
    CFRunLoopSourceRef runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0);
    CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
    CFRelease(runLoopSource);
    
    
    
    setupHIDManagerAndCallbacks();
    
}

static void setupHIDManagerAndCallbacks() {

    
    // Create an HID Manager
    _hidManager = IOHIDManagerCreate(kCFAllocatorDefault, 0);
    
    // Create a Matching Dictionary
    CFMutableDictionaryRef matchDict1 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                  2,
                                                                  &kCFTypeDictionaryKeyCallBacks,
                                                                  &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef matchDict2 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                  2,
                                                                  &kCFTypeDictionaryKeyCallBacks,
                                                                  &kCFTypeDictionaryValueCallBacks);
    CFMutableDictionaryRef matchDict3 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                  2,
                                                                  &kCFTypeDictionaryKeyCallBacks,
                                                                  &kCFTypeDictionaryValueCallBacks);
    
    
    
    // Specify properties of the devices which we want to add to the HID Manager in the Matching Dictionary
    
    //int n = 0x227;
    
    CFArrayRef matches;
    
    int up = 1;
    int u = 2;
    CFNumberRef genericDesktopPrimaryUsagePage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &up);
    CFNumberRef mousePrimaryUsage = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &u);
    
    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsage"), genericDesktopPrimaryUsagePage);
    CFDictionarySetValue(matchDict1, CFSTR("PrimaryUsage"), mousePrimaryUsage);         // add mice
    CFDictionarySetValue(matchDict1, CFSTR("Transport"), CFSTR("USB"));                 // add USB devices
    
    CFMutableDictionaryRef matchesList[] = {matchDict1};
    matches = CFArrayCreate(kCFAllocatorDefault, (const void **)matchesList, 1, NULL);
    
    
    NSLog(@"HIDManager: %@", _hidManager);
    NSLog(@"matches: %@", matchDict2);
    
    //Register the Matching Dictionary to the HID Manager
    IOHIDManagerSetDeviceMatchingMultiple(_hidManager, matches);
    
    CFRelease(matches);
    CFRelease(matchDict1);
    CFRelease(matchDict2);
    CFRelease(matchDict3);
    
    
    
    
    // Register the HID Manager on our app’s run loop
    IOHIDManagerScheduleWithRunLoop(_hidManager, CFRunLoopGetMain(), kCFRunLoopDefaultMode);
    
    // Open the HID Manager
    IOReturn IOReturn = IOHIDManagerOpen(_hidManager, kIOHIDOptionsTypeNone);
    if(IOReturn) NSLog(@"IOHIDManagerOpen failed.");  //  Couldn't open the HID manager! TODO: proper error handling
    
    
    
    // Register a callback for USB device detection with the HID Manager, this will in turn register an button input callback for all devices that getFilteredDevicesFromManager() returns
    IOHIDManagerRegisterDeviceMatchingCallback(_hidManager, &Handle_DeviceMatchingCallback, NULL);
    
    
    
    // Register a callback for USB device removal with the HID Manager
    IOHIDManagerRegisterDeviceRemovalCallback(_hidManager, &Handle_DeviceRemovalCallback, NULL);
    
    //CFArrayRef device_array = getFilteredDevicesFromManager(HIDManager);
    //registerButtonInputCallbackForDevices(device_array);
}



/* HID Manager Callback Handlers */



static void Handle_InputValueCallback(void *context, IOReturn result, void *sender, IOHIDValueRef value) {
    
    inputSourceIsDeviceOfInterest = true;
    
    //NSLog(@"Button Input from Registered Device %@, button: %@", sender, value);
}

static void Handle_DeviceRemovalCallback(void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    // MomentumScroll
    CFSetRef devices = IOHIDManagerCopyDevices(_hidManager);
    if (CFSetGetCount(devices) == 0) {
        _relevantDevicesAreAttached = FALSE;
        [MomentumScroll stop];
    }
    
}


static void Handle_DeviceMatchingCallback (void *context, IOReturn result, void *sender, IOHIDDeviceRef device) {
    
    NSLog(@"New matching device");
    
    // currently filters devices with "magic" in their name string - untested
    if (devicePassesFiltering(device) ) {
        NSLog(@"Device Passed filtering");
        registerButtonInputCallbackForDevice(device);
    }
    
    // MomentumScroll
    _relevantDevicesAreAttached = TRUE;
    NSLog(@"isEnabled:                %hhd", MomentumScroll.isEnabled);
    NSLog(@"MomentumScroll.isRunning: %hhd", MomentumScroll.isRunning);

    if (MomentumScroll.isEnabled && !MomentumScroll.isRunning) {
        [MomentumScroll start];
    }
    
    
    
    
    // print stuff
    
    // Retrieve the device name & serial number
    NSString *devName = [NSString stringWithUTF8String:
                         CFStringGetCStringPtr(IOHIDDeviceGetProperty(device, CFSTR("Product")), kCFStringEncodingMacRoman)];
    
    
    NSString *devPrimaryUsage = IOHIDDeviceGetProperty(device, CFSTR("PrimaryUsage"));
    
    // Log the device reference, Name, Serial Number & device count
    NSLog(@"\nMatching device added: %p\nModel: %@\nUsage: %@\nMatching",
          device,
          devName,
          devPrimaryUsage
          //filteredUSBDeviceCount(sender)
          );
    
    
    return;
    
}





// Convenience Functions



static void registerButtonInputCallbackForDevice(IOHIDDeviceRef device) {
    
    NSLog(@"registering device: %@", device);
    NSCAssert(device != NULL, @"tried to register a device which equals NULL");
    
    
    // Add callback function for the button input from the device
    CFMutableDictionaryRef elementMatchDict1 = CFDictionaryCreateMutable(kCFAllocatorDefault,
                                                                         2,
                                                                         &kCFTypeDictionaryKeyCallBacks,
                                                                         &kCFTypeDictionaryValueCallBacks);
    int nine = 9; // "usage Page" for Buttons
    CFNumberRef buttonRef = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &nine);
    CFDictionarySetValue (elementMatchDict1, CFSTR("UsagePage"), buttonRef);
    IOHIDDeviceSetInputValueMatching(device, elementMatchDict1);
    IOHIDDeviceRegisterInputValueCallback(device, &Handle_InputValueCallback, NULL);
    
    
    CFRelease(elementMatchDict1);
    CFRelease(buttonRef);
    
    
    // v2.0 TODO: (code for adding scrollwheel input to the callback is in the USBHID Project)
    
    
}

static BOOL devicePassesFiltering(IOHIDDeviceRef HIDDevice) {
    
    NSString *deviceName = [NSString stringWithUTF8String:
                            CFStringGetCStringPtr(IOHIDDeviceGetProperty(HIDDevice, CFSTR("Product")), kCFStringEncodingMacRoman)];
    NSString *deviceNameLower = [deviceName lowercaseString];
    
    if ([deviceNameLower rangeOfString:@"magic"].location == NSNotFound) {
        return TRUE;
    } else {
        return FALSE;
    }
}
@end