import 'package:flutter/material.dart';

import 'package:responda/core/theme/app_colors.dart';

class EmergencyInfoScreen extends StatelessWidget {
  const EmergencyInfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: const [
              _EmergencyHeader(),
              SizedBox(height: 14),
              _ManualCover(),
              SizedBox(height: 14),
              _ContentsCard(),
              SizedBox(height: 14),
              _ManualSection(
                number: '01',
                title: 'Before an emergency',
                body:
                    '• Know the nearest evacuation center and safest route.\n'
                    '• Prepare water, food, medicines, a flashlight, and copies of important IDs.\n'
                    '• Choose one family contact and agree on a meeting place.\n'
                    '• Keep your phone charged and save local emergency numbers.',
              ),
              SizedBox(height: 14),
              _ManualSection(
                number: '02',
                title: 'When an emergency happens',
                body:
                    '• Protect yourself first and move away from immediate danger.\n'
                    '• Call 911 or Pantukan MDRRMO when cellular signal is available.\n'
                    '• Give your barangay, a nearby landmark, and GPS location if possible.\n'
                    '• Follow official instructions and do not return until the area is declared safe.',
              ),
              SizedBox(height: 14),
              _ManualSection(
                number: '03',
                title: 'Flood',
                accent: AppColors.info,
                background: AppColors.infoSoft,
                body:
                    '• Move to higher ground as soon as water begins rising.\n'
                    '• Never walk, swim, or drive through moving floodwater.\n'
                    '• Disconnect electricity only when it is safe to do so.\n'
                    '• Keep children away from drains, rivers, and contaminated water.',
              ),
              SizedBox(height: 14),
              _ManualSection(
                number: '04',
                title: 'Fire',
                accent: AppColors.danger,
                background: AppColors.dangerSoft,
                body:
                    '• Leave immediately using the nearest safe exit.\n'
                    '• Crawl low beneath smoke and cover your nose and mouth.\n'
                    '• Once outside, stay outside and call for help.\n'
                    '• Never return for belongings.',
              ),
              SizedBox(height: 14),
              _ManualSection(
                number: '05',
                title: 'Road accident',
                accent: AppColors.brand,
                background: AppColors.brandSoft,
                body:
                    '• Move away from traffic if you can do so safely.\n'
                    '• Warn approaching vehicles and call for emergency help.\n'
                    '• Do not move an injured person unless there is immediate danger.\n'
                    '• Share the road name, landmark, and number of injured people.',
              ),
              SizedBox(height: 14),
              _ManualSection(
                number: '06',
                title: 'Landslide',
                accent: AppColors.warning,
                background: AppColors.warningSoft,
                body:
                    '• Move away from steep slopes, cliffs, and river channels.\n'
                    '• Watch for falling rocks, leaning trees, and new ground cracks.\n'
                    '• Do not cross an active slide area.\n'
                    '• Follow evacuation instructions from local authorities.',
              ),
              SizedBox(height: 14),
              _ManualSection(
                number: '07',
                title: 'Evacuation and recovery',
                body:
                    '• Bring medicines, IDs, water, food, and essential clothing.\n'
                    '• Account for children, older adults, and persons with disabilities.\n'
                    '• Use the route given by barangay or MDRRMO responders.\n'
                    '• Avoid damaged buildings, fallen wires, and floodwater when returning.',
              ),
              SizedBox(height: 14),
              _ContactsCard(),
              SizedBox(height: 14),
              _NoticeCard(
                title: 'AVAILABLE WITHOUT INTERNET',
                body: 'This manual stays available offline. Phone calls and SMS still require cellular signal.',
                background: AppColors.successSoft,
                titleColor: AppColors.success,
              ),
              SizedBox(height: 14),
              _NoticeCard(
                title: 'IMPORTANT',
                body: 'Always follow instructions from Pantukan MDRRMO, barangay officials, police, fire services, and medical responders.',
                background: AppColors.neutralSoft,
                titleColor: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmergencyHeader extends StatelessWidget {
  const _EmergencyHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Emergency Information',
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  height: 28 / 22,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Offline safety manual',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        Container(
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: AppColors.successSoft,
            borderRadius: BorderRadius.circular(14),
          ),
          alignment: Alignment.center,
          child: const Text(
            'AVAILABLE OFFLINE',
            style: TextStyle(
              color: AppColors.success,
              fontSize: 9,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _ManualCover extends StatelessWidget {
  const _ManualCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 175,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.brand,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Stack(
        children: [
          const Positioned.fill(
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 14, 96, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PANTUKAN MDRRMO',
                    style: TextStyle(
                      color: Color(0xFFF2C8CF),
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    'Emergency Safety Manual',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      height: 23 / 18,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Simple guidance to read before, during, and after an emergency.',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Color(0xFFFBECEF),
                      fontSize: 10,
                      height: 13 / 10,
                    ),
                  ),
                  Spacer(),
                  Text(
                    'Keep this guide on your phone for offline use.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: AppColors.surface,
                      fontSize: 8,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 5),
                child: Semantics(
                  image: true,
                  label: 'RESPONDA responder reading an emergency manual',
                  child: Image.asset(
                    'assets/images/emergency_information.gif',
                    height: 160,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.none,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContentsCard extends StatelessWidget {
  const _ContentsCard();

  static const _items = [
    ('01', 'Before an emergency'),
    ('02', 'When an emergency happens'),
    ('03–06', 'Hazard-specific guidance'),
    ('07', 'Evacuation and recovery'),
    ('08', 'Emergency contacts'),
  ];

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CONTENTS',
            style: TextStyle(
              color: AppColors.brand,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < _items.length; index++) ...[
            Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 48,
                    child: Text(
                      _items[index].$1,
                      style: const TextStyle(
                        color: AppColors.brand,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      _items[index].$2,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (index < _items.length - 1) const SizedBox(height: 7),
          ],
        ],
      ),
    );
  }
}

class _ManualSection extends StatelessWidget {
  const _ManualSection({
    required this.number,
    required this.title,
    required this.body,
    this.accent = AppColors.brand,
    this.background = AppColors.surface,
  });

  final String number;
  final String title;
  final String body;
  final Color accent;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        boxShadow: background == AppColors.surface
            ? const [
                BoxShadow(
                  color: Color(0x121C1C1E),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 11,
              height: 17 / 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactsCard extends StatelessWidget {
  const _ContactsCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionHeading(number: '08', title: 'Emergency contacts'),
          SizedBox(height: 10),
          _ContactRow(
            title: 'National emergency hotline',
            detail: 'Call 911 when cellular service is available.',
          ),
          Divider(color: AppColors.border, height: 17),
          _ContactRow(
            title: 'Pantukan MDRRMO',
            detail: 'Use the verified local number saved on this device.',
          ),
          Divider(color: AppColors.border, height: 17),
          _ContactRow(
            title: 'Barangay emergency contact',
            detail: 'Confirm the current number with your barangay office.',
          ),
        ],
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.number, required this.title});

  final String number;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: AppColors.brand,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            number,
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          detail,
          style: const TextStyle(color: AppColors.textSecondary, fontSize: 10),
        ),
      ],
    );
  }
}

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({
    required this.title,
    required this.body,
    required this.background,
    required this.titleColor,
  });

  final String title;
  final String body;
  final Color background;
  final Color titleColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 10,
              height: 16 / 10,
            ),
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x121C1C1E),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: child,
    );
  }
}
