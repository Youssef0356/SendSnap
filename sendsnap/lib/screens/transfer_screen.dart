import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path/path.dart' as p;
import '../providers/transfer_provider.dart';
import '../config/constants.dart';
import '../models/transfer.dart';
import '../services/file_handler.dart';
import '../services/local_storage_service.dart';
import '../services/rating_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/bouncing_card.dart';
import '../widgets/ambient_background.dart';
import '../widgets/media_viewer_modal.dart';
import '../l10n/app_localizations.dart';
import '../services/bidi_helper.dart';
import 'received_files_screen.dart';
class TransferScreen extends StatefulWidget {
  const TransferScreen({super.key});
  @override
  State<TransferScreen> createState() => _TransferScreenState();
}
class _TransferScreenState extends State<TransferScreen> {
  bool _hasTriggeredRating = false;
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final transProv = Provider.of<TransferProvider>(context);
    final current = transProv.currentTransfer;
    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n?.transferTitle ?? 'Transfer')),
        body: Center(child: Text(l10n?.transferNoActive ?? 'No active transfers')),
      );
    }
    if (current.status == TransferStatus.completed && !_hasTriggeredRating) {
      _hasTriggeredRating = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          RatingService.recordSuccessfulTransfer(context);
        }
      });
    }
    final isReceiver = current.savedPath != null;
    return AmbientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: BouncingCard(
              onTap: () {
                if (current.status == TransferStatus.completed || 
                    current.status == TransferStatus.failed) {
                  transProv.dismissActiveTransfer();
                }
                Navigator.pop(context);
              },
              child: Container(
                margin: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 20),
              ),
            ),
          ),
          title: Text(
            _getTitle(current.status, l10n),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 19,
              letterSpacing: -0.3,
              color: AppColors.textPrimary,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl, vertical: AppSpacing.l),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: GlassContainer(
                  blur: 16,
                  opacity: 0.72,
                  borderRadius: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (transProv.transfers.length > 1) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            'Batch: ${transProv.transfers.where((t) => t.status == TransferStatus.completed).length} of ${transProv.transfers.length} finished',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      _buildProgressIndicator(context, current),
                      const SizedBox(height: AppSpacing.xl),
                      Text(
                        current.fileName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                          color: AppColors.textPrimary,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Text(
                          BidiHelper.isolate('${FileHandler.formatFileSize(current.transferredBytes)} / ${FileHandler.formatFileSize(current.fileSize)}'),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      if (current.status == TransferStatus.completed)
                        _buildCompletedActions(context, transProv, isReceiver, l10n)
                      else if (current.status == TransferStatus.failed)
                        _buildFailedActions(context, transProv, l10n)
                      else
                        _buildTransferringIndicator(context, current, l10n),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  String _getTitle(TransferStatus status, AppLocalizations? l10n) {
    switch (status) {
      case TransferStatus.completed:
        return l10n?.transferCompleted ?? 'Transfer Complete';
      case TransferStatus.failed:
        return l10n?.transferFailed ?? 'Transfer Failed';
      case TransferStatus.cancelled:
        return l10n?.transferCanceled ?? 'Transfer Cancelled';
      default:
        return l10n?.transferTitle ?? 'Transferring...';
    }
  }
  Widget _buildTransferringIndicator(BuildContext context, FileTransfer current, AppLocalizations? l10n) {
    return Column(
      children: [
        if (current.speed > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary.withValues(alpha: 0.12),
                  AppColors.secondary.withValues(alpha: 0.12),
                ],
              ),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.bolt_rounded, color: AppColors.primary, size: 18),
                const SizedBox(width: 6),
                Text(
                  current.formattedSpeed,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          Text(
            l10n?.transferConnecting('') ?? 'Preparing transfer...',
            style: const TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
        const SizedBox(height: 10),
        Text(
          l10n?.homeNoDevicesHint ?? 'Keep both devices on the same Wi-Fi',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  Widget _buildProgressIndicator(BuildContext context, FileTransfer transfer) {
    final isCompleted = transfer.status == TransferStatus.completed;
    final isFailed = transfer.status == TransferStatus.failed;
    Color progressColor = AppColors.primary;
    if (isCompleted) progressColor = AppColors.success;
    if (isFailed) progressColor = AppColors.error;
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glowing track
        Container(
          width: 210,
          height: 210,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: progressColor.withValues(alpha: isCompleted ? 0.35 : 0.15),
                blurRadius: 36,
                spreadRadius: 2,
              ),
            ],
          ),
        ),
        SizedBox(
          width: 190,
          height: 190,
          child: CircularProgressIndicator(
            value: transfer.progress,
            strokeWidth: 12,
            backgroundColor: progressColor.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: progressColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isCompleted
                    ? Icons.check_circle_rounded
                    : isFailed
                        ? Icons.error_rounded
                        : Icons.sync_rounded,
                size: 40,
                color: progressColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${(transfer.progress * 100).toInt()}%',
              style: const TextStyle(
                fontSize: 38,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ],
    );
  }
  Widget _buildCompletedActions(BuildContext context, TransferProvider transProv, bool isReceiver, AppLocalizations? l10n) {
    final current = transProv.currentTransfer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          isReceiver
              ? 'File saved to Downloads/SendSnap'
              : (l10n?.transferCompleted ?? 'File sent successfully!'),
          style: const TextStyle(
            color: AppColors.success,
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (isReceiver && current?.savedPath != null) ...[
          BouncingCard(
            onTap: () {
              final path = current!.savedPath!;
              final ext = p.extension(path).toLowerCase();
              if (['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.heic'].contains(ext)) {
                final file = File(path);
                final item = LocalItem(
                  path: path,
                  name: p.basename(path),
                  size: file.existsSync() ? file.lengthSync() : 0,
                  modified: DateTime.now(),
                  isDirectory: false,
                  extension: ext,
                );
                MediaViewerModal.show(context, item: item);
              } else {
                FileHandler.openFile(path);
              }
            },
            child: Container(
              width: double.infinity,
              height: 54,
              decoration: BoxDecoration(
                gradient: AppColors.sendGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.open_in_new_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.settingsOpen ?? 'OPEN FILE',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          BouncingCard(
            onTap: () {
              final path = current?.savedPath;
              FileHandler.openFolderChoice(context, filePath: path);
            },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_open_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.receivedOpenFolder ?? 'OPEN IN FILE MANAGER',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          BouncingCard(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ReceivedFilesScreen()),
              );
            },
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black.withValues(alpha: 0.08), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.folder_special_rounded, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    l10n?.transferViewFiles ?? 'VIEW RECEIVED FILES',
                    style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
        BouncingCard(
          onTap: () {
            transProv.dismissActiveTransfer();
            Navigator.pop(context);
          },
          child: Container(
            width: double.infinity,
            height: 54,
            decoration: BoxDecoration(
              gradient: !isReceiver ? AppColors.receiveGradient : null,
              color: isReceiver ? Colors.black.withValues(alpha: 0.05) : null,
              borderRadius: BorderRadius.circular(20),
              boxShadow: !isReceiver ? [
                BoxShadow(
                  color: AppColors.receivePrimary.withValues(alpha: 0.35),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ] : null,
            ),
            child: Center(
              child: Text(
                l10n?.actionDone ?? 'DONE',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  letterSpacing: 0.5,
                  color: isReceiver ? AppColors.textPrimary : Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
  Widget _buildFailedActions(BuildContext context, TransferProvider transProv, AppLocalizations? l10n) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          l10n?.transferFailed ?? 'Transfer failed. Please check connection and try again.',
          style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        BouncingCard(
          onTap: () {
            transProv.dismissActiveTransfer();
            Navigator.pop(context);
          },
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                l10n?.actionCancel ?? 'BACK',
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}