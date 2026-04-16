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
    final active = transProv.activeTransfer;
    final last = transProv.transfers.isNotEmpty ? transProv.transfers.first : null;
    
    final current = active ?? last;

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
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.close, color: AppColors.textPrimary),
        ),
        title: Text(
          current.status == TransferStatus.completed ? 'Success' : 'Transferring',
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
                _buildCompletedActions(context)
              else if (current.status == TransferStatus.failed)
                _buildFailedActions(context)
              else
                 Text(
                   'Sending to connected device...',
                   style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold),
                 ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator(BuildContext context, FileTransfer transfer) {
    return Stack(
      alignment: Alignment.center,
      children: [
        SizedBox(
          width: 240,
          height: 240,
          child: CircularProgressIndicator(
            value: transfer.progress,
            strokeWidth: 12,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(
               transfer.status == TransferStatus.completed ? AppColors.success : AppColors.primary
            ),
            strokeCap: StrokeCap.round,
          ),
        ),
        Column(
          children: [
            Icon(
              transfer.status == TransferStatus.completed ? Icons.check_circle_rounded : Icons.sync_rounded,
              size: 64,
              color: transfer.status == TransferStatus.completed ? AppColors.success : AppColors.primary,
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

  Widget _buildCompletedActions(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.celebration_rounded, color: AppColors.warning, size: 48),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(minimumSize: const Size(200, 56)),
          child: const Text('DISMISS'),
        ),
      ],
    );
  }

  Widget _buildFailedActions(BuildContext context) {
    return Column(
      children: [
        const Text('Something went wrong', style: TextStyle(color: AppColors.error)),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('BACK'),
        ),
      ],
    );
  }
}
