//
//  ChatController.m
//  ChatGPTiger
//
//  Created by Colton Booth 
//  Copyright 2023 Booth Software Inc. All rights reserved. Released under Apache 2 Licence.

#import "ChatController.h"
#import "UserTextField.h"
#import <Cocoa/Cocoa.h>

@implementation ChatController


- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    if (control == userMessageField) {
        NSString *fullString = [fieldEditor string];
        if (fullString) {
			[self sendMessage:control];
        }
    }
    return YES;
}


- (IBAction)clearChat:(id)sender {
	[chatLog setString:@""];
}

- (IBAction)saveChat:(id)sender {
    // Create and configure the save panel
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setRequiredFileType:@"txt"];
    // Display the panel and check for user confirmation
    if ([savePanel runModal] == NSOKButton) {
        // Extract the string content from chatLog NSTextView
        NSString *chatContent = [chatLog string];
        // Get the selected file path
        NSString *filePath = [savePanel filename];
        // Write the content to the selected file
        NSError *error;
        BOOL success = [chatContent writeToFile:filePath
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:&error];
        
        // Handle success or failure
        if (success) {
            NSLog(@"Successfully saved the chat log to %@", filePath);
        } else {
            NSLog(@"Failed to save the chat log: %@", [error localizedDescription]);
        }
    }
}


- (IBAction)sendMessage:(id)sender {
    NSString *message = [userMessageField stringValue];
	[userMessageField setStringValue:@""];
    
    NSMutableString *messageForChat = [NSMutableString stringWithString:@"User: "];
    [messageForChat appendString:message];
    [messageForChat appendString:@"\r\n\r\n"];
    
    NSTextStorage *textStorage = [chatLog textStorage];
    NSAttributedString *attributedTextToAdd = [[[NSAttributedString alloc] initWithString:messageForChat] autorelease];
    [textStorage appendAttributedString:attributedTextToAdd];

    [self scrollChatLogToBottom];

    [self sendRequestToOpenAIWithMessage:message];
}

- (void)sendRequestToOpenAIWithMessage:(NSString *)message {
    // Read proxy server value
    NSString *proxyValue = [proxyServer stringValue];

    // Check if proxyValue is empty or nil before proceeding
    if (proxyValue == nil || [proxyValue isEqualToString:@""]) {
        proxyValue = nil;
        NSArray *addresses = [[NSHost currentHost] addresses];

        // Get local IP address and tack on 8080 by default
        NSEnumerator *e = [addresses objectEnumerator];
        NSString *anAddress;
        while (anAddress = [e nextObject]) {
            if (![anAddress hasPrefix:@"127"] && [[anAddress componentsSeparatedByString:@"."] count] == 4) {
                proxyValue = [NSString stringWithFormat:@"%@:8080", anAddress];
                break;
            }
        }

        // Can't find local IP address
        if (proxyValue == nil) {
            [proxyServer setStringValue:@"Please enter a value!"];
            NSLog(@"Proxy server value is missing.");
            return;
        }
    }

    // Construct URL string
    NSString *urlString = [NSString stringWithFormat:@"http://%@/v1/chat/completions", proxyValue];
    NSLog(@"Sending request to: %@", urlString);

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];

    NSString *messagesString = [self constructMessagesFromChatLog];
    
    // Construct the full JSON body
    NSString *jsonBody = [NSString stringWithFormat: messagesString];
    
    [request setHTTPBody:[jsonBody dataUsingEncoding:NSUTF8StringEncoding]];

    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    // Making the request
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!connection) {
		[proxyServer setStringValue:@"Error! Check Connecton!"];
        NSLog(@"Connection failed");
    }
}


- (NSString *)constructMessagesFromChatLog {
    NSString *fullChat = [chatLog string];
    NSArray *entries = [fullChat componentsSeparatedByString:@"\r\n\r\n"];
    NSMutableString *jsonMessages = [NSMutableString stringWithString:@"["];
    
    unsigned count = [entries count];
    unsigned i;
    for (i = 0; i < count; i++) {
        NSString *entry = [entries objectAtIndex:i];
        if ([entry hasPrefix:@"User: "]) {
            [jsonMessages appendFormat:@"{\"message\":\"%@\"},", [entry substringFromIndex:6]];
        } else if ([entry hasPrefix:@"ChatGPT: "]) {
            [jsonMessages appendFormat:@"{\"role\":\"assistant\",\"content\":\"%@\"},", [entry substringFromIndex:9]];
        }
    }
    
    // Remove the trailing comma
    if ([jsonMessages hasSuffix:@","]) {
        [jsonMessages deleteCharactersInRange:NSMakeRange([jsonMessages length]-1, 1)];
    }
    
    [jsonMessages appendString:@"]"];
    
    return fullChat;
}

#pragma mark - NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (data) {
        NSString *responseString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        NSLog(responseString);
        
        NSString *assistantMessage = responseString;
		
        NSMutableString *messageForChat = [NSMutableString stringWithString:@"ChatGPT: "];
        [messageForChat appendString:assistantMessage];
        [messageForChat appendString:@"\r\n\r\n"];
		
        NSTextStorage *textStorage = [chatLog textStorage];
        NSAttributedString *attributedTextToAdd = [[[NSAttributedString alloc] initWithString:messageForChat] autorelease];
        [textStorage appendAttributedString:attributedTextToAdd];

        [self scrollChatLogToBottom]; // Call to scroll after appending text

    } else {
        NSLog(@"No data received.");
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Connection failed with error: %@", [error localizedDescription]);
}

- (void)scrollChatLogToBottom {
    NSRange range = NSMakeRange([[chatLog string] length], 0);
    [chatLog scrollRangeToVisible:range];
}

@end
