/*
  CorsixTH iOS Native Alert Dialog
  Implementation of UIAlertController with text field for iPadOS/iOS.
*/

#include "ios_alert.h"

#import <UIKit/UIKit.h>

bool ios_has_native_text_input() {
    return true;
}

@interface CorsixTHAlertTarget : NSObject
@property (nonatomic, copy) void (^onReturnBlock)(void);
- (void)onEditingDidEndOnExit:(UITextField *)sender;
@end

@implementation CorsixTHAlertTarget
- (void)onEditingDidEndOnExit:(UITextField *)sender {
    if (self.onReturnBlock) {
        self.onReturnBlock();
    }
}
@end

static UIViewController* get_top_view_controller() {
    UIViewController *topController = nil;
    if (@available(iOS 13.0, *)) {
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (scene.activationState == UISceneActivationStateForegroundActive &&
                [scene isKindOfClass:[UIWindowScene class]]) {
                UIWindowScene *windowScene = (UIWindowScene *)scene;
                for (UIWindow *w in windowScene.windows) {
                    if (w.rootViewController) {
                        topController = w.rootViewController;
                        if (w.isKeyWindow) {
                            break;
                        }
                    }
                }
                if (topController) {
                    break;
                }
            }
        }
    }
    if (!topController) {
        for (UIWindow *w in UIApplication.sharedApplication.windows) {
            if (w.rootViewController) {
                topController = w.rootViewController;
                if (w.isKeyWindow) {
                    break;
                }
            }
        }
    }
    while (topController.presentedViewController) {
        topController = topController.presentedViewController;
    }
    return topController;
}

static NSString* clean_string(const char* cstr) {
    if (!cstr) return @"";
    NSString *s = [NSString stringWithUTF8String:cstr];
    NSString *prefix = @"<LocalisedString> Current value:";
    if ([s hasPrefix:prefix]) {
        s = [s substringFromIndex:[prefix length]];
    }
    return s;
}

static bool ios_show_text_input_prompt_main_thread(const char* title,
                                                   const char* message,
                                                   const char* default_text,
                                                   const char* ok_text,
                                                   const char* cancel_text,
                                                   std::string& out_result) {
    @autoreleasepool {
        UIViewController *topController = get_top_view_controller();
        if (!topController) {
            return false;
        }

        NSString *nsTitle = clean_string(title);
        NSString *nsMessage = clean_string(message);
        NSString *nsDefault = clean_string(default_text);
        NSString *nsOk = (ok_text && ok_text[0]) ? clean_string(ok_text) : @"Guardar";
        NSString *nsCancel = (cancel_text && cancel_text[0]) ? clean_string(cancel_text) : @"Cancelar";

        UIAlertController *alert = [UIAlertController alertControllerWithTitle:nsTitle
                                                                       message:nsMessage
                                                                preferredStyle:UIAlertControllerStyleAlert];

        CorsixTHAlertTarget *targetHelper = [[CorsixTHAlertTarget alloc] init];

        [alert addTextFieldWithConfigurationHandler:^(UITextField *textField) {
            if (nsDefault.length > 0) {
                textField.text = nsDefault;
                textField.selectedTextRange = [textField textRangeFromPosition:textField.endOfDocument
                                                                    toPosition:textField.endOfDocument];
            }
            textField.placeholder = (nsTitle.length > 0) ? nsTitle : nsMessage;
            textField.clearButtonMode = UITextFieldViewModeWhileEditing;
            textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
            textField.autocorrectionType = UITextAutocorrectionTypeDefault;
            textField.returnKeyType = UIReturnKeyDone;

            [textField addTarget:targetHelper
                          action:@selector(onEditingDidEndOnExit:)
                forControlEvents:UIControlEventEditingDidEndOnExit];
        }];

        __block BOOL finished = NO;
        __block BOOL confirmed = NO;
        __block NSString *resultText = nil;

        UIAlertAction *cancelAction = [UIAlertAction actionWithTitle:nsCancel
                                                               style:UIAlertActionStyleCancel
                                                             handler:^(UIAlertAction *action) {
            finished = YES;
        }];

        UIAlertAction *okAction = [UIAlertAction actionWithTitle:nsOk
                                                           style:UIAlertActionStyleDefault
                                                         handler:^(UIAlertAction *action) {
            UITextField *tf = alert.textFields.firstObject;
            if (tf && tf.text) {
                resultText = [tf.text copy];
            }
            confirmed = YES;
            finished = YES;
        }];

        targetHelper.onReturnBlock = ^{
            UITextField *tf = alert.textFields.firstObject;
            if (tf && tf.text) {
                resultText = [tf.text copy];
            }
            confirmed = YES;
            finished = YES;
            [alert dismissViewControllerAnimated:YES completion:nil];
        };

        [alert addAction:cancelAction];
        [alert addAction:okAction];
        alert.preferredAction = okAction;

        [topController presentViewController:alert animated:YES completion:nil];

        while (!finished) {
            [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                     beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
        }

        if (confirmed && resultText) {
            out_result = [resultText UTF8String];
            return true;
        }
        return false;
    }
}

bool ios_show_text_input_prompt(const char* title,
                                const char* message,
                                const char* default_text,
                                const char* ok_text,
                                const char* cancel_text,
                                std::string& out_result) {
    if (![NSThread isMainThread]) {
        __block bool success = false;
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        dispatch_async(dispatch_get_main_queue(), ^{
            success = ios_show_text_input_prompt_main_thread(title, message, default_text, ok_text, cancel_text, out_result);
            dispatch_semaphore_signal(sema);
        });
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
        return success;
    }

    return ios_show_text_input_prompt_main_thread(title, message, default_text, ok_text, cancel_text, out_result);
}
