#import "Localization.h"
#import "Catalog.inc"

static uint16_t DPRead16(const uint8_t *bytes) { uint16_t value; memcpy(&value, bytes, 2); return CFSwapInt16LittleToHost(value); }
static uint32_t DPRead32(const uint8_t *bytes) { uint32_t value; memcpy(&value, bytes, 4); return CFSwapInt32LittleToHost(value); }
static void DPWrite32(uint8_t *bytes, uint32_t value) { value = CFSwapInt32HostToLittle(value); memcpy(bytes, &value, 4); }

// Chromium DataPack v5: preserve IDs, aliases, encoding and untouched resource bytes.
NSData *DPTranslateLocalePack(NSData *data, NSDictionary<NSString *, NSString *> *translations) {
    const uint8_t *bytes = data.bytes;
    if (data.length < 12 || DPRead32(bytes) != 5 || (bytes[4] != 1 && bytes[4] != 2)) return nil;
    NSUInteger count = DPRead16(bytes + 8), aliases = DPRead16(bytes + 10);
    NSUInteger header = 12 + (count + 1) * 6 + aliases * 4;
    if (data.length < header || data.length > UINT32_MAX) return nil;
    for (NSUInteger i = 0; i < aliases; i++) if (DPRead16(bytes + 12 + (count + 1) * 6 + i * 4 + 2) >= count) return nil;
    NSStringEncoding encoding = bytes[4] == 1 ? NSUTF8StringEncoding : NSUTF16LittleEndianStringEncoding;
    NSMutableData *out = [[data subdataWithRange:NSMakeRange(0, header)] mutableCopy];
    for (NSUInteger i = 0; i < count; i++) {
        uint32_t start = DPRead32(bytes + 12 + i * 6 + 2), end = DPRead32(bytes + 12 + (i + 1) * 6 + 2);
        if (start < header || end < start || end > data.length) return nil;
        NSData *original = [data subdataWithRange:NSMakeRange(start, end - start)];
        NSString *source = [[NSString alloc] initWithData:original encoding:encoding];
        NSData *replacement = source ? [translations[source] dataUsingEncoding:encoding] : nil;
        if (out.length + (replacement ?: original).length > UINT32_MAX) return nil;
        DPWrite32((uint8_t *)out.mutableBytes + 12 + i * 6 + 2, (uint32_t)out.length);
        [out appendData:replacement ?: original];
    }
    DPWrite32((uint8_t *)out.mutableBytes + 12 + count * 6 + 2, (uint32_t)out.length);
    return out;
}

// Only the dedicated onboarding renderer's title/subtitle fields are adapted.
// No DOM scanning, response text replacement, or user-content interception.
NSString *DPTranslateChatHints(NSString *script, NSDictionary *translations) {
    if ([script containsString:@"const __dpHintText="]) return script;
    if (![script containsString:@"--hint-image-width"] || ![script containsString:@"t.hint.subtitle"]) return script;
    if ([script componentsSeparatedByString:@"t.hint.title"].count != 3
        || [script componentsSeparatedByString:@"t.hint.subtitle"].count != 2) return script;
    NSData *json = [NSJSONSerialization dataWithJSONObject:translations options:NSJSONWritingSortedKeys error:nil];
    if (!json) return script;
    NSString *map = [[NSString alloc] initWithData:json encoding:NSUTF8StringEncoding];
    NSString *prefix = [NSString stringWithFormat:@"const __dpHintText=(s)=>(%@)[navigator.language.toLowerCase()]?.[s]??s;\n", map];
    NSString *result = [script stringByReplacingOccurrencesOfString:@"t.hint.title" withString:@"__dpHintText(t.hint.title)"];
    result = [result stringByReplacingOccurrencesOfString:@"t.hint.subtitle" withString:@"__dpHintText(t.hint.subtitle)"];
    return [prefix stringByAppendingString:result];
}

static BOOL DPPrepareChatHints(NSString *app, NSDictionary *resource) {
    NSMutableDictionary *maps = [NSMutableDictionary new];
    for (NSDictionary *language in resource[@"languages"]) {
        NSMutableDictionary *strings = [NSMutableDictionary new];
        for (NSDictionary *entry in [resource[@"messages"] allValues])
            if ([entry[@"contexts"] containsObject:@"chat-hint"] && entry[language[@"id"]]) strings[entry[@"en"]] = entry[language[@"id"]];
        maps[[language[@"chromium"] lowercaseString]] = strings;
    }
    NSString *root = [app stringByAppendingPathComponent:@"Contents/Resources/web-chat-resources/dist/app/immutable/nodes"];
    BOOL matched = NO;
    for (NSString *name in [NSFileManager.defaultManager contentsOfDirectoryAtPath:root error:nil]) {
        if (![name.pathExtension isEqual:@"js"]) continue;
        NSString *path = [root stringByAppendingPathComponent:name];
        NSString *source = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
        if (!source) continue;
        NSString *result = DPTranslateChatHints(source, maps);
        if (![result isEqual:source]) {
            matched = YES;
            if (![result writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil]) return NO;
        } else if ([source containsString:@"const __dpHintText="]) matched = YES;
    }
    if (!matched) fprintf(stderr, "warning: unsupported chat hint renderer; kept original resources\n");
    return YES;
}

BOOL DPPrepareLocalization(NSString *app) {
    NSDictionary *resource = [NSJSONSerialization JSONObjectWithData:[NSData dataWithBytes:DPCatalogBytes length:sizeof DPCatalogBytes] options:0 error:nil];
    NSString *infoPath = [app stringByAppendingPathComponent:@"Contents/Info.plist"];
    NSMutableDictionary *info = [[NSDictionary dictionaryWithContentsOfFile:infoPath] mutableCopy];
    NSMutableOrderedSet *languages = [NSMutableOrderedSet orderedSetWithArray:info[@"CFBundleLocalizations"] ?: @[@"en"]];
    for (NSDictionary *language in resource[@"languages"]) {
        NSString *locale = language[@"id"];
        [languages addObject:language[@"cocoa"]];
        if ([locale isEqual:@"en"]) continue;
        NSMutableDictionary *translations = [NSMutableDictionary new];
        for (NSDictionary *entry in [resource[@"messages"] allValues])
            if ([entry[@"contexts"] containsObject:@"chromium-resource"] && entry[locale]) translations[entry[@"en"]] = entry[locale];
        if (!translations.count) continue;
        NSString *relative = [NSString stringWithFormat:@"Contents/Frameworks/ArcCore.framework/Resources/%@.lproj/locale.pak", language[@"cocoa"]];
        NSString *path = [app stringByAppendingPathComponent:relative];
        NSData *data = [NSData dataWithContentsOfFile:path];
        if (!data) continue; // A future version may move the pack; native localization still works.
        NSData *localized = DPTranslateLocalePack(data, translations);
        if (!localized) { fprintf(stderr, "warning: unsupported Chromium language pack; kept its original resources\n"); continue; }
        if (![localized isEqual:data] && ![localized writeToFile:path options:NSDataWritingAtomic error:nil]) return NO;
    }
    if (!DPPrepareChatHints(app, resource)) return NO;
    info[@"CFBundleLocalizations"] = languages.array;
    return [info writeToFile:infoPath atomically:YES];
}
