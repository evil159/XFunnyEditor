//
//  PreferenceWindowController.m
//  XFunnyEditor
//
//  Created by Kenji Abe on 2013/09/26.
//  Copyright (c) 2013年 STAR-ZERO. All rights reserved.
//

#import "PreferenceWindowController.h"

@interface PreferenceWindowController ()

@end

@implementation PreferenceWindowController

- (void)windowWillClose:(NSNotification *)notification
{
    int result = 1;
    if (self.textFile && ![self.textFile.stringValue isEqualToString:@""]) {
        // result ok
        result = 0;
    }
    [[NSApplication sharedApplication] stopModalWithCode:result];
}

#pragma mark -
#pragma mark Actions

- (IBAction)clickFile:(id)sender {
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    NSArray *fileTypes = [[[NSArray alloc] initWithObjects:@"png", @"jpg", @"jpeg", nil] autorelease];

    [openPanel setCanChooseDirectories:YES];
    [openPanel setCanChooseFiles:YES];
    [openPanel setAllowedFileTypes:fileTypes];

    [openPanel beginSheetModalForWindow:self.window completionHandler:^(NSInteger resultCode){
        if (resultCode == NSOKButton) {
            NSURL *pathURL = [openPanel URLs][0];
            NSString *imagePath = [pathURL path];
            
            [self.textFile setStringValue:imagePath];
            
            [self.delegate selectedImageFile:imagePath];
        }
    }];
}

- (IBAction)changePosition:(id)sender {
    NSInteger index = [self.imagePosition indexOfSelectedItem];
    [self.delegate selectedPosition:index];
}

- (IBAction)changeSliderOpactiy:(id)sender {
    NSUInteger opacity = floor([self.sliderOpacity floatValue]);
    [self.labelOpacity setStringValue:[NSString stringWithFormat:@"%ld", opacity]];
    
    [self.delegate selectedOpacity:opacity / 100.0];
}

- (IBAction)onEnablePictureTimer:(NSButton *)sender {
    [self.timerValue setEnabled:sender.state];
    [self.timeStepper setEnabled:sender.state];
    [self.timeRangeSelector setEnabled:sender.state];
    // disabled temporarly
//    [self.randomOrder setEnabled:sender.state];
    if (sender.state == 0) {
        [self.delegate selectedTimeInterval:0.f];
        [self.timerValue setDoubleValue:0.f];
        [self.randomOrder setState:0];
    }
}

- (IBAction)onSetTimerValue:(NSTextField *)sender {
    NSUInteger index = [self.timeRangeSelector indexOfSelectedItem];
    
    [self.delegate selectedTimeInterval:[sender doubleValue] * [self timeMultiplierForIndex:index]];
}

- (IBAction)onSetRandomOrder:(NSButton *)sender {
    [self.delegate selectedRandomOrder:sender.state];
}

- (IBAction)onSelectTimeUnits:(NSPopUpButton *)sender {
    CGFloat timerValue = [self.timerValue floatValue];
    NSUInteger index = [sender indexOfSelectedItem];
    [self.delegate selectedTimeInterval:timerValue * [self timeMultiplierForIndex:index]];
}

- (IBAction)onChangeTimerValue:(NSStepper *)sender {
    CGFloat currentTime = [self.timerValue doubleValue];
    CGFloat stepperValue = [sender doubleValue];

    currentTime += stepperValue;
    currentTime = MAX(0, currentTime);
    [self.timerValue setDoubleValue:currentTime];
    [sender setDoubleValue:0.f];
}

- (IBAction)checkAndNotifyDelegateOnSize:(NSTextField *)sender {
    NSSize imageSize = NSMakeSize([self.imageWidth doubleValue], [self.imageHeight doubleValue]);
    if (imageSize.width && imageSize.height) {
        [self.delegate selectedImageSize:imageSize];
    }
}

#pragma mark -
#pragma mark Private

- (CGFloat)timeMultiplierForIndex:(NSUInteger)index {
    switch (index) {
        case 0:
            return 1.f;
        case 1:
            return 60.f;
        case 2:
            return 60.f * 60.f;
        case 3:
            return 60.f * 60.f * 24.f;
        default:
            return 0;
    }
}

@end
