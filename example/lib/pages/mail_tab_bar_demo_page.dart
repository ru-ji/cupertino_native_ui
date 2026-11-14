import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:cupertino_ui/cupertino_ui.dart';

/// A small Mail client: an inbox with a standalone [CupertinoNativeTabBar]
/// next to a round compose button, a message screen and a compose screen,
/// all with floating Liquid Glass chrome.
class MailTabBarDemoPage extends StatefulWidget {
  const MailTabBarDemoPage({super.key});

  @override
  State<MailTabBarDemoPage> createState() => _MailTabBarDemoPageState();
}

class _Mail {
  const _Mail(
    this.sender,
    this.time,
    this.preview,
    this.avatar, {
    this.invite = false,
  });
  final String sender;
  final String time;
  final String preview;
  final Widget avatar;
  final bool invite;
}

Color _blue(BuildContext context) =>
    CupertinoColors.systemBlue.resolveFrom(context);
const _rowSecondary = CupertinoColors.secondaryLabel;

final _sections = <(String, List<_Mail>)>[
  (
    'Today',
    [
      const _Mail(
        'Nora Ellison',
        '9:41',
        'Just sent over the revised deck...',
        _Avatar.initials('NE', Color(0xFFE5484D)),
      ),
      const _Mail(
        'Marcus & Priya',
        '5:30',
        'Are we still on for the 4pm c...',
        _PairAvatar(),
        invite: true,
      ),
    ],
  ),
  (
    'Yesterday',
    [
      const _Mail(
        'Apple',
        '14:31',
        "We're thrilled to let you know th...",
        _Avatar.symbol('apple.logo', CupertinoColors.label),
      ),
      const _Mail(
        'Wifey',
        '20:55',
        'I have called you SIX times. whe...',
        _Avatar.initials('W', Color(0xFFF2A0C8)),
      ),
      const _Mail(
        'Dub.co',
        '8:30',
        'Your \$2400.59 payout for Fram...',
        _Avatar.symbol('circle.lefthalf.filled', CupertinoColors.label),
      ),
    ],
  ),
  (
    'This Week',
    [
      const _Mail(
        'Hiroshi Naka',
        '4:19',
        'The homepage copy is in Notion...',
        _Avatar.initials('HN', Color(0xFF8E8AA8)),
      ),
      const _Mail(
        'GitHub',
        '10:30',
        'A new sign-in to your account...',
        _Avatar.symbol(
          'chevron.left.forwardslash.chevron.right',
          Color(0xFF24292F),
        ),
      ),
      const _Mail(
        'Figma',
        '9:02',
        'Nora mentioned you in inbox-feedb...',
        _Avatar.initials('F', Color(0xFFA259FF)),
      ),
      const _Mail(
        'Linear',
        '8:15',
        'Weekly digest: 12 issues closed...',
        _Avatar.initials('L', Color(0xFF5E6AD2)),
      ),
    ],
  ),
];

class _MailTabBarDemoPageState extends State<MailTabBarDemoPage> {
  /// The iOS 26 tab bar pill is 62pt; the native view is taller, the
  /// extra space below the pill, so the button matches the pill.
  static const double _pillHeight = 62;
  int _index = 0;

  void _open(_Mail mail) =>
      Navigator.of(context)
          .push(CupertinoPageRoute(builder: (_) => _MessagePage(mail: mail)));

  void _compose() => Navigator.of(context).push(
    CupertinoPageRoute(
      fullscreenDialog: true,
      builder: (_) => const _ComposePage(),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              pad.top + 64,
              16,
              pad.bottom + 100,
            ),
            children: [
              for (final (title, mails) in _sections) ...[
                _SectionHeader(title),
                _Card(
                  children: [
                    for (final m in mails)
                      _MailRow(mail: m, onTap: () => _open(m)),
                  ],
                ),
                const SizedBox(height: 22),
              ],
            ],
          ),
          _TopChrome(
            leading: CupertinoNativeButton.icon(
              CupertinoSymbols.ellipsis,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: const _Pill(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _Dot(),
                  SizedBox(width: 8),
                  Text('Primary', style: _pillText),
                ],
              ),
            ),
            trailing: CupertinoNativeButton.icon(
              CupertinoSymbols.magnifyingglass,
              onPressed: () {},
            ),
          ),
          _BottomChrome(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: CupertinoNativeTabBar(
                    currentIndex: _index,
                    onTap: (i) => setState(() => _index = i),
                    items: const [
                      CupertinoNativeTab(
                        id: 'inbox',
                        title: 'Inbox',
                        icon: CupertinoNativeIcon.named('envelope.fill'),
                      ),
                      CupertinoNativeTab(
                        id: 'important',
                        title: 'Important',
                        icon: CupertinoNativeIcon.named('star.fill'),
                      ),
                      CupertinoNativeTab(
                        id: 'library',
                        title: 'Library',
                        icon: CupertinoNativeIcon.named('square.grid.2x2.fill'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                CupertinoNativeButton.glassProminent(
                  width: _pillHeight,
                  height: _pillHeight,
                  color: _blue(context),
                  borderShape: CupertinoNativeButtonBorderShape.circle,
                  onPressed: _compose,
                  child: const CupertinoSymbolImage('plus', size: 24),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MessagePage extends StatelessWidget {
  const _MessagePage({required this.mail});
  final _Mail mail;

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              pad.top + 72,
              16,
              pad.bottom + 100,
            ),
            children: [
              const _Card(
                children: [
                  _Field('Subject:', 'Feedback on the new layout'),
                  _Field('To:', 'yash@yashwanth941v.com'),
                ],
              ),
              const SizedBox(height: 18),
              _Card(
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Text(_body, style: _bodyText),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Attachements', style: _strong),
                        const SizedBox(height: 14),
                        _Attachment(),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          _TopChrome(
            leading: CupertinoNativeButton.icon(
              CupertinoSymbols.chevronLeft,
              onPressed: () => Navigator.of(context).pop(),
            ),
            title: _Pill(
              padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox.square(dimension: 32, child: mail.avatar),
                  const SizedBox(width: 10),
                  Text(mail.sender, style: _pillText),
                ],
              ),
            ),
            trailing: CupertinoNativeButton.icon(
              CupertinoSymbols.archivebox,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          _BottomChrome(
            child: Row(
              children: [
                Expanded(
                  child: CupertinoNativeButton.glassProminent(
                    expand: true,
                    height: 54,
                    color: _blue(context),
                    borderShape: CupertinoNativeButtonBorderShape.capsule,
                    onPressed: () => Navigator.of(context).push(
                      CupertinoPageRoute(
                        fullscreenDialog: true,
                        builder: (_) => const _ComposePage(),
                      ),
                    ),
                    child: const Text('Reply'),
                  ),
                ),
                const SizedBox(width: 10),
                CupertinoNativeButton.glass(
                  width: 54,
                  height: 54,
                  borderShape: CupertinoNativeButtonBorderShape.circle,
                  onPressed: () {},
                  child: const CupertinoSymbolImage('arrowshape.turn.up.right'),
                ),
                const SizedBox(width: 10),
                CupertinoNativeButton.glass(
                  width: 54,
                  height: 54,
                  borderShape: CupertinoNativeButtonBorderShape.circle,
                  onPressed: () {},
                  child: const CupertinoSymbolImage('ellipsis'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComposePage extends StatefulWidget {
  const _ComposePage();

  @override
  State<_ComposePage> createState() => _ComposePageState();
}

class _ComposePageState extends State<_ComposePage> {
  final _text = TextEditingController(
    text:
        "Hi Steve,\n\nI've been sitting on this for a while, but I think "
        "it's worth saying.\n\nThe way you think about pro",
  );

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, pad.top, 16, 12),
        child: Column(
          children: [
            SizedBox(
              height: 64,
              child: _ChromeRow(
                leading: CupertinoNativeButton.icon(
                  CupertinoSymbols.xmark,
                  onPressed: () => Navigator.of(context).pop(),
                ),
                title: const _Pill(child: Text('Compose', style: _pillText)),
                trailing: CupertinoNativeButton.icon(
                  CupertinoSymbols.squareAndPencil,
                  onPressed: () {},
                ),
              ),
            ),
            const SizedBox(height: 8),
            const _Card(
              children: [
                _Field(
                  'To:',
                  'stevejobs@icloud.com',
                  trailing: CupertinoSymbolImage(
                    'chevron.down',
                    size: 15,
                    weight: FontWeight.w600,
                  ),
                ),
                _Field('Subject:', 'One thing I keep thinking about'),
              ],
            ),
            const SizedBox(height: 18),
            Expanded(
              child: _Card(
                children: [
                  Expanded(
                    child: CupertinoTextField.borderless(
                      controller: _text,
                      autofocus: true,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      padding: const EdgeInsets.all(16),
                      style: _bodyText,
                      cursorColor: _blue(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const CupertinoNativeGlassContainer(
                  shape: CupertinoGlassShape.capsule,
                  padding: EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CupertinoSymbolImage('paperclip', size: 20),
                      SizedBox(width: 22),
                      CupertinoSymbolImage('textformat', size: 20),
                      SizedBox(width: 22),
                      CupertinoSymbolImage('pencil.tip.crop.circle', size: 20),
                    ],
                  ),
                ),
                const Spacer(),
                CupertinoNativeButton.glassProminent(
                  width: 56,
                  height: 56,
                  color: _blue(context),
                  borderShape: CupertinoNativeButtonBorderShape.circle,
                  onPressed: () => Navigator.of(context).pop(),
                  child: const CupertinoSymbolImage(
                    'paperplane.fill',
                    size: 22,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Chrome

/// Header row pinned to the top over a soft scroll edge effect.
class _TopChrome extends StatelessWidget {
  const _TopChrome({
    required this.leading,
    required this.title,
    required this.trailing,
  });
  final Widget leading, title, trailing;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: top + 64,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CupertinoScrollEdgeEffect(
              edge: CupertinoScrollEdgeEffectEdge.top,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, top, 16, 0),
            child: _ChromeRow(
              leading: leading,
              title: title,
              trailing: trailing,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChromeRow extends StatelessWidget {
  const _ChromeRow({
    required this.leading,
    required this.title,
    required this.trailing,
  });
  final Widget leading, title, trailing;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Align(alignment: Alignment.centerLeft, child: leading),
        title,
        Align(alignment: Alignment.centerRight, child: trailing),
      ],
    );
  }
}

/// Bottom controls over a soft scroll edge effect.
class _BottomChrome extends StatelessWidget {
  const _BottomChrome({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Stack(
        children: [
          const Positioned.fill(
            child: CupertinoScrollEdgeEffect(
              edge: CupertinoScrollEdgeEffectEdge.bottom,
            ),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 8),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
  });
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) => CupertinoNativeGlassContainer(
    shape: CupertinoGlassShape.capsule,
    interactive: true,
    padding: padding,
    child: child,
  );
}

// Content

const _pillText = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
const _strong = TextStyle(fontSize: 17, fontWeight: FontWeight.w600);
const _bodyText = TextStyle(fontSize: 17, height: 1.35);

const _body =
    'Hey Yash,\n\n'
    "Went through the screens you shared; overall it's looking really "
    'solid. The spacing is finally breathing and the type hierarchy makes '
    'sense now.\n\n'
    "Two things I'd look at: the card radius feels a touch heavy on mobile, "
    'and the empty state on the inbox could use something - even just a '
    "line of text. Right now it's a bit dead.\n\n"
    "Attaching my notes as a Figma file. Comments are inline, shouldn't "
    'take long to go through.\n\n'
    '- Nora';

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
    child: Text(title, style: _strong),
  );
}

/// White rounded card whose children are split by hairlines.
class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final divider = Container(
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) divider,
            children[i],
          ],
        ],
      ),
    );
  }
}

class _MailRow extends StatelessWidget {
  const _MailRow({required this.mail, required this.onTap});
  final _Mail mail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = _rowSecondary.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            SizedBox.square(dimension: 46, child: mail.avatar),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          mail.sender,
                          style: _strong.copyWith(fontWeight: FontWeight.w500),
                        ),
                      ),
                      Text(
                        mail.time,
                        style: TextStyle(fontSize: 16, color: secondary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (mail.invite) ...[
                        CupertinoSymbolImage(
                          'calendar',
                          size: 14,
                          color: secondary,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          mail.preview,
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(fontSize: 16, color: secondary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Label: value" line of the subject/recipient cards.
class _Field extends StatelessWidget {
  const _Field(this.label, this.value, {this.trailing});
  final String label, value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    child: Row(
      children: [
        Text(label, style: _strong),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _bodyText,
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class _Attachment extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: CupertinoColors.systemBackground.resolveFrom(context),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const CupertinoSymbolImage(
            'doc.richtext.fill',
            size: 18,
            color: Color(0xFFF24E1E),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(child: Text('inbox-feedback-v2.fig', style: _strong)),
        CupertinoSymbolImage(
          'arrow.down.circle.fill',
          size: 22,
          color: CupertinoColors.systemGrey.resolveFrom(context),
        ),
      ],
    ),
  );
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: CupertinoColors.systemRed.resolveFrom(context),
      shape: BoxShape.circle,
    ),
  );
}

/// Round avatar: initials or an SF Symbol on a colour.
class _Avatar extends StatelessWidget {
  const _Avatar.initials(String this.text, this.color) : symbol = null;
  const _Avatar.symbol(String this.symbol, this.color) : text = null;
  final String? text;
  final String? symbol;
  final Color color;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final d = box.maxWidth;
      // A label-coloured badge inverts with the appearance.
      final fg = color == CupertinoColors.label
          ? CupertinoColors.systemBackground.resolveFrom(context)
          : CupertinoColors.white;
      return Container(
        width: d,
        height: d,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CupertinoDynamicColor.resolve(color, context),
          shape: BoxShape.circle,
        ),
        child: symbol != null
            ? CupertinoSymbolImage(symbol!, size: d * 0.5, color: fg)
            : Text(
                text!,
                style: TextStyle(fontSize: d * 0.42, color: fg),
              ),
      );
    },
  );
}

/// Two overlapping avatars for a group thread.
class _PairAvatar extends StatelessWidget {
  const _PairAvatar();

  @override
  Widget build(BuildContext context) {
    final ring = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    );
    Widget face(String t, Color c) => Container(
      width: 32,
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(color: ring, shape: BoxShape.circle),
      child: _Avatar.initials(t, c),
    );
    return Stack(
      children: [
        Positioned(left: 0, top: 0, child: face('M', const Color(0xFF6E7B8B))),
        Positioned(
          right: 0,
          bottom: 0,
          child: face('P', const Color(0xFF7FA7E0)),
        ),
      ],
    );
  }
}
