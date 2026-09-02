import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:snabbit_runner/providers/language_provider.dart';
import 'package:snabbit_runner/services/mixpanel_setup.dart';
import 'package:snabbit_runner/utils/tracking_events.dart';

class BcpDegradedPage extends StatefulWidget {
  static const String routeName = '/bcp_degraded';

  /// `'auto'` when [BcpGate] routed here from a detected degraded state,
  /// `'manual'` when the user opened it from the drawer's emergency tile.
  /// Funnel splits behaviour on the distinction.
  static const String sourceAuto = 'auto';
  static const String sourceManual = 'manual';

  static const String _iconAsset = 'assets/pngs/degraded_service_icon.png';
  static const Color _primaryBlack = Color(0xFF303030);
  static const Color _secondaryBlack = Color(0xFF828282);
  static const Color _accentPink = Color(0xFFF70F79);

  static const String _titleKey = 'bcp_degraded_title';
  static const String _subtitleKey = 'bcp_degraded_subtitle';
  static const String _backButtonKey = 'bcp_degraded_back_button';
  static const String _titleEn = 'Temporarily Unavailable';
  static const String _subtitleEn =
      'We are experiencing technical difficulties. Please try again later.';
  static const String _backButtonEn = 'Go Back';

  final bool backDisabled;
  final String source;

  const BcpDegradedPage({
    super.key,
    required this.backDisabled,
    required this.source,
  });

  @override
  State<BcpDegradedPage> createState() => _BcpDegradedPageState();
}

class _BcpDegradedPageState extends State<BcpDegradedPage> {
  @override
  void initState() {
    super.initState();
    MixpanelSetup.logEvent(TrackingEvents.bcpDegradedPageLoad, {
      'source': widget.source,
      'back_disabled': widget.backDisabled,
    });
  }

  @override
  Widget build(BuildContext context) {
    final lang = Provider.of<LanguageProvider>(context, listen: true);
    return PopScope(
      canPop: !widget.backDisabled,
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 41),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    BcpDegradedPage._iconAsset,
                    width: 280,
                    height: 280,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    lang.getMessage(
                      BcpDegradedPage._titleKey,
                      BcpDegradedPage._titleEn,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      height: 32 / 24,
                      fontWeight: FontWeight.w700,
                      color: BcpDegradedPage._primaryBlack,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    lang.getMessage(
                      BcpDegradedPage._subtitleKey,
                      BcpDegradedPage._subtitleEn,
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 16,
                      height: 20 / 16,
                      fontWeight: FontWeight.w500,
                      color: BcpDegradedPage._secondaryBlack,
                    ),
                  ),
                  if (!widget.backDisabled) ...[
                    const SizedBox(height: 20),
                    _BackButton(
                      label: lang.getMessage(
                        BcpDegradedPage._backButtonKey,
                        BcpDegradedPage._backButtonEn,
                      ),
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _BackButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: BcpDegradedPage._accentPink,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              height: 20 / 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}
