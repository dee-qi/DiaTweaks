# Localization

DiaTweaks provides Follow System, English and Simplified Chinese under Settings → Home → Interface Language. Restart Dia after changing the choice. The preference is `interfaceLanguage` in `com.diapatches` (`system`, `en`, `zh-Hans`). An unset preference means Follow System. Unsupported system languages fall back to English; Traditional Chinese is not silently treated as Simplified Chinese.

## Resource model

`locales/languages.json` registers each language's native name, matching language tags, Cocoa/Chromium locale and preferred website languages. Files under `locales/<language>/` contain stable message IDs, the original English text, translated text and allowed contexts. `interface.json` holds native UI, `patches.json` holds tweak metadata, and `chromium.json` holds Dia-specific strings missing from Chromium's translated resource pack.

To add a language:

1. Register its metadata, ensuring the Cocoa locale matches the installed ArcCore language pack when one is available.
2. Add catalog files with the same message IDs, English sources and contexts. Translate placeholders without changing their types, order or spelling.
3. Run `scripts/build-localizations --check`, `make check`, and both live test layouts. Inspect menus, settings, popovers, and longer labels in the new language.

The generator rejects duplicate IDs, contradictory translations in the same context, empty translations and changed printf/Chromium placeholders. It embeds a deterministic catalog in both the dylib and installer; no runtime network translation or external resource-directory dependency is involved. Missing translations return the original English.

## Integration

- `Catalog.m` resolves the process language once and provides ID-based and contextual source lookup. Original tweak keys, manifest data and Wiki URLs remain English/stable; settings search includes both English and translated metadata.
- `Runtime.m` uses an in-process volatile AppleLanguages override and the existing Chromium configuration hook for `--lang` and `--accept-lang`. It constrains the main bundle's preferred localization to the selected language. No global or persistent browser language preference is rewritten; uninstalling the patch removes these overrides.
- The installer advertises the registered bundle languages before signing. It patches only exact catalog matches in existing Chromium DataPack v5 resources, preserving resource IDs, aliases, encoding and unrelated bytes. It operates on the staged copy, never the pristine backup. Unknown pack formats keep their original contents with a diagnostic.
- `Native.m` translates native menus and non-editable controls in preferences, sheets and selected known browser controls. It skips web-content views and editable text. It retains source text per object/property so existing menu lookup and label-dependent patches can still use English identifiers. Dropdown item values, menu actions and shortcuts are preserved.
- Owned DiaTweaks controls and alerts call localization explicitly. Translation does not rewrite user input, URLs, page content or AI output. Chrome Web Store's UI uses the preferred website languages; extension names and publisher descriptions remain the publisher's content.

## Verification and recovery

`make check` includes locale negotiation, fallback/context isolation, idempotence, menu source lookup, dropdown option count and represented values, editable-field preservation, and DataPack offset/alias/corruption tests. Existing tweak checks remain part of the suite. `make test` runs the live patch combinations; repeat with sidebar tabs and top tabs.

`DIATWEAKS_DOMAIN` isolates catalog preferences in tests. Native tests use a temporary preference domain and remove it afterward. Source installations preserve an existing Rust CLI when Rust is unavailable.

To return to English, select English and restart. To remove localization along with all patches, use DiaTweaks' existing Restore flow. Before the first local installation for this change, the installed dylib, installer, release metadata and preference export were saved under `~/Library/Application Support/DiaPatches/backups/pre-localization/`.

This is an unofficial adaptation of Dia 1.57.1. New Dia wording, new screens or custom-rendered controls require catalog/adapter updates. A failed live check or an unvisited conditional screen must be reported separately from verified coverage.

### Dynamic native surfaces

Library filters/section headers, the sidebar Chats entry, and the recent-tab menu use explicit native-class scopes. Search fields translate their attributed placeholder while preserving its styling and entered text. Library item titles and recent-tab titles remain outside this scope. Dynamically reset `NSMenuItem` titles are translated on assignment; original-title lookup remains available to existing patches, including Group Tabs by Domain.

Set `localizationDiagnostics` in `com.diapatches` to enable compatibility diagnostics on the next launch. Diagnostics contain only native class/property/context identifiers, never the actual text, URLs, account values, or page contents.

### Bookmarks, split targets, and linked descriptions

The native bookmarks manager lives inside a WebContents container. Traversal therefore reaches that container's native controls, while RenderWidget/WKWebView contents remain excluded. Bookmark name/address cells are excluded from general translation; only a complete numeric item-count label in the address/count cell is formatted. Column headers, the native page title, and toolbar controls use the catalog. The built-in bookmark tab is distinguished from web tabs by its native split action and absence of pin/unpin actions; arbitrary web-page titles are not localized.

DragDrop SplitTargetView labels use their own class scope. Attributed menu titles are localized as well as plain titles. Linked descriptions translate attribute runs separately, retaining the link target and keeping the surrounding sentence outside the link. Tests cover both split directions, item counts, user bookmark titles, attributed menus, and link attributes.

### Translation before display

Native localization no longer uses `NSWindowDidUpdateNotification`. Scoped label/button/placeholder assignments are translated before the original setter receives them. A `viewWillDraw` hook translates only the current native control immediately before drawing; AppKit owns traversal and scheduling. It does not recursively scan the window or newly attached subtrees. Menu title setters remain synchronous and language changes still require a restart.

The initial pre-display prototype recursively scanned at `addSubview` and `NSWindow.display` / `displayIfNeeded`. It caused severe stalls during rapid settings navigation and was removed. Do not reintroduce whole-tree scans into these hot paths.

Scope restrictions and editable-content exclusions also apply to the setter and draw hooks. A popup button's title is never assigned by the generic button hook. Tests assert translated values immediately after the pre-draw callback and assignments, without pumping the run loop or relying on a post-paint notification; out-of-scope labels and editable user text retain their original contents. Turn Off AI reads preserved source labels when identifying settings rows.

### Language setting placement

The first section in Patches is Language / 语言, containing Language Patch / 语言补丁. The selector retains Follow System, 简体中文 and English and stores the same `interfaceLanguage` preference. The overview search indexes both English and localized labels. Home no longer contains a duplicate selector.

### Navigation hover cards (Dia 1.57.1, build 90935)

Visible hover labels are verbatim SwiftUI.Text values inside DiaTooltip, not AppKit labels or bundle-localized resources. The earlier reflected-model overlay was unreliable when Dia reused a tooltip; it has been removed, including its window-order hook, tree walk and pre-draw adaptation.

`TooltipImport.m` rebinds only Dia's import of `$s7SwiftUI4TextVyACxcSyRzlufC`. It requires arm64 UUID `0EA785D3-F313-3D02-A86F-3A1C7BE15996`, verifies all seven recorded BL instructions target the expected Text initializer stub, and verifies the import pointer equals the resolved original function. It restores the data page's original protection after replacement. Unsupported binaries skip this adapter and retain original text.

The trampoline checks the return address against the seven DiaTooltip constructors. `Tooltip.swift` additionally checks that the generic metadata is exactly Swift.String, looks up an exact `tooltip` catalog entry, and replaces only the initializer's owned argument. It then tail-calls the original initializer. SwiftUI continues to render the label, appearance, layout and shortcut keycaps; there is no overlay, reflection, display hook or periodic scan for these hover cards. Unknown text, other StringProtocol types, English mode, and calls outside DiaTooltip remain unchanged.

To support a new Dia build, independently identify its tooltip constructors and import slot, record its UUID, and verify the call instructions and Swift ABI before adding an adapter. Do not reuse offsets from build 90312 or remove UUID validation. Translation additions belong in the language catalog, not in the binary adapter.

`make check-localization-tooltip` exercises the actual SwiftUI initializer with 14,000 repeated translations and alternates translated and excluded calls. It checks that caller-owned strings remain unchanged and verifies unknown-string and Substring fallback. Physical hover reuse and shortcut rendering still require live UI verification; an ABI test alone is not a visual pass.

### New-tab welcome UI

Welcome strings use the `newtab` context at main-bundle lookup, plus narrowly scoped native fallback for NewTabPage.ConnectAppsUpsellView / ConnectAppRowView. The command-bar placeholder getter permits its exact `commandBarTextField` identifier, without translating editable text. TurnOffAI explicitly localizes its replacement placeholder because its hook runs after the localization getter. Welcome headings use balanced line breaks; footnote translations fit the existing layout and retain the original link attributes/actions. Promotional illustration pixels are not rewritten.

### Shortcut descriptions and conflict menu

`shortcuts.json` contains the individually enumerated shortcut descriptions and conflict-policy menu text. Exact `shortcut` resource lookups translate descriptions before their views are constructed, with the scoped settings adapter as fallback. Original actions and key bindings are untouched by the implementation. `docs/localization-shortcuts-90935.json` records 55 physically clicked, currently reachable items before and after installation. Profile 2–9 descriptions are catalogued but not live verified because only Profile 1 exists locally. Five AI-related rows hidden by TurnOffAI are excluded from the 55-item coverage claim.
