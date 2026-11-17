#import "Localization.h"
#import "StdPatch/StdPatch.h"
#import "SafeMode/SafeMode.h"

static NSArray *DPBundle_languages(NSBundle *self, SEL _cmd) {
    if ([self.bundleIdentifier isEqual:@"company.thebrowser.dia"]) return @[DPLanguageInfo(DPLocale())[@"cocoa"]];
    return DPCallOriginal(DPBundle_languages, self);
}

void DPInstallLocalization(void) {
    if (DPSafeMode) return;
    NSDictionary *language = DPLanguageInfo(DPLocale());
    // Volatile only: original persistent app/global preferences survive restore/uninstall.
    NSMutableDictionary *arguments = [[NSUserDefaults.standardUserDefaults volatileDomainForName:NSArgumentDomain] mutableCopy];
    arguments[@"AppleLanguages"] = @[language[@"cocoa"], @"en"];
    [NSUserDefaults.standardUserDefaults setVolatileDomain:arguments forName:NSArgumentDomain];
    DPAddLaunchFlag([@"--lang=" stringByAppendingString:language[@"chromium"]]);
    DPAddLaunchFlag([@"--accept-lang=" stringByAppendingString:language[@"accept"]]);
    DPHookClass(NSBundle.class, @selector(preferredLocalizations), (IMP)DPBundle_languages);
    DPInstallLocalizedUI();
}
