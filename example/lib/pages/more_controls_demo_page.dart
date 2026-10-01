import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// The single-value SwiftUI controls, each lowered straight into a native
/// list row the way Settings lays them out: stepper, color well, gauges,
/// the calendar and wheel date pickers, the multi-date calendar, and an
/// expandable row.
class MoreControlsDemoPage extends StatefulWidget {
  const MoreControlsDemoPage({super.key});

  @override
  State<MoreControlsDemoPage> createState() => _MoreControlsDemoPageState();
}

class _MoreControlsDemoPageState extends State<MoreControlsDemoPage> {
  int _guests = 2;
  Color _color = CupertinoColors.systemIndigo;
  DateTime _date = DateTime.now();
  Set<DateTime> _days = {};

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'More Controls',
            leading: Navigator.canPop(context)
                ? CupertinoNativeButton.glass(
                    borderShape: CupertinoNativeButtonBorderShape.circle,
                    onPressed: () => Navigator.pop(context),
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronBackward,
                    ),
                  )
                : null,
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 40,
            ),
            sliver: SliverList.list(
              children: [
                CupertinoNativeList(
                  activeColor: _color,
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Reservation',
                      children: [
                        CupertinoNativeListTile(
                          id: 'guests',
                          title: 'Guests',
                          additionalInfo: '$_guests',
                          trailing: CupertinoNativeStepper(
                            value: _guests.toDouble(),
                            min: 1,
                            max: 10,
                            onChanged: (v) =>
                                setState(() => _guests = v.round()),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'color',
                          title: 'Accent Color',
                          trailing: CupertinoNativeColorPicker(
                            color: _color,
                            onChanged: (c) => setState(() => _color = c),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'capacity',
                          title: 'Capacity',
                          subtitle: '$_guests of 10 seats',
                          trailing: CupertinoNativeGauge(
                            value: _guests / 10,
                            currentValueLabel: '$_guests',
                            style: CupertinoNativeGaugeStyle.circularCapacity,
                            color: _color,
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'fill',
                          title: 'Room Fill',
                          trailing: CupertinoNativeGauge(
                            value: _guests / 10,
                            minimumValueLabel: '0',
                            maximumValueLabel: '10',
                            style: CupertinoNativeGaugeStyle.linearCapacity,
                            color: _color,
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Date',
                      footer:
                          'The graphical and wheel styles of the same '
                          'native DatePicker.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'calendar',
                          title: 'Day',
                          trailing: CupertinoNativeDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            style: CupertinoNativeDatePickerStyle.graphical,
                            initialDateTime: _date,
                            onDateTimeChanged: (d) => setState(() => _date = d),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'time',
                          title: 'Time',
                          trailing: CupertinoNativeDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            style: CupertinoNativeDatePickerStyle.wheel,
                            initialDateTime: _date,
                            onDateTimeChanged: (d) => setState(() => _date = d),
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Days Off',
                      footer: '${_days.length} days picked — iOS 16+.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'days',
                          title: 'Pick several days',
                          trailing: CupertinoNativeMultiDatePicker(
                            dates: _days,
                            minimumDate: DateTime.now(),
                            onChanged: (d) => setState(() => _days = d),
                          ),
                        ),
                      ],
                    ),
                    const CupertinoNativeListSection(
                      header: 'Expandable Row',
                      children: [
                        CupertinoNativeListTile(
                          id: 'advanced',
                          title: 'Advanced',
                          leading: CupertinoNativeIcon.named('gearshape'),
                          children: [
                            CupertinoNativeListTile(
                              id: 'proxy',
                              title: 'Proxy',
                              showChevron: true,
                            ),
                            CupertinoNativeListTile(
                              id: 'dns',
                              title: 'DNS',
                              showChevron: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
