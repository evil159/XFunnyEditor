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
            NSURL *pathURL = [[openPanel URLs] objectAtIndex:0];
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
    [self.randomOrder setEnabled:sender.state];
    if (sender.state == 0) {
        [self.delegate selectedTimeInterval:0.f];
    } else {
        [self.timerValue setStringValue:@"0"];
        [self.randomOrder setState:0];
    }
}

- (IBAction)onSetTimerValue:(NSTextField *)sender {
    [self.delegate selectedTimeInterval:sender.doubleValue];
}

- (IBAction)onSetRandomOrder:(NSButton *)sender {
    [self.delegate selectedRandomOrder:sender.state];
}

@end
