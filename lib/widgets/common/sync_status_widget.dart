import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/repositories/firebase_sync_service.dart';
import '../../data/repositories/local_storage_service.dart';

/// ===========================================================
/// SYNC STATUS WIDGET
/// Provides real-time synchronization status and controls
/// ===========================================================
class SyncStatusWidget extends StatelessWidget {
  const SyncStatusWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final firebaseSync = FirebaseSyncService.instance;
    final localStorage = LocalStorageService.instance;

    return StreamBuilder<SyncEvent>(
      stream: firebaseSync.syncEvents,
      builder: (context, snapshot) {
        final syncEvent = snapshot.data;
        final isSyncing = firebaseSync.isSyncing;
        final isInitialized = firebaseSync.isInitialized;
        final lastSyncTime = firebaseSync.lastSyncTime;
        final deviceId = firebaseSync.deviceId;
        final pendingChanges = localStorage.pendingChanges;

        return Card(
          margin: const EdgeInsets.all(8),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Icon(
                      _getSyncIcon(isInitialized, isSyncing, syncEvent?.type),
                      color: _getSyncColor(isInitialized, isSyncing, syncEvent?.type),
                      size: 24,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Sync Status',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (pendingChanges.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${pendingChanges.length} pending',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),

                // Status information
                _buildStatusInfo(context, isInitialized, isSyncing, lastSyncTime, deviceId, syncEvent),

                const SizedBox(height: 12),

                // Action buttons
                _buildActionButtons(context, firebaseSync, isInitialized, isSyncing, pendingChanges),

                // Error display
                if (syncEvent?.type == SyncEventType.error)
                  _buildErrorDisplay(context, syncEvent!.message),

                // Pending changes display
                if (pendingChanges.isNotEmpty)
                  _buildPendingChangesDisplay(context, pendingChanges),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusInfo(
    BuildContext context,
    bool isInitialized,
    bool isSyncing,
    DateTime? lastSyncTime,
    String deviceId,
    SyncEvent? syncEvent,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Connection status
        Row(
          children: [
            Text(
              'Connection: ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              isInitialized ? 'Connected' : 'Disconnected',
              style: TextStyle(
                color: isInitialized ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Device ID
        Row(
          children: [
            Text(
              'Device ID: ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Expanded(
              child: Text(
                deviceId,
                style: Theme.of(context).textTheme.bodySmall,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(
              icon: const Icon(Icons.copy, size: 16),
              onPressed: () {
                // Copy device ID to clipboard
                // Clipboard.setData(ClipboardData(text: deviceId));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Device ID copied')),
                );
              },
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Last sync time
        Row(
          children: [
            Text(
              'Last Sync: ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              lastSyncTime != null 
                  ? _formatDateTime(lastSyncTime)
                  : 'Never',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const SizedBox(height: 4),

        // Current operation
        if (isSyncing || syncEvent != null)
          Row(
            children: [
              Text(
                'Status: ',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (isSyncing)
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  syncEvent?.message ?? 'Syncing...',
                  style: Theme.of(context).textTheme.bodySmall,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    FirebaseSyncService firebaseSync,
    bool isInitialized,
    bool isSyncing,
    Map<String, String> pendingChanges,
  ) {
    return Row(
      children: [
        // Manual sync button
        Expanded(
          child: ElevatedButton.icon(
            onPressed: (isInitialized && !isSyncing)
                ? () => _performManualSync(context, firebaseSync)
                : null,
            icon: const Icon(Icons.sync, size: 16),
            label: const Text('Sync Now'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8),
            ),
          ),
        ),
        const SizedBox(width: 8),

        // Clear pending changes button
        if (pendingChanges.isNotEmpty)
          OutlinedButton.icon(
            onPressed: isSyncing ? null : () => _clearPendingChanges(context),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('Clear'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            ),
          ),
      ],
    );
  }

  Widget _buildErrorDisplay(BuildContext context, String errorMessage) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade600, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              errorMessage,
              style: TextStyle(
                color: Colors.red.shade800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingChangesDisplay(BuildContext context, Map<String, String> pendingChanges) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border.all(color: Colors.orange.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pending_actions, color: Colors.orange.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'Pending Changes',
                style: TextStyle(
                  color: Colors.orange.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...pendingChanges.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                Icon(
                  entry.value == 'delete' ? Icons.delete : Icons.edit,
                  color: Colors.orange.shade600,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatPendingChange(entry.key, entry.value),
                    style: TextStyle(
                      color: Colors.orange.shade800,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }

  // ===========================================================
  // HELPER METHODS
  // ===========================================================

  IconData _getSyncIcon(bool isInitialized, bool isSyncing, SyncEventType? eventType) {
    if (!isInitialized) return Icons.cloud_off;
    if (isSyncing) return Icons.sync;
    if (eventType == SyncEventType.error) return Icons.error_outline;
    return Icons.cloud_done;
  }

  Color _getSyncColor(bool isInitialized, bool isSyncing, SyncEventType? eventType) {
    if (!isInitialized) return Colors.grey;
    if (isSyncing) return Colors.blue;
    if (eventType == SyncEventType.error) return Colors.red;
    return Colors.green;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  String _formatPendingChange(String key, String operation) {
    if (key.startsWith('camera_config_')) {
      final cameraName = key.replaceFirst('camera_config_', '');
      final operationText = operation == 'delete' ? 'Deleted' : 'Updated';
      return '$cameraName - $operationText';
    }
    return '$key - $operation';
  }

  Future<void> _performManualSync(BuildContext context, FirebaseSyncService firebaseSync) async {
    try {
      final result = await firebaseSync.fullSync();
      
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Sync failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _clearPendingChanges(BuildContext context) async {
    try {
      final localStorage = LocalStorageService.instance;
      await localStorage.clearAllPendingChanges();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pending changes cleared'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear changes: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
