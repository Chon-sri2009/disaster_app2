import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../models/damage_report.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/warning_banner.dart';

// Report screen: a damage-report form (photo, GPS, category, note) and the saved reports.
class ReportScreen extends StatefulWidget {
  const ReportScreen({
    super.key,
    required this.storage,
    required this.location,
  });

  final StorageService storage;
  final LocationService location;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

// Holds the form fields: category, note, photo path and GPS position.
class _ReportScreenState extends State<ReportScreen> {
  static const _categories = [
    'Flooded road',
    'Damaged building',
    'No power',
    'No water',
  ];

  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _picker = ImagePicker();

  String? _category;
  String? _photoPath;
  LatLng? _point;
  String? _locationMessage;
  bool _locationIsError = false;
  bool _locating = false;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  // Shows a short message at the bottom of the screen.
  void _toast(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // Opens the camera or gallery; a missing permission or camera shows a message.
  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (!mounted || file == null) return;
      setState(() => _photoPath = file.path);
    } catch (_) {
      if (mounted) _toast('Could not open the camera or photo library.');
    }
  }

  // Reads GPS and stores the point (or the error) for the form.
  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final result = await widget.location.getCurrent();
    if (!mounted) return;
    setState(() {
      _locating = false;
      _point = result.point;
      _locationIsError = result.point == null;
      if (result.point == null) {
        _locationMessage = result.error;
      } else if (result.fromCache) {
        _locationMessage = 'GPS failed, using last saved position.';
      } else {
        _locationMessage = null;
      }
    });
  }

  // Validates the form, saves the report locally and clears the form.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final report = DamageReport(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      category: _category!,
      note: _noteController.text.trim(),
      createdAt: DateTime.now(),
      lat: _point?.latitude,
      lng: _point?.longitude,
      photoPath: _photoPath,
    );
    await widget.storage.addReport(report);
    if (!mounted) return;
    _formKey.currentState!.reset();
    setState(() {
      _category = null;
      _photoPath = null;
      _point = null;
      _locationMessage = null;
    });
    _toast('Report saved on this phone.');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: ContentWidth(
        child: ListenableBuilder(
          listenable: widget.storage,
          builder: (context, _) {
            final reports = widget.storage.reports;
            return ListView(
              padding: const EdgeInsets.all(AppSpace.md),
              children: [
                Text('Report damage', style: theme.textTheme.headlineMedium),
                const SizedBox(height: AppSpace.md),
                Form(key: _formKey, child: _buildForm()),
                const SizedBox(height: AppSpace.lg),
                Text(
                  'Saved reports (${reports.length})',
                  style: theme.textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpace.sm),
                if (reports.isEmpty)
                  const WarningBanner(
                    message:
                        'No reports yet. Reports you save are kept on this phone '
                        'and work without internet.',
                  ),
                for (final r in reports)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.sm),
                    child: _ReportTile(report: r),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  // Builds the form fields and buttons.
  Widget _buildForm() {
    final point = _point;
    final message = _locationMessage;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        DropdownButtonFormField<String>(
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in _categories)
              DropdownMenuItem(value: c, child: Text(c)),
          ],
          onChanged: (value) => _category = value,
          validator: (value) =>
              value == null ? 'Please choose a category' : null,
        ),
        const SizedBox(height: AppSpace.md),
        TextFormField(
          controller: _noteController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Note (optional)',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpace.md),
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          children: [
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera),
              label: const Text('Camera'),
            ),
            OutlinedButton.icon(
              onPressed: () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library),
              label: const Text('Gallery'),
            ),
            OutlinedButton.icon(
              onPressed: _locating ? null : _useLocation,
              icon: _locating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location),
              label: Text(_locating ? 'Finding location…' : 'Add location'),
            ),
          ],
        ),
        if (_photoPath != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.md),
            child: Semantics(
              image: true,
              label: 'Photo attached to this report',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.sm),
                child: Image.file(
                  File(_photoPath!),
                  height: 160,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stack) =>
                      const Icon(Icons.broken_image, size: 48),
                ),
              ),
            ),
          ),
        if (point != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: Text(
              'Location: ${point.latitude.toStringAsFixed(5)}, ${point.longitude.toStringAsFixed(5)}',
            ),
          ),
        if (message != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: WarningBanner(
              kind: _locationIsError ? BannerKind.error : BannerKind.offline,
              message: message,
            ),
          ),
        const SizedBox(height: AppSpace.md),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: const Text('Save report'),
          ),
        ),
      ],
    );
  }
}

// One saved report in the list, with a photo thumbnail when there is one.
class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final DamageReport report;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final photo = report.photoPath;
    final hasLocation = report.lat != null && report.lng != null;
    final lines = [
      if (report.note.isNotEmpty) report.note,
      report.createdAt.toString().substring(0, 16),
      if (hasLocation)
        '${report.lat!.toStringAsFixed(5)}, ${report.lng!.toStringAsFixed(5)}',
    ];
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.all(AppSpace.md),
        leading: photo == null
            ? Icon(Icons.report, size: 40, color: t.accent)
            : SizedBox(
                width: 56,
                height: 56,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                  child: Image.file(
                    File(photo),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.broken_image, size: 40),
                  ),
                ),
              ),
        title: Text(
          report.category,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        subtitle: Text(lines.join('\n')),
        isThreeLine: lines.length > 1,
      ),
    );
  }
}
