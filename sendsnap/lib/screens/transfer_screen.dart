import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/transfer_file.dart';
import '../providers/transfer_provider.dart';
import '../providers/device_provider.dart';
import '../widgets/file_tile.dart';
import '../widgets/progress_bar.dart';
import '../services/ads_service.dart';

/// S5 — Transfer Screen
/// Live transfer monitoring for both sending and receiving.
class TransferScreen extends ConsumerWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Preload interstitial ad when transfer screen is shown
    AdsService.loadInterstitialAd();
    
    final session = ref.watch(activeTransferProvider);

    if (session == null) {
      return Scaffold(
        backgroundColor: SendSnapTheme.foundation,
        appBar: AppBar(
          backgroundColor: SendSnapTheme.foundation,
          title: const Text('Transfer'),
        ),
        body: const Center(
          child: Text(
            'No active transfer',
            style: TextStyle(color: SendSnapTheme.accent),
          ),
        ),
      );
    }

    final isSending = session.direction == TransferDirection.sending;
    final isComplete =
        session.status == TransferSessionStatus.completed;
    final hasError = session.status == TransferSessionStatus.connectionLost ||
        session.status == TransferSessionStatus.error;
    final isCancelled = session.status == TransferSessionStatus.cancelled;

    return Scaffold(
      backgroundColor: SendSnapTheme.foundation,
      appBar: AppBar(
        backgroundColor: SendSnapTheme.foundation,
        automaticallyImplyLeading: false,
        title: Text(
          isComplete
              ? 'Transfer Complete'
              : '${isSending ? 'Sending to' : 'Receiving from'} ${session.targetDevice.name}',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          // Status header
          if (session.status == TransferSessionStatus.waitingForAccept)
            _buildWaitingState(),

          if (isComplete) _buildCompleteState(session, isSending),

          if (hasError) _buildErrorState(session),

          if (isCancelled)
            _buildStatusBanner(
              'Transfer cancelled',
              Icons.cancel_rounded,
              SendSnapTheme.warning,
            ),

          // File list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.only(top: 8, bottom: 16),
              itemCount: session.files.length,
              itemBuilder: (context, index) {
                return FileTile(
                  file: session.files[index],
                  showProgress: true,
                );
              },
            ),
          ),

          // Overall progress (only during active transfer)
          if (session.status == TransferSessionStatus.transferring)
            TransferProgressDisplay(
              progress: session.overallProgress,
              speed: session.formattedSpeed,
              timeRemaining: session.formattedTimeRemaining,
            ),

          // Bottom button
          _buildBottomButton(context, ref, session, isComplete, hasError, isCancelled),
        ],
      ),
    );
  }

  Widget _buildWaitingState() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SendSnapTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SendSnapTheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: SendSnapTheme.primary.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Text(
              'Waiting for receiver to accept…',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompleteState(TransferSession session, bool isSending) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: SendSnapTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: SendSnapTheme.success.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SendSnapTheme.success.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              color: SendSnapTheme.success,
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '${session.files.length} ${session.files.length == 1 ? 'file' : 'files'} ${isSending ? 'sent to' : 'received from'} ${session.targetDevice.name}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (!isSending) ...[
            const SizedBox(height: 6),
            Text(
              'Saved to Downloads/SendSnap',
              style: TextStyle(
                color: SendSnapTheme.accent.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState(TransferSession session) {
    return _buildStatusBanner(
      session.errorMessage ?? 'Connection lost',
      Icons.error_outline_rounded,
      SendSnapTheme.error,
    );
  }

  Widget _buildStatusBanner(String message, IconData icon, Color color) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomButton(
    BuildContext context,
    WidgetRef ref,
    TransferSession session,
    bool isComplete,
    bool hasError,
    bool isCancelled,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SendSnapTheme.surface,
        border: Border(
          top: BorderSide(
            color: SendSnapTheme.accent.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: isComplete || isCancelled || hasError
              ? ElevatedButton(
                  onPressed: () {
                    void complete() {
                      ref.read(activeTransferProvider.notifier).clearTransfer();
                      Navigator.of(context)
                          .pushNamedAndRemoveUntil('/home', (route) => false);
                    }

                    if (isComplete) {
                      AdsService.showInterstitialAd(onAdDismissed: complete);
                    } else {
                      complete();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isComplete
                        ? SendSnapTheme.success
                        : SendSnapTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    isComplete ? 'Done' : (hasError ? 'Try Again' : 'Back to Home'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      color: Colors.white,
                    ),
                  ),
                )
              : OutlinedButton(
                  onPressed: () => _showCancelDialog(context, ref),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SendSnapTheme.error,
                    side: BorderSide(
                      color: SendSnapTheme.error.withValues(alpha: 0.5),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SendSnapTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Cancel transfer?',
          style: TextStyle(color: Colors.white, fontSize: 17),
        ),
        content: Text(
          'Files already transferred will be kept.',
          style: TextStyle(
            color: SendSnapTheme.accent.withValues(alpha: 0.7),
            fontSize: 14,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Keep going',
              style: TextStyle(
                color: SendSnapTheme.accent.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(activeTransferProvider.notifier).cancelTransfer();
            },
            child: const Text(
              'Cancel',
              style: TextStyle(color: SendSnapTheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
