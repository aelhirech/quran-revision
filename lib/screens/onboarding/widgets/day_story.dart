part of '../onboarding_screen.dart';

/// A day of use told in four moments, each showing the real control the user
/// will touch (US-17). Describes gestures only, never a projection figure.
class _DayStory extends StatelessWidget {
  const _DayStory();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DayStoryMoment(
          index: 1,
          title: SOnboarding.recitMatinTitre,
          body: SOnboarding.recitMatinCorps,
          control: _Inert(
            child: PrimaryCtaButton(
              icon: Icons.wb_sunny_outlined,
              label: SCheckIn.illuminerMaJournee,
              height: 44,
              onPressed: () {},
            ),
          ),
        ),
        _DayStoryMoment(
          index: 2,
          title: SOnboarding.recitPrieresTitre,
          body: SOnboarding.recitPrieresCorps,
          control: Icon(Icons.menu_book_outlined, color: palette.gold),
        ),
        _DayStoryMoment(
          index: 3,
          title: SOnboarding.recitEcouteTitre,
          body: SOnboarding.recitEcouteCorps,
          control: _Inert(
            child: IconButton.filled(
              onPressed: () {},
              icon: const Icon(Icons.play_arrow),
            ),
          ),
        ),
        _DayStoryMoment(
          index: 4,
          title: SOnboarding.recitSoirTitre,
          body: SOnboarding.recitSoirCorps,
          control: _Inert(
            child: PrimaryCtaButton(
              icon: Icons.nightlight_outlined,
              label: S.cloturerMaJournee,
              height: 44,
              onPressed: () {},
            ),
          ),
        ),
      ],
    );
  }
}

class _DayStoryMoment extends StatelessWidget {
  final int index;
  final String title;
  final String body;
  final Widget control;

  const _DayStoryMoment({
    required this.index,
    required this.title,
    required this.body,
    required this.control,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IndexBadge(text: '$index'),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: palette.textPrimary)),
                const SizedBox(height: 4),
                Text(body,
                    style: TextStyle(
                        fontSize: 13.5, color: palette.textMuted, height: 1.5)),
                const SizedBox(height: 10),
                control,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows a real button that does nothing. Not `onPressed: null`: a disabled
/// button turns grey and loses its shadow, so it would no longer look like
/// the one the user will meet in the app.
class _Inert extends StatelessWidget {
  final Widget child;
  const _Inert({required this.child});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(child: ExcludeSemantics(child: child));
  }
}
