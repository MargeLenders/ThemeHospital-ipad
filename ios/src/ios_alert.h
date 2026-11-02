/*
  CorsixTH iOS Native Alert Dialog
  Provides native text input modal alerts (UIAlertController) for iPadOS/iOS.
*/

#ifndef CORSIX_TH_IOS_ALERT_H
#define CORSIX_TH_IOS_ALERT_H

#include <string>

bool ios_has_native_text_input();

bool ios_show_text_input_prompt(const char* title,
                                const char* message,
                                const char* default_text,
                                const char* ok_text,
                                const char* cancel_text,
                                std::string& out_result);

#endif // CORSIX_TH_IOS_ALERT_H
