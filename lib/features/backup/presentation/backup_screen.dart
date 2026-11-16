import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hisab_pro/core/theme/design_tokens.dart';
import 'package:hisab_pro/features/backup/backup_providers.dart';
import 'package:hisab_pro/features/user_profiles/profile_providers.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _isLoading = false;
  String? _statusMessage;
  bool _isSuccess = false;

  Future<void> _handleExportBackup() async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final shouldExport = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Encrypted Backup'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a secure password for this backup file. You will need this exact password to restore your financial records.',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Backup Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val == null || val.length < 6) {
                      return 'Password must be at least 6 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (val) {
                    if (val != passwordController.text) {
                      return 'Passwords do not match';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Export Now', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldExport != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Encrypting and exporting backup...';
      _isSuccess = false;
    });

    try {
      final backupService = ref.read(backupServiceProvider);
      final file = await backupService.createEncryptedBackup(
        profileId: activeProfile.id,
        profileName: activeProfile.fullName,
        backupPassword: passwordController.text,
      );

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _statusMessage = 'Backup created successfully!\nSaved to: ${file.path}';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Backup exported and securely encrypted!'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Export failed: $e';
      });
    }
  }

  Future<void> _handleRestoreBackup() async {
    final activeProfile = ref.read(activeProfileProvider);
    if (activeProfile == null) return;

    final files = await FilePicker.pickFiles(
      dialogTitle: 'Select Hisab Pro Backup (.hisab)',
      type: FileType.custom,
      allowedExtensions: ['hisab', 'txt', 'bin'],
    );

    if (files.isEmpty || files.first.path == null) return;
    final selectedFile = File(files.first.path!);
    final fileContent = await selectedFile.readAsString();

    final passwordController = TextEditingController();
    bool createSafetyBackup = true;

    if (!mounted) return;

    final shouldRestore = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Restore Backup'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Enter the password used when this backup was exported:',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Backup Password',
                    prefixIcon: Icon(Icons.password),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                CheckboxListTile(
                  title: const Text('Create safety backup first'),
                  subtitle: const Text('Takes a backup of current data before overwriting'),
                  value: createSafetyBackup,
                  onChanged: (val) {
                    setDialogState(() {
                      createSafetyBackup = val ?? true;
                    });
                  },
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Verify & Restore', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );

    if (shouldRestore != true) return;

    setState(() {
      _isLoading = true;
      _statusMessage = 'Verifying and restoring database...';
      _isSuccess = false;
    });

    try {
      final backupService = ref.read(backupServiceProvider);
      final restoreResult = await backupService.restoreBackup(
        fileContent: fileContent,
        backupPassword: passwordController.text,
        currentProfileId: activeProfile.id,
        createSafetyBackup: createSafetyBackup,
      );

      setState(() {
        _isLoading = false;
        _isSuccess = true;
        _statusMessage = 'Restore Successful!\nRestored ${restoreResult['totalRecords']} total records for profile "${restoreResult['profileName']}".';
      });

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Restoration Complete'),
            content: Text(
              'Your financial database has been verified with PRAGMA integrity checks.\n\nTotal restored records: ${restoreResult['totalRecords']}.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isSuccess = false;
        _statusMessage = 'Restore failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeProfile = ref.watch(activeProfileProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Encrypted Backup & Restore'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              color: isDark ? AppColors.navy : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.security,
                            color: AppColors.emerald,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                '100% Offline & Authenticated',
                                style: AppTextStyles.title,
                              ),
                              Text(
                                'Profile: ${activeProfile?.fullName ?? "Active"}',
                                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hisab Pro backups are encrypted using keys derived via PBKDF2-HMAC-SHA256. Your data remains protected with tamper-evident HMAC authentication and database integrity verification.',
                      style: AppTextStyles.body,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Export Action Card
            Card(
              color: isDark ? AppColors.navy : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Export Encrypted Backup',
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Create an encrypted .hisab archive of all your accounts, transactions, loans, people, and budgets.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.upload_file, color: Colors.white),
                        label: Text(
                          _isLoading ? 'Processing...' : 'Export Backup File',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _handleExportBackup,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Restore Action Card
            Card(
              color: isDark ? AppColors.navy : Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Restore from Backup',
                      style: AppTextStyles.title,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Select a previously exported .hisab file and enter your backup password. An automatic safety backup will be created first.',
                      style: AppTextStyles.caption,
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.restore, color: AppColors.emerald),
                        label: const Text(
                          'Select & Restore Backup',
                          style: TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.emerald, width: 1.5),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _isLoading ? null : _handleRestoreBackup,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: (_isSuccess ? AppColors.success : AppColors.danger).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isSuccess ? AppColors.success : AppColors.danger,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                      color: _isSuccess ? AppColors.success : AppColors.danger,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isSuccess ? AppColors.success : AppColors.danger,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
