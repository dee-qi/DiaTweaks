#import "Native.h"

static char DPSourceKey;
BOOL DPTranslating, DPDiagnostics;

NSString *DPOriginalText(id object, NSString *property, NSString *current) {
    NSDictionary *record = DPGet(object, &DPSourceKey)[property];
    return [record[@"shown"] isEqual:current] ? record[@"source"] : current;
}

NSString *DPTranslate(id object, NSString *property, NSString *text, NSString *context) {
    NSString *source = DPOriginalText(object, property, text);
    NSString *shown = DPLocalize(source, context);
    if ([shown isEqual:source] && source.length && DPDiagnostics) {
        // Never log text: even native settings can contain account names or user titles.
        static NSMutableSet *reported;
        if (!reported) reported = [NSMutableSet new];
        NSString *site = [NSString stringWithFormat:@"%@.%@ (%@)", NSStringFromClass([object class]), property, context];
        if (![reported containsObject:site]) { [reported addObject:site]; NSLog(@"DiaTweaks localization: untranslated text at %@", site); }
    }
    NSMutableDictionary *records = DPGet(object, &DPSourceKey);
    if (!records) DPSet(object, &DPSourceKey, records = [NSMutableDictionary new]);
    records[property] = @{@"source": source ?: @"", @"shown": shown ?: @""};
    return shown;
}

// Translate linked runs separately so the link remains on its own translated label.
NSAttributedString *DPRichTranslation(NSAttributedString *source, NSString *context) {
    if (!source.length) return source;
    __block BOOL linked = NO;
    [source enumerateAttribute:NSLinkAttributeName inRange:NSMakeRange(0, source.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) { if (value) linked = YES; }];
    NSMutableAttributedString *result = [source mutableCopy];
    if (!linked) {
        NSString *shown = DPLocalize(source.string, context);
        if (![shown isEqual:source.string]) [result replaceCharactersInRange:NSMakeRange(0, result.length) withString:shown];
        return result;
    }
    [source enumerateAttributesInRange:NSMakeRange(0, source.length) options:NSAttributedStringEnumerationReverse usingBlock:^(NSDictionary *attrs, NSRange range, BOOL *stop) {
        NSString *part = [source.string substringWithRange:range];
        NSRange core = [part rangeOfString:[part stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet]];
        if (!core.length) return;
        NSString *original = [part substringWithRange:core], *shown = DPLocalize(original, context);
        if (![shown isEqual:original]) [result replaceCharactersInRange:NSMakeRange(range.location + core.location, core.length) withString:shown];
    }];
    return result;
}

