import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../config/constants.dart';
import '../services/rating_service.dart';
import 'bouncing_card.dart';
import 'glass_container.dart';
import '../l10n/app_localizations.dart';

/// A beautiful frosted glass modal dialog that encourages ratings
/// and routes feedback thoughtfully based on user satisfaction.
class RateUsDialog extends StatefulWidget {
  const RateUsDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      builder: (ctx) => const RateUsDialog(),
    );
  }

  @override
  State<RateUsDialog> createState() => _RateUsDialogState();
}

class _RateUsDialogState extends State<RateUsDialog> with SingleTickerProviderStateMixin {
  int _selectedRating = 5;
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _scaleAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutBack,
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String get _storeName {
    if (Platform.isAndroid) return 'Google Play';
    if (Platform.isWindows) return 'Microsoft Store';
    if (Platform.isIOS || Platform.isMacOS) return 'App Store';
    return 'Store';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ScaleTransition(
      scale: _scaleAnimation,
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 380),
          child: GlassContainer(
            blur: 28,
            opacity: 0.90,
            borderRadius: 32,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
            borderColor: Colors.white.withValues(alpha: 0.9),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Glowing Star Badge
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFFFD700), Color(0xFFFF9500)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFFF9500).withValues(alpha: 0.40),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.star_rounded,
                      size: 44,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Title
                Text(
                  l10n.rateEnjoyingTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Description
                Text(
                  l10n.rateEnjoyingDesc(_storeName),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // 5-Star Interactive Rating Selector
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starNumber = index + 1;
                    final isFilled = starNumber <= _selectedRating;

                    return GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() {
                          _selectedRating = starNumber;
                        });
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: AnimatedScale(
                          duration: const Duration(milliseconds: 200),
                          scale: isFilled ? 1.15 : 1.0,
                          curve: Curves.easeOutBack,
                          child: Icon(
                            isFilled ? Icons.star_rounded : Icons.star_outline_rounded,
                            size: 38,
                            color: isFilled ? const Color(0xFFFFB300) : Colors.black.withValues(alpha: 0.20),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 24),

                // Smart Action Button
                BouncingCard(
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (_selectedRating >= 4) {
                      await RatingService.launchStoreReview();
                    } else {
                      await RatingService.launchFeedbackEmail();
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: _selectedRating >= 4
                          ? const LinearGradient(
                              colors: [Color(0xFFFF9500), Color(0xFFFF5E3A)],
                            )
                          : AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(18),
                      boxShadow: [
                        BoxShadow(
                          color: (_selectedRating >= 4 ? const Color(0xFFFF9500) : AppColors.primary)
                              .withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _selectedRating >= 4 ? l10n.rateSubmit(_storeName) : l10n.rateFeedbackInstead,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                // Maybe Later Button
                TextButton(
                  onPressed: () {
                    RatingService.markPostponed();
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    l10n.rateLater,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
