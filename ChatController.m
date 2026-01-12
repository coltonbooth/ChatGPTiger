//
//  ChatController.m
//  ChatGPTiger
//
//  Created by Colton Booth 
//  Copyright 2023 Booth Software Inc. All rights reserved. Released under Apache 2 Licence.

#import "ChatController.h"
#import "UserTextField.h"
#import <Cocoa/Cocoa.h>

// Define a category to silence compiler warnings for WebView methods
// since we are linking dynamically.
@interface NSObject (WebViewDynamic)
- (id)initWithFrame:(NSRect)frame frameName:(NSString *)fName groupName:(NSString *)gName;
- (void)setAutoresizingMask:(unsigned int)mask;
- (id)mainFrame;
- (void)loadHTMLString:(NSString *)string baseURL:(NSURL *)URL;
- (NSString *)stringByEvaluatingJavaScriptFromString:(NSString *)script;
- (void)setDrawsBackground:(BOOL)draws;
- (void)setBackgroundColor:(NSColor *)color;
@end

@implementation ChatController

- (void)awakeFromNib {
    // 1. Initialize Speech Synthesizer
    synthesizer = [[NSSpeechSynthesizer alloc] initWithVoice:nil];
    
    // 2. Initialize Chat History
    chatHistory = [[NSMutableArray alloc] init];
    
    // 3. Setup Layout Constraints for existing controls
    NSScrollView *scrollView = [chatLog enclosingScrollView];
    [scrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    [userMessageField setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    [proxyServer setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    
    // 4. Dynamic WebView Injection for "Bubbles"
    NSBundle *webKitBundle = [NSBundle bundleWithPath:@"/System/Library/Frameworks/WebKit.framework"];
    if ([webKitBundle load]) {
        Class WebViewClass = NSClassFromString(@"WebView");
        if (WebViewClass) {
            NSRect frame = [scrollView frame];
            NSView *superview = [scrollView superview];
            
            // Remove the old NSTextView based scrollview
            [scrollView removeFromSuperview];
            
            // Create the WebView
            webView = [[WebViewClass alloc] initWithFrame:frame frameName:nil groupName:nil];
            [webView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
            
            // Add to window
            [superview addSubview:webView];
            
            // Load initial HTML with CSS for bubbles
            [self loadInitialHTML];
        } else {
            NSLog(@"Could not load WebView class.");
        }
    } else {
        NSLog(@"Could not load WebKit framework.");
    }
}

- (void)loadInitialHTML {
    // Safari 2.0 (Tiger) requires -webkit-border-radius
    NSString *html = @"<html><head><style>"
    "body { font-family: 'Lucida Grande', sans-serif; font-size: 13px; background-color: #f0f0f0; margin: 0; padding: 10px; }"
    ".bubble { max-width: 80%; padding: 8px 12px; margin-bottom: 10px; -webkit-border-radius: 15px; border-radius: 15px; clear: both; position: relative; }"
    ".user { background-color: #007AFF; color: white; float: right; -webkit-border-bottom-right-radius: 2px; border-bottom-right-radius: 2px; }"
    ".assistant { background-color: #E5E5EA; color: black; float: left; -webkit-border-bottom-left-radius: 2px; border-bottom-left-radius: 2px; }"
    ".clearfix { clear: both; }"
    "</style></head><body><div id='chat'></div></body></html>";
    
    [[webView mainFrame] loadHTMLString:html baseURL:nil];
}

- (void)appendMessageToWebView:(NSString *)message isUser:(BOOL)isUser {
    // Escape content for JS
    NSMutableString *escaped = [NSMutableString stringWithString:message];
    [escaped replaceOccurrencesOfString:@"\\" withString:@"\\\\" options:NSLiteralSearch range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange(0, [escaped length])];
    [escaped replaceOccurrencesOfString:@"\n" withString:@"<br>" options:NSLiteralSearch range:NSMakeRange(0, [escaped length])];
    
    NSString *className = isUser ? @"user" : @"assistant";
    NSString *js = [NSString stringWithFormat:
                    @"var container = document.getElementById('chat');"
                    @"var bubble = document.createElement('div');"
                    @"bubble.className = 'bubble %@';"
                    @"bubble.innerHTML = \"%@\";"
                    @"container.appendChild(bubble);"
                    @"var cleaner = document.createElement('div');"
                    @"cleaner.className = 'clearfix';"
                    @"container.appendChild(cleaner);"
                    @"window.scrollTo(0, document.body.scrollHeight);",
                    className, escaped];
    
    [webView stringByEvaluatingJavaScriptFromString:js];
}

- (BOOL)control:(NSControl *)control textShouldEndEditing:(NSText *)fieldEditor {
    if (control == userMessageField) {
        NSString *fullString = [fieldEditor string];
        if (fullString && [fullString length] > 0) {
            // Check if it's just a newline or enter
             if (![fullString isEqualToString:@"\n"]) {
                 [self sendMessage:control];
             }
        }
    }
    return YES;
}

- (IBAction)clearChat:(id)sender {
    [chatHistory removeAllObjects];
    [self loadInitialHTML];
    // Also clear legacy chatLog just in case
	[chatLog setString:@""];
}

- (IBAction)saveChat:(id)sender {
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    [savePanel setRequiredFileType:@"txt"];
    if ([savePanel runModal] == NSOKButton) {
        // Construct text log from history array
        NSMutableString *exportString = [NSMutableString string];
        NSEnumerator *e = [chatHistory objectEnumerator];
        NSDictionary *item;
        while (item = [e nextObject]) {
            NSString *role = [item objectForKey:@"role"];
            NSString *content = [item objectForKey:@"content"];
            NSString *prefix = [role isEqualToString:@"user"] ? @"User: " : @"ChatGPT: ";
            [exportString appendFormat:@"%@%@\r\n\r\n", prefix, content];
        }
        
        NSString *filePath = [savePanel filename];
        NSError *error;
        BOOL success = [exportString writeToFile:filePath
                                     atomically:YES
                                       encoding:NSUTF8StringEncoding
                                          error:&error];
        if (success) {
            NSLog(@"Successfully saved chat to %@", filePath);
        } else {
            NSLog(@"Failed to save chat: %@", [error localizedDescription]);
        }
    }
}

- (void)saveDocument:(id)sender {
    [self saveChat:sender];
}

- (IBAction)sendMessage:(id)sender {
    if (sender == proxyServer) return;

    NSString *message = [userMessageField stringValue];
    if ([message length] == 0) return;
    
	[userMessageField setStringValue:@""];
    
    // Add to internal history
    [chatHistory addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"user", @"role", message, @"content", nil]];

    // Update UI (WebView)
    if (webView) {
        [self appendMessageToWebView:message isUser:YES];
    } else {
        // Fallback to old text view if WebView failed to load
        NSMutableString *messageForChat = [NSMutableString stringWithString:@"User: "];
        [messageForChat appendString:message];
        [messageForChat appendString:@"\r\n\r\n"];
        [[chatLog textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:messageForChat] autorelease]];
        [chatLog scrollRangeToVisible:NSMakeRange([[chatLog string] length], 0)];
    }

    [self sendRequestToOpenAIWithMessage:message];
}

- (void)sendRequestToOpenAIWithMessage:(NSString *)message {
    NSString *proxyValue = [proxyServer stringValue];

    if (proxyValue == nil || [proxyValue isEqualToString:@""]) {
        proxyValue = nil;
        NSArray *addresses = [[NSHost currentHost] addresses];
        NSEnumerator *e = [addresses objectEnumerator];
        NSString *anAddress;
        while (anAddress = [e nextObject]) {
			NSLog(anAddress);
            if (![anAddress hasPrefix:@"127"] && [[anAddress componentsSeparatedByString:@"."] count] == 4) {
                proxyValue = [NSString stringWithFormat:@"%@:8080", anAddress];
				[proxyServer setStringValue:proxyValue];
                break;
            }
        }
        if (proxyValue == nil) {
            [proxyServer setStringValue:@"Please enter a value!"];
            return;
        }
    }

    NSString *urlString = [NSString stringWithFormat:@"http://%@/v1/chat/completions", proxyValue];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlString]];

    NSString *messagesString = [self constructJSONHistory];
    
    [request setHTTPBody:[messagesString dataUsingEncoding:NSUTF8StringEncoding]];
    [request setHTTPMethod:@"POST"];
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    
    NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    if (!connection) {
		[proxyServer setStringValue:@"Error! Check Connecton!"];
    }
}

- (NSString *)escapeJSONString:(NSString *)input {
    NSMutableString *s = [NSMutableString stringWithString:input];
    [s replaceOccurrencesOfString:@"\\" withString:@"\\\\
" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\"" withString:@"\\\"" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\r" withString:@"\\r" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\n" withString:@"\\n" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    [s replaceOccurrencesOfString:@"\t" withString:@"\\t" options:NSLiteralSearch range:NSMakeRange(0, [s length])];
    return s;
}

- (NSString *)constructJSONHistory {
    NSMutableString *jsonMessages = [NSMutableString stringWithString:@"["];
    
    NSEnumerator *e = [chatHistory objectEnumerator];
    NSDictionary *item;
    while (item = [e nextObject]) {
        NSString *role = [item objectForKey:@"role"];
        NSString *content = [item objectForKey:@"content"];
        [jsonMessages appendFormat:@"{\"role\":\"%@\",\"content\":\"%@\"},", role, [self escapeJSONString:content]];
    }
    
    if ([jsonMessages hasSuffix:@","]) {
        [jsonMessages deleteCharactersInRange:NSMakeRange([jsonMessages length]-1, 1)];
    }
    
    [jsonMessages appendString:@"]"];
    return jsonMessages;
}

#pragma mark - NSURLConnection delegate methods

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    if (data) {
        NSString *responseString = [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease];
        NSLog(responseString);
        
        // Add to history
        [chatHistory addObject:[NSDictionary dictionaryWithObjectsAndKeys:@"assistant", @"role", responseString, @"content", nil]];
        
        // Update UI
        if (webView) {
            [self appendMessageToWebView:responseString isUser:NO];
        } else {
            NSMutableString *messageForChat = [NSMutableString stringWithString:@"ChatGPT: "];
            [messageForChat appendString:responseString];
            [messageForChat appendString:@"\r\n\r\n"];
            [[chatLog textStorage] appendAttributedString:[[[NSAttributedString alloc] initWithString:messageForChat] autorelease]];
            [chatLog scrollRangeToVisible:NSMakeRange([[chatLog string] length], 0)];
        }

        // Speech
        if (synthesizer) {
            [synthesizer startSpeakingString:responseString];
        }
        
    } else {
        NSLog(@"No data received.");
    }
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Connection failed with error: %@", [error localizedDescription]);
    [proxyServer setStringValue:@"Connection Failed"];
}

- (void)dealloc {
    [chatHistory release];
    [synthesizer release];
    if (webView) [webView release];
    [super dealloc];
}

@end
