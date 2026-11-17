#import "Localization/Localization.h"
#include <assert.h>
int main(void) { @autoreleasepool {
    assert([DPLocaleResolve(@"system", @[@"zh-Hans-CN"]) isEqual:@"zh-Hans"]);
    assert([DPLocaleResolve(@"system", @[@"zh_CN"]) isEqual:@"zh-Hans"]);
    assert([DPLocaleResolve(@"system", @[@"zh-SG"]) isEqual:@"zh-Hans"]);
    assert([DPLocaleResolve(@"system", @[@"zh-Hant-TW", @"en-US"]) isEqual:@"en"]);
    assert([DPLocaleResolve(@"en", @[@"zh-CN"]) isEqual:@"en"]);
    assert([DPLocaleResolve(@"zh-Hans", @[@"en-US"]) isEqual:@"zh-Hans"]);
    assert([DPLocaleResolve(@"bad", @[@"de-DE"]) isEqual:@"en"]);
    assert([DPLocaleResolve(nil, @[]) isEqual:@"en"]);
    assert([DPLocalize(@"A user supplied title", @"settings") isEqual:@"A user supplied title"]);
    assert([DPLocalized(@"missing.key", @"fallback") isEqual:@"fallback"]);
    assert([DPLocalize(@"New Tab", @"website") isEqual:@"New Tab"]);
    NSString *translated = DPLocalize(@"New Tab", @"menu");
    assert(DPTextMatches(translated, @"New Tab"));
    assert([DPLocalize(translated, @"menu") isEqual:translated]);
    assert([DPLanguageInfo(@"zh-Hans")[@"accept"] isEqual:@"zh-CN,zh,en-US,en"]);
    puts("localization: locale negotiation, context, fallback, idempotence and source matching passed");
} }
