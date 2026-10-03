import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// One message of the Mail demo.
class Mail {
  const Mail({
    required this.sender,
    required this.color,
    required this.time,
    required this.subject,
    required this.preview,
    required this.body,
    this.unread = false,
  });

  final String sender;
  final Color color;
  final String time;
  final String subject;
  final String preview;
  final String body;
  final bool unread;

  String get initials =>
      sender.split(' ').take(2).map((word) => word[0]).join().toUpperCase();
}

const mails = <Mail>[
  Mail(
    sender: 'Apple',
    color: CupertinoColors.systemGrey,
    time: '9:41',
    subject: 'Your receipt from Apple',
    preview: 'Apple ID: you@icloud.com · iCloud+ with 200 GB · €2.99',
    body:
        'Thank you for your purchase.\n\niCloud+ with 200 GB of storage, '
        'billed monthly. Your subscription renews on November 2 unless you '
        'cancel it at least one day before.',
    unread: true,
  ),
  Mail(
    sender: 'Chloé Dubois',
    color: CupertinoColors.systemPink,
    time: '8:12',
    subject: 'Photos from the weekend',
    preview: 'I put them all in a shared album. The sunset ones turned out…',
    body:
        'Hi!\n\nI put them all in a shared album. The sunset ones turned '
        'out even better than I hoped. Let me know which ones you want '
        'printed for the kitchen wall.\n\nChloé',
    unread: true,
  ),
  Mail(
    sender: 'Daniel Kim',
    color: CupertinoColors.systemBlue,
    time: 'Yesterday',
    subject: 'Re: Design review on Thursday',
    preview: 'Works for me. I will bring the new tab bar mockups and the…',
    body:
        'Works for me. I will bring the new tab bar mockups and the motion '
        'studies for the glass transitions.\n\nShould we invite the '
        'accessibility team too?\n\nDaniel',
    unread: true,
  ),
  Mail(
    sender: 'TestFlight',
    color: CupertinoColors.systemTeal,
    time: 'Yesterday',
    subject: 'Cupertino Widgets 1.4 (212) is ready to test',
    preview: 'A new build is available for testing. What to test: native…',
    body:
        'A new build is available for testing.\n\nWhat to test: native '
        'sheets, the Mail demo and the reworked keyboard avoidance. Thanks '
        'for helping make the app better!',
  ),
  Mail(
    sender: 'Fatou Diallo',
    color: CupertinoColors.systemOrange,
    time: 'Tuesday',
    subject: 'Dinner on Saturday?',
    preview: 'We are trying the new place by the river. 8pm? Bring Hugo…',
    body:
        'We are trying the new place by the river. 8pm?\n\nBring Hugo if '
        'he is around. They have a terrace now.\n\nFatou',
  ),
  Mail(
    sender: 'GitHub',
    color: CupertinoColors.systemIndigo,
    time: 'Tuesday',
    subject: '[cupertino_native_ui] New issue: sheet detents on iPad',
    preview: 'A medium detent sheet opens at full height on iPad in split…',
    body:
        'A medium detent sheet opens at full height on iPad in split view.\n\n'
        'Steps to reproduce: open the Sheet demo in split view and present '
        'the segmented sheet.',
  ),
  Mail(
    sender: 'Mateo García',
    color: CupertinoColors.systemGreen,
    time: 'Monday',
    subject: 'Trip itinerary',
    preview: 'Flights are booked! Here is the plan for Lisbon, day by day…',
    body:
        'Flights are booked! Here is the plan for Lisbon, day by day:\n\n'
        'Friday: arrive, Alfama walk.\nSaturday: Sintra.\nSunday: '
        'Belém and pastéis.\n\nMateo',
  ),
  Mail(
    sender: 'Nora Larsen',
    color: CupertinoColors.systemPurple,
    time: 'Sunday',
    subject: 'The book I mentioned',
    preview: 'Found it: “The Design of Everyday Things”. Chapter 4 is the…',
    body:
        'Found it: “The Design of Everyday Things”. Chapter 4 is the one '
        'about constraints I was talking about.\n\nNora',
  ),
];

/// The inbox: a Mail-style list, filtered by the scaffold's native search
/// field. Tapping a message pushes it natively.
class MailInboxBody extends StatefulWidget {
  const MailInboxBody({super.key});

  @override
  State<MailInboxBody> createState() => _MailInboxBodyState();
}

class _MailInboxBodyState extends State<MailInboxBody> {
  String _query = '';

  @override
  void initState() {
    super.initState();
    CupertinoNativePageScaffold.searchState.addListener(_onSearch);
  }

  @override
  void dispose() {
    CupertinoNativePageScaffold.searchState.removeListener(_onSearch);
    super.dispose();
  }

  void _onSearch() => setState(
    () => _query = CupertinoNativePageScaffold.searchState.value.query,
  );

  void _open(int index) {
    CupertinoNativePageScaffold.push(
      CupertinoNativePageScaffoldPage(
        route: 'mail$index',
        navigationBar: const CupertinoNativeScaffoldNavigationBar(
          title: '',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.inline,
          trailing: [
            CupertinoNativeToolbarItemGroup(
              items: [
                CupertinoNativeToolbarItem(
                  systemImage: 'chevron.up',
                  actionId: 'previous',
                ),
                CupertinoNativeToolbarItem(
                  systemImage: 'chevron.down',
                  actionId: 'next',
                ),
              ],
            ),
          ],
          bottom: [
            CupertinoNativeToolbarItem(systemImage: 'trash', actionId: 'trash'),
            CupertinoNativeToolbarItem(systemImage: 'folder', actionId: 'move'),
            CupertinoNativeToolbarSpacer(),
            CupertinoNativeToolbarItem(
              systemImage: 'arrowshape.turn.up.left',
              actionId: 'reply',
            ),
            CupertinoNativeToolbarItem(
              systemImage: 'square.and.pencil',
              actionId: 'compose',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final (i, mail) in mails.indexed)
        if (q.isEmpty ||
            '${mail.sender} ${mail.subject} ${mail.preview}'
                .toLowerCase()
                .contains(q))
          (i, mail),
    ];
    if (shown.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No Results',
              style: CupertinoTheme.of(context).textTheme.textStyle
                  .copyWith(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'for “$_query”',
              style: TextStyle(
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
          ],
        ),
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (index, (i, mail)) in shown.indexed)
          _MailRow(
            mail: mail,
            showSeparator: index != shown.length - 1,
            onTap: () => _open(i),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// A Mail row: unread dot, avatar, sender and time, subject, two-line preview.
class _MailRow extends StatelessWidget {
  const _MailRow({
    required this.mail,
    required this.showSeparator,
    required this.onTap,
  });

  final Mail mail;
  final bool showSeparator;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final label = CupertinoTheme.of(context).textTheme.textStyle;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 16, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 16,
                    child: mail.unread
                        ? Padding(
                            padding: const EdgeInsets.only(top: 16),
                            child: Container(
                              width: 9,
                              height: 9,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: CupertinoColors.systemBlue.resolveFrom(
                                  context,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                  _Avatar(mail: mail, size: 40),
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
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: label.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              mail.time,
                              style: TextStyle(fontSize: 15, color: secondary),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              CupertinoIcons.chevron_right,
                              size: 13,
                              color: CupertinoColors.tertiaryLabel.resolveFrom(
                                context,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mail.subject,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: label.copyWith(fontSize: 15),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          mail.preview,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.25,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (showSeparator)
              Padding(
                padding: const EdgeInsets.only(left: 68),
                child: Container(
                  height: 1 / MediaQuery.devicePixelRatioOf(context),
                  color: CupertinoColors.separator.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The sender's initials on their colour, Mail's contact photo stand-in.
class _Avatar extends StatelessWidget {
  const _Avatar({required this.mail, required this.size});

  final Mail mail;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoDynamicColor.resolve(mail.color, context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.75), color],
        ),
      ),
      child: Text(
        mail.initials,
        style: TextStyle(
          fontSize: size * 0.4,
          fontWeight: FontWeight.w600,
          color: CupertinoColors.white,
        ),
      ),
    );
  }
}

/// One message, read: subject, sender block, then the text.
class MailMessageBody extends StatelessWidget {
  const MailMessageBody({super.key, required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final mail = mails[index];
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final label = CupertinoTheme.of(context).textTheme.textStyle;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Avatar(mail: mail, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      mail.sender,
                      style: label.copyWith(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      'To: Me',
                      style: TextStyle(fontSize: 15, color: secondary),
                    ),
                  ],
                ),
              ),
              Text(mail.time, style: TextStyle(fontSize: 15, color: secondary)),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            mail.subject,
            style: label.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            height: 1 / MediaQuery.devicePixelRatioOf(context),
            color: CupertinoColors.separator.resolveFrom(context),
          ),
          const SizedBox(height: 16),
          Text(mail.body, style: label.copyWith(height: 1.4)),
        ],
      ),
    );
  }
}
