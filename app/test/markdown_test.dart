import 'package:flutter_test/flutter_test.dart';
import 'package:lumi/l10n/gen/app_localizations.dart';
import 'package:lumi/theme/app_theme.dart';
import 'package:lumi/widgets/markdown_view.dart';
import 'package:material_ui/material_ui.dart';

const answer = '''
## Landing page

Pakai **HTML** dan `Tailwind`, lalu:

1. Hero
2. Features

| Bagian | Isi |
|---|---|
| Hero | Judul dan tombol |
| Footer | Kontak |

```html
<section class="hero">Halo</section>
```
''';

void main() {
  setUpAll(() => AppFonts.useGoogleFonts = false);

  testWidgets('renders headings, lists, tables and code blocks without layout errors', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        localizationsDelegates: const [AppLocalizations.delegate, ...GlobalMaterialLocalizations.delegates],
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(child: SizedBox(width: 320, child: MarkdownView(data: answer))),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('Landing page'), findsOneWidget);
    expect(find.byType(Table), findsOneWidget);
    expect(find.text('<section class="hero">Halo</section>'), findsOneWidget);
    expect(find.text('html'), findsOneWidget); // code block language label
    expect(find.textContaining('**'), findsNothing); // bold markers are rendered, not shown
  });
}
