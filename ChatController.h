//
//  ChatController.h
//  ChatGPTiger
//
//  Created by Colton Booth
//  Copyright 2023 Booth Software Inc. All rights reserved. Released under Apache 2 Licence.
//

#import <Cocoa/Cocoa.h>

@interface ChatController : NSObject {
    IBOutlet NSTextField *userMessageField;
    IBOutlet NSTextView *chatLog;
    IBOutlet NSTextField *proxyServer;
    
    NSSpeechSynthesizer *synthesizer;
    id webView; // Dynamically loaded WebView
    NSMutableArray *chatHistory; // Store history for saving
}

- (IBAction)sendMessage:(id)sender;
- (IBAction)clearChat:(id)sender;
- (IBAction)saveChat:(id)sender;

@end