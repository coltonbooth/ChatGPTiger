//
//  ChatController.m
//  ChatGPTiger
//
//  Created by Colton Booth
//  Copyright 2023 Booth Software Inc. All rights reserved. Released under Apache 2 Licence.
//

#import <Cocoa/Cocoa.h>

@interface ChatController : NSObject <NSCoding> {
    IBOutlet NSTextField *userMessageField;
    IBOutlet NSTextView *chatLog;
    IBOutlet NSTextField *proxyServer;
}

- (id)initWithCoder:(NSCoder *)coder;
- (IBAction)sendMessage:(id)sender;
- (IBAction)clearChat:(id)sender;
- (IBAction)saveChat:(id)sender;

@end
