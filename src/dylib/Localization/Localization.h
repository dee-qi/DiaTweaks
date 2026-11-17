#import <AppKit/AppKit.h>
NSString *DPLocaleResolve(NSString *choice, NSArray<NSString *> *preferred);
NSString *DPLocale(void);
NSString *DPLocalize(NSString *source, NSString *context);
NSString *DPLocalized(NSString *key, NSString *fallback);
NSString *DPOriginalText(id object, NSString *property, NSString *current);
BOOL DPTextMatches(NSString *text, NSString *source);
void DPInstallLocalization(void);
void DPInstallLocalizedUI(void);
NSView *DPLanguageRow(void);
NSArray<NSDictionary *> *DPSupportedLanguages(void);
NSDictionary *DPLanguageInfo(NSString *locale);
