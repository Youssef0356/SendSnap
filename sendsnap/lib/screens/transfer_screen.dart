import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../config/constants.dart';
import '../models/transfer.dart';
import '../services/file_handler.dart';

class TransferScreen extends StatelessWidget {
  const TransferScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final transProv = Provider.of<TransferProvider>(context);
    final current = transProv.currentTransfer;

    if (current == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Transfer')),
        body: const Center(child: Text('No active transfers')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          onPressed: () {
            // Dismiss the active transfer if completed before popping
            if (current.status == TransferStatus.completed || 
                current.status == TransferStatus.failed) {
              transProv.dismissActiveTransfer();
            }
            Navigator.pop(context);
          },
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
        ),
        title: Text(
          _getTitle(current.status),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildProgressIndicator(context, current),
              const SizedBox(height: AppSpacing.xxl),
              Text(
                current.fileName,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.s),
              Text(
                '${FileHandler.formatFileSize(current.transferredBytes)} / ${FileHandler.formatFileSize(current.fileSize)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AppSpacing.xxl),
              if (current.status == TransferStatus.completed)
                _buildCompletedActions(context, transProv)
              else if (current.status == TransferStatus.failed)
                _buildFailedActions(context, transProv)
              else
                 Column(
                   children: [
                     Text(
                       'Transferring...',
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                         color: AppColors.primary, 
                         fontWeight: FontWeight.bold,
                       ),
                     ),
                     const SizedBox(height: 8),
                     Text(
                       'Keep both devices nearby',
                       style: Theme.of(context).textTheme.bodySmall?.copyWith(
                         color: AppColors.textSecondary,
                       ),
                     ),
                   ],
                 ),
            ],
          ),
        ),
      ),
    );
  }

  String _getTitle(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return 'Transfer Complete!';
      case TransferStatus.failed:
        return 'Transfer Failed';
      case TransferStatus.cancelled:
        return 'Transfer Cancelled';
      default:
        return 'Transferring...';
    }
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
        SizedBox(
          width: 240,
          height: 240,
          child: CircularProgressIndicator(
            value: transfer.progress,
            strokeWidth: 12,
            backgroundColor: progressColor.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          children: [
            Icon(
              isCompleted ? Icons.check_circle_rounded 
                : isFailed ? Icons.error_rounded 
                : Icons.sync_rounded,
              size: 64,
              color: progressColor,
            ),
            const SizedBox(height: 8),
            Text(
              '${(transfer.progress * 100).toInt()}%',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(fontSize: 48),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletedActions(BuildContext context, TransferProvider transProv) {
    return Column(
      children: [
        const Icon(Icons.celebration_rounded, color: AppColors.warning, size: 48),
        const SizedBox(height: 12),
        Text(
          'File saved to Downloads/SendSnap',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.success),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            transProv.dismissActiveTransfer();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 56),
            backgroundColor: AppColors.success,
          ),
          child: const Text('DONE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ],
    );
  }

  Widget _buildFailedActions(BuildContext context, TransferProvider transProv) {
    return Column(
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 48),
        const SizedBox(height: 12),
        const Text('Something went wrong', style: TextStyle(color: AppColors.error)),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            transProv.dismissActiveTransfer();
            Navigator.pop(context);
          },
          style: ElevatedButton.styleFrom(
            minimumSize: const Size(200, 56),
          ),
          child: const Text('BACK'),
        ),
      ],
    );
  }
}
