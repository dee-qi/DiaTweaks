#import "Localization.h"
#import "Catalog.inc"

static NSString *DPLanguage;
static NSDictionary *DPCatalog, *DPIndex;
static NSArray *DPPatterns;

static NSArray *DPLanguageList;
static void DPLoadCatalog(void);
NSArray<NSDictionary *> *DPSupportedLanguages(void) { DPLoadCatalog(); return DPLanguageList; }
NSDictionary *DPLanguageInfo(NSString *locale) {
    for (NSDictionary *language in DPSupportedLanguages()) if ([language[@"id"] isEqual:locale]) return language;
    return DPSupportedLanguages().firstObject;
}
NSString *DPLocaleResolve(NSString *choice, NSArray<NSString *> *preferred) {
    if ([DPLanguageInfo(choice)[@"id"] isEqual:choice]) return choice;
    for (NSString *language in preferred) {
        NSString *tag = [[language stringByReplacingOccurrencesOfString:@"_" withString:@"-"] lowercaseString];
        for (NSDictionary *supported in DPSupportedLanguages())
            for (NSString *match in supported[@"matches"]) {
                NSString *prefix = match.lowercaseString;
                // Bare zh must not claim zh-Hant/TW/HK.
                if ([tag isEqual:prefix] || (![prefix isEqual:@"zh"] && [tag hasPrefix:[prefix stringByAppendingString:@"-"]])) return supported[@"id"];
            }
    }
    return @"en";
}

NSString *DPLocale(void) {
    if (!DPLanguage) {
        NSUserDefaults *prefs = [[NSUserDefaults alloc] initWithSuiteName:@(getenv("DIATWEAKS_DOMAIN") ?: "com.diapatches")];
        // Read the global domain, not the app override installed below.
        NSArray *languages = [NSUserDefaults.standardUserDefaults persistentDomainForName:NSGlobalDomain][@"AppleLanguages"];
        DPLanguage = DPLocaleResolve([prefs stringForKey:@"interfaceLanguage"], languages ?: NSLocale.preferredLanguages);
    }
    return DPLanguage;
}

static void DPLoadCatalog(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        NSData *data = [NSData dataWithBytes:DPCatalogBytes length:sizeof DPCatalogBytes];
        NSDictionary *resource = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        DPCatalog = resource[@"messages"];
        DPLanguageList = resource[@"languages"];
        NSMutableDictionary *index = [NSMutableDictionary new];
        NSMutableArray *patterns = [NSMutableArray new];
        for (NSString *key in DPCatalog) {
            NSDictionary *entry = DPCatalog[key];
            if (entry[@"pattern"]) {
                NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:entry[@"pattern"] options:0 error:nil];
                if (regex) [patterns addObject:@{@"entry":entry, @"regex":regex}];
            }
            for (NSString *context in entry[@"contexts"]) index[[NSString stringWithFormat:@"%@\n%@", context, entry[@"en"]]] = entry;
        }
        DPIndex = index;
        DPPatterns = patterns;
    });
}

NSString *DPLocalized(NSString *key, NSString *fallback) {
    if ([DPLocale() isEqual:@"en"]) return fallback;
    DPLoadCatalog();
    return DPCatalog[key][DPLocale()] ?: fallback;
}

NSString *DPLocalize(NSString *source, NSString *context) {
    if (!source.length || [DPLocale() isEqual:@"en"]) return source;
    DPLoadCatalog();
    NSString *exact = DPIndex[[NSString stringWithFormat:@"%@\n%@", context, source]][DPLocale()];
    if (exact) return exact;
    for (NSDictionary *rule in DPPatterns) {
        NSDictionary *entry = rule[@"entry"];
        if (![entry[@"contexts"] containsObject:context] || ![source hasPrefix:entry[@"prefix"]] || !entry[DPLocale()]) continue;
        NSTextCheckingResult *match = [rule[@"regex"] firstMatchInString:source options:0 range:NSMakeRange(0, source.length)];
        if (!match) continue;
        NSMutableString *result = [entry[DPLocale()] mutableCopy];
        NSRegularExpression *slots = [NSRegularExpression regularExpressionWithPattern:@"%([0-9]+)\\$@" options:0 error:nil];
        NSArray *tokens = [slots matchesInString:result options:0 range:NSMakeRange(0, result.length)];
        for (NSTextCheckingResult *token in tokens.reverseObjectEnumerator) {
            NSUInteger index = [[result substringWithRange:[token rangeAtIndex:1]] integerValue];
            if (index >= match.numberOfRanges) return source;
            [result replaceCharactersInRange:token.range withString:[source substringWithRange:[match rangeAtIndex:index]]];
        }
        return result;
    }
    return source;
}

BOOL DPTextMatches(NSString *text, NSString *source) {
    if ([text isEqual:source]) return YES;
    for (NSString *context in @[@"menu", @"settings", @"chrome", @"tweaks"])
        if ([text isEqual:DPLocalize(source, context)]) return YES;
    return NO;
}
