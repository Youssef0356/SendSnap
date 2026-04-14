import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../models/transfer_file.dart';
import '../providers/transfer_provider.dart';
import '../widgets/file_tile.dart';

/// S3 — Incoming Request Screen
/// Modal overlay when someone wants to send files to this device.
class IncomingRequestSheet extends StatefulWidget {
  final IncomingRequest request;
  final WidgetRef ref;

  const IncomingRequestSheet({
    super.key,
    required this.request,
    required this.ref,
  });

  static void show(BuildContext context, IncomingRequest request, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => IncomingRequestSheet(request: request, ref: ref),
    );
  }

  @override
  State<IncomingRequestSheet> createState() => _IncomingRequestSheetState();
}

class _IncomingRequestSheetState extends State<IncomingRequestSheet> {
  int _countdown = 30;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown <= 1) {
        _decline();
        return;
      }
      setState(() => _countdown--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _accept() {
    _timer?.cancel();
    final transferNotifier = widget.ref.read(activeTransferProvider.notifier);
    transferNotifier.acceptIncoming(widget.request);

    // Clear the incoming request
    widget.ref.read(incomingRequestProvider.notifier).state = null;

    Navigator.of(context).pop();
    Navigator.of(context).pushNamed('/transfer');
  }

  void _decline() {
    _timer?.cancel();
    final service = widget.ref.read(transferServiceProvider);
    service.declineTransfer(widget.request);

    // Clear the incoming request
    widget.ref.read(incomingRequestProvider.notifier).state = null;

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final request = widget.request;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SendSnapTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: SendSnapTheme.accent.withValues(alpha: 0.15),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SendSnapTheme.accent.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),

            // Sender avatar
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: SendSnapTheme.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.smartphone_rounded,
                color: SendSnapTheme.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),

            // Sender name
            Text(
              request.senderName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'wants to send you files',
              style: TextStyle(
                color: SendSnapTheme.accent.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),

            // File list
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.3,
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: request.files.length,
                itemBuilder: (context, index) {
                  return FileTile(file: request.files[index]);
                },
              ),
            ),

            const SizedBox(height: 16),

            // Total summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: SendSnapTheme.foundation,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Total: ${request.files.length} ${request.files.length == 1 ? 'file' : 'files'} · ${request.formattedTotalSize}',
                    style: TextStyle(
                      color: SendSnapTheme.accent.withValues(alpha: 0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Countdown
            Text(
              'Auto-decline in ${_countdown}s',
              style: TextStyle(
                color: SendSnapTheme.accent.withValues(alpha: 0.4),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 16),

            // Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _decline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: SendSnapTheme.error,
                      side: BorderSide(
                        color: SendSnapTheme.error.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _accept,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SendSnapTheme.success,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Accept',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
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
