import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../services/google_drive_service.dart';
import '../services/autostart_service.dart';
import '../providers/notes_provider.dart';
import '../widgets/color_picker.dart';
import 'archive_screen.dart';
import 'package:notizblock/l10n/generated/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app_info.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Kontaktadresse für Feedback/Fragen (unter „Über" anzeigt; mailto-Link).
  static const String _feedbackEmail = 'andi-w-apps@tuta.com';

  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  bool _autostartEnabled = false;

  bool get _isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  void initState() {
    super.initState();
    _loadLastSyncTime();
    _loadAutostart();
    // Login-Status kann sich asynchron ändern (stiller Login läuft seit der
    // Start-Optimierung NACH dem ersten Frame; außerdem Ab-/Anmelden) → neu
    // bauen, sobald sich der Status ändert.
    GoogleDriveService.instance.signedInNotifier.addListener(_onSignInChanged);
  }

  void _onSignInChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    GoogleDriveService.instance.signedInNotifier
        .removeListener(_onSignInChanged);
    super.dispose();
  }

  Future<void> _loadLastSyncTime() async {
    final lastSync = await GoogleDriveService.instance.getLastSyncTime();
    if (mounted) {
      setState(() {
        _lastSyncTime = lastSync;
      });
    }
  }

  Future<void> _loadAutostart() async {
    final enabled = await AutostartService.instance.isEnabled();
    if (mounted) {
      setState(() => _autostartEnabled = enabled);
    }
  }

  Future<void> _setAutostart(bool value) async {
    await AutostartService.instance.setEnabled(value);
    final enabled = await AutostartService.instance.isEnabled();
    if (mounted) {
      setState(() => _autostartEnabled = enabled);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsProvider>();
    final driveService = GoogleDriveService.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
      ),
      body: ListView(
        children: [
          // Sprache
          _buildSectionHeader(l10n.language),
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(l10n.language),
            subtitle: Text(
              SettingsProvider.getLanguageName(settings.locale.languageCode),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showLanguageDialog(context, settings, l10n),
          ),

          const Divider(),

          // Design
          _buildSectionHeader(l10n.theme),
          ListTile(
            leading: const Icon(Icons.brightness_6),
            title: Text(l10n.theme),
            subtitle: Text(_getThemeName(settings.themeMode, l10n)),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeDialog(context, settings, l10n),
          ),
          ListTile(
            leading: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: _parseColor(settings.defaultNoteColor),
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade300),
              ),
            ),
            title: Text(l10n.defaultColor),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showDefaultColorPicker(context, settings),
          ),

          // Schriftgröße der Notizen
          ListTile(
            leading: const Icon(Icons.format_size),
            title: Text(l10n.fontSize),
            subtitle: Text(
              l10n.fontSizeSample,
              style: TextStyle(fontSize: 14 * settings.noteFontScale),
            ),
            trailing: Text('${(settings.noteFontScale * 100).round()}%'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.text_decrease, size: 20),
                Expanded(
                  child: Slider(
                    min: 0.8,
                    max: 1.8,
                    divisions: 10,
                    value: settings.noteFontScale.clamp(0.8, 1.8),
                    label: '${(settings.noteFontScale * 100).round()}%',
                    onChanged: (v) =>
                        context.read<SettingsProvider>().setNoteFontScale(v),
                  ),
                ),
                const Icon(Icons.text_increase, size: 28),
              ],
            ),
          ),

          const Divider(),

          // Archiv & Wiederherstellen (archivierte + gelöschte Notizen)
          ListTile(
            leading: const Icon(Icons.unarchive_outlined),
            title: Text(l10n.archiveAndRestore),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ArchiveScreen()),
            ),
          ),

          const Divider(),

          // Desktop (Windows / Linux)
          if (_isDesktop) ...[
            _buildSectionHeader('Desktop'),
            SwitchListTile(
              secondary: const Icon(Icons.power_settings_new),
              title: Text(l10n.autostart),
              subtitle: Text(l10n.autostartSubtitle),
              value: _autostartEnabled,
              onChanged: _setAutostart,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.web_asset),
              title: Text(l10n.showMainWindow),
              subtitle: Text(l10n.showMainWindowSubtitle),
              value: settings.showMainWindowOnStart,
              onChanged: (v) =>
                  context.read<SettingsProvider>().setShowMainWindowOnStart(v),
            ),
            const Divider(),
          ],

          // Google Drive
          _buildSectionHeader(l10n.googleDrive),
          if (driveService.isSignedIn) ...[
            ListTile(
              leading: const Icon(Icons.account_circle),
              title: Text(l10n.signedInAs(driveService.userEmail ?? '')),
              subtitle: Text(driveService.userName ?? ''),
            ),
            ListTile(
              leading: const Icon(Icons.sync),
              title: Text(l10n.sync),
              subtitle: Text(
                _lastSyncTime != null
                    ? l10n.lastSync(_formatDateTime(_lastSyncTime!))
                    : l10n.neverSynced,
              ),
              trailing: _isSyncing
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: _isSyncing ? null : () => _synchronize(l10n),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.sync_alt),
              title: Text(l10n.autoSync),
              value: settings.autoSync,
              onChanged: (value) => settings.setAutoSync(value),
            ),
            ListTile(
              leading: const Icon(Icons.backup),
              title: Text(l10n.createBackup),
              onTap: () => _createBackup(l10n),
            ),
            ListTile(
              leading: const Icon(Icons.restore),
              title: Text(l10n.restoreBackup),
              onTap: () => _showRestoreDialog(l10n),
            ),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: Text(
                l10n.signOut,
                style: const TextStyle(color: Colors.red),
              ),
              onTap: () => _signOut(l10n),
            ),
          ] else
            ListTile(
              leading: const Icon(Icons.login),
              title: Text(l10n.signIn),
              subtitle: const Text('Google Drive'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _signIn(l10n),
            ),

          const Divider(),

          // Über
          _buildSectionHeader(l10n.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: Text(l10n.version),
            subtitle: Text(kAppVersionDisplay),
            // Easter Egg: Tippen auf die Version zeigt zwei Bibelverse.
            onTap: () => _showVersionVerses(l10n),
          ),
          // Ersteller
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: Text(l10n.creator),
            subtitle: const Text('Andreas Wurzer'),
          ),
          // Feedback & Kontakt (Tippen öffnet das Mailprogramm)
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(l10n.feedback),
            subtitle: const Text(_feedbackEmail),
            onTap: _sendFeedbackMail,
          ),
        ],
      ),
    );
  }

  // Easter Egg: zwei Bibelverse beim Tippen auf die Versionsanzeige.
  void _showVersionVerses(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.bibleVerse1Ref,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.bibleVerse1Text),
              const SizedBox(height: 20),
              Text(l10n.bibleVerse2Ref,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(l10n.bibleVerse2Text),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.close),
          ),
        ],
      ),
    );
  }

  // Mailprogramm mit der Feedback-Adresse öffnen; klappt das nicht, die Adresse
  // als Hinweis einblenden (zum Abschreiben).
  Future<void> _sendFeedbackMail() async {
    final uri = Uri(scheme: 'mailto', path: _feedbackEmail);
    var opened = false;
    try {
      opened = await launchUrl(uri);
    } catch (_) {
      opened = false;
    }
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(_feedbackEmail),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  String _getThemeName(ThemeMode mode, AppLocalizations l10n) {
    switch (mode) {
      case ThemeMode.system:
        return l10n.themeSystem;
      case ThemeMode.light:
        return l10n.themeLight;
      case ThemeMode.dark:
        return l10n.themeDark;
    }
  }

  Color _parseColor(String hexColor) {
    final hex = hexColor.replaceFirst('#', '');
    return Color(int.parse('FF$hex', radix: 16));
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('d. MMM yyyy, HH:mm', 'de').format(date);
  }

  void _showLanguageDialog(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(l10n.language),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SettingsProvider.supportedLocales.map((locale) {
            final isSelected = locale == settings.locale;
            return ListTile(
              title: Text(SettingsProvider.getLanguageName(locale.languageCode)),
              trailing: isSelected ? const Icon(Icons.check) : null,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              onTap: () {
                settings.setLocale(locale);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showThemeDialog(
    BuildContext context,
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(l10n.theme),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildThemeOption(
              context,
              l10n.themeSystem,
              Icons.brightness_auto,
              ThemeMode.system,
              settings,
            ),
            _buildThemeOption(
              context,
              l10n.themeLight,
              Icons.light_mode,
              ThemeMode.light,
              settings,
            ),
            _buildThemeOption(
              context,
              l10n.themeDark,
              Icons.dark_mode,
              ThemeMode.dark,
              settings,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption(
    BuildContext context,
    String title,
    IconData icon,
    ThemeMode mode,
    SettingsProvider settings,
  ) {
    final isSelected = settings.themeMode == mode;
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      trailing: isSelected ? const Icon(Icons.check) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      onTap: () {
        settings.setThemeMode(mode);
        Navigator.pop(context);
      },
    );
  }

  void _showDefaultColorPicker(BuildContext context, SettingsProvider settings) async {
    final newColor = await showColorPickerSheet(
      context,
      currentColor: settings.defaultNoteColor,
    );
    if (newColor != null) {
      settings.setDefaultNoteColor(newColor);
    }
  }

  Future<void> _signIn(AppLocalizations l10n) async {
    final success = await GoogleDriveService.instance.signIn();
    if (mounted) {
      setState(() {});
      if (!success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.syncFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _signOut(AppLocalizations l10n) async {
    await GoogleDriveService.instance.signOut();
    if (mounted) {
      setState(() {
        _lastSyncTime = null;
      });
    }
  }

  Future<void> _synchronize(AppLocalizations l10n) async {
    setState(() {
      _isSyncing = true;
    });

    final result = await GoogleDriveService.instance.synchronize();

    if (mounted) {
      setState(() {
        _isSyncing = false;
      });

      await _loadLastSyncTime();

      if (result.success) {
        context.read<NotesProvider>().refreshNotes();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${l10n.syncSuccess} - ${l10n.uploaded(result.uploadedCount)}, ${l10n.downloaded(result.downloadedCount)}',
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${l10n.syncFailed}: ${result.message}'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 8),
          ),
        );
      }
    }
  }

  Future<void> _createBackup(AppLocalizations l10n) async {
    final success = await GoogleDriveService.instance.createBackup();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.backupSuccess : l10n.backupFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showRestoreDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(l10n.restoreBackup),
        content: Text(l10n.restoreConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _restoreBackup(l10n);
            },
            child: Text(l10n.restore),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup(AppLocalizations l10n) async {
    final success = await GoogleDriveService.instance.restoreBackup();
    if (mounted) {
      if (success) {
        context.read<NotesProvider>().refreshNotes();
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? l10n.restoreSuccess : l10n.restoreFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
