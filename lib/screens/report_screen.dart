import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../models/damage_report.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/soft_ui.dart';
import '../widgets/warning_banner.dart';
import 'settings_screen.dart';

// Report screen: a damage-report form (category, note, photo, GPS) and the saved reports.
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
  // Reports store the key, so a report keeps its meaning if the language is switched later.
  static const _categories = {
    'flooded_road': (th: 'ถนนน้ำท่วม', en: 'Flooded road', icon: Icons.flood),
    'damaged_building': (
      th: 'อาคารเสียหาย',
      en: 'Damaged building',
      icon: Icons.domain_disabled,
    ),
    'no_power': (th: 'ไฟฟ้าดับ', en: 'No power', icon: Icons.power_off),
    'no_water': (
      th: 'น้ำประปาไม่ไหล',
      en: 'No water',
      icon: Icons.format_color_reset,
    ),
  };

  final _formKey = GlobalKey<FormState>();
  final _noteController = TextEditingController();
  final _addressController = TextEditingController();
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
    _addressController.dispose();
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
      if (mounted) {
        _toast(
          context.tr(
            th: 'เปิดกล้องหรือคลังภาพไม่ได้',
            en: 'Could not open the camera or photo library.',
          ),
        );
      }
    }
  }

  // Reads GPS and stores the point (or the error) for the form.
  Future<void> _useLocation() async {
    setState(() => _locating = true);
    final result = await widget.location.getCurrent();
    if (!mounted) return;
    final point = result.point;
    // The address is only a suggestion: the person can correct it or type their own below.
    final place = point == null ? null : await widget.location.describe(point);
    if (!mounted) return;
    if (place != null && !place.isEmpty) {
      _addressController.text = context.placeText(place);
    }
    setState(() {
      _locating = false;
      _point = result.point;
      _locationIsError = result.point == null;
      if (result.point == null) {
        _locationMessage = context.locationError(result.issue!);
      } else if (result.fromCache) {
        _locationMessage = context.tr(
          th: 'อ่าน GPS ไม่สำเร็จ ใช้ตำแหน่งที่บันทึกไว้ล่าสุดแทน',
          en: 'GPS failed, using last saved position.',
        );
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
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      photoPath: _photoPath,
    );
    await widget.storage.addReport(report);
    if (!mounted) return;
    _formKey.currentState!.reset();
    _noteController.clear();
    _addressController.clear();
    setState(() {
      _category = null;
      _photoPath = null;
      _point = null;
      _locationMessage = null;
    });
    _toast(
      context.tr(
        th: 'บันทึกรายงานในเครื่องแล้ว (ยังไม่ได้ส่งให้ใคร)',
        en: 'Report saved on this phone (not sent to anyone yet).',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListenableBuilder(
        listenable: widget.storage,
        builder: (context, _) {
          final reports = widget.storage.reports;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              BrandHeader(
                title: context.tr(th: 'แจ้งความเสียหาย', en: 'Report damage'),
                trailing: SettingsButton(storage: widget.storage),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpace.md,
                    0,
                    AppSpace.md,
                    AppSpace.lg,
                  ),
                  children: [
                    ContentWidth(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Form(key: _formKey, child: _buildForm()),
                          SectionLabel(
                            context.tr(
                              th: 'รายงานที่บันทึกไว้ (${reports.length})',
                              en: 'Saved reports (${reports.length})',
                            ),
                          ),
                          if (reports.isEmpty)
                            WarningBanner(
                              message: context.tr(
                                th:
                                    'ยังไม่มีรายงาน รายงานที่บันทึกจะเก็บไว้ในเครื่องนี้เท่านั้น '
                                    'ใช้ได้โดยไม่ต้องมีอินเทอร์เน็ต และยังไม่ได้ส่งให้ใคร',
                                en:
                                    'No reports yet. Reports you save stay on this phone only, '
                                    'work without internet, and are not sent to anyone yet.',
                              ),
                            ),
                          for (final r in reports)
                            Padding(
                              padding: const EdgeInsets.only(
                                bottom: AppSpace.sm,
                              ),
                              child: _ReportTile(report: r),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Builds the form: category tiles, note, attachments, save.
  Widget _buildForm() {
    final theme = Theme.of(context);
    final t = context.tokens;
    final point = _point;
    final message = _locationMessage;
    final photo = _photoPath;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FormField<String>(
          validator: (value) => value == null
              ? context.tr(
                  th: 'กรุณาเลือกประเภท',
                  en: 'Please choose a category',
                )
              : null,
          builder: (field) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(context.tr(th: 'ประเภท', en: 'Category')),
              _TileGrid(
                children: [
                  for (final c in _categories.entries)
                    _ChoiceTile(
                      icon: c.value.icon,
                      label: context.tr(th: c.value.th, en: c.value.en),
                      selected: field.value == c.key,
                      onTap: () {
                        field.didChange(c.key);
                        setState(() => _category = c.key);
                      },
                    ),
                ],
              ),
              if (field.errorText != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppSpace.sm),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: t.dangerInk,
                        size: AppIconSize.sm,
                      ),
                      const SizedBox(width: AppSpace.xs),
                      Expanded(
                        child: Text(
                          field.errorText!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: t.dangerInk,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        SectionLabel(context.tr(th: 'รายละเอียด', en: 'Details')),
        TextFormField(
          controller: _noteController,
          maxLines: 3,
          maxLength: 500,
          decoration: InputDecoration(
            counterText: '',
            labelText: context.tr(
              th: 'หมายเหตุ (ไม่บังคับ)',
              en: 'Note (optional)',
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _ChoiceTile(
                  icon: Icons.photo_camera,
                  label: context.tr(th: 'ถ่ายรูป', en: 'Camera'),
                  onTap: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _ChoiceTile(
                  icon: Icons.photo_library,
                  label: context.tr(th: 'คลังภาพ', en: 'Gallery'),
                  onTap: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Expanded(
                child: _ChoiceTile(
                  icon: point != null ? Icons.check : Icons.my_location,
                  label: _locating
                      ? context.tr(th: 'กำลังหา…', en: 'Finding…')
                      : point != null
                      ? context.tr(th: 'มีตำแหน่งแล้ว', en: 'Location added')
                      : context.tr(th: 'เพิ่มตำแหน่ง', en: 'Add location'),
                  busy: _locating,
                  onTap: _locating ? null : _useLocation,
                ),
              ),
            ],
          ),
        ),
        if (photo != null)
          Padding(
            padding: const EdgeInsets.only(top: AppSpace.sm),
            child: SoftCard(
              padding: EdgeInsets.zero,
              child: Row(
                children: [
                  Semantics(
                    image: true,
                    label: context.tr(
                      th: 'รูปที่แนบกับรายงานนี้',
                      en: 'Photo attached to this report',
                    ),
                    child: Image.file(
                      File(photo),
                      width: AppSize.photoPreview,
                      height: AppSize.photoPreview * 0.75,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => const SizedBox(
                        width: AppSize.photoPreview,
                        child: Icon(Icons.broken_image, size: AppIconSize.xl),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpace.sm),
                      child: Text(
                        context.tr(th: 'แนบรูปแล้ว', en: 'Photo attached'),
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: context.tr(th: 'เอารูปออก', en: 'Remove photo'),
                    onPressed: () => setState(() => _photoPath = null),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppSpace.sm),
        TextFormField(
          controller: _addressController,
          textInputAction: TextInputAction.done,
          maxLines: 2,
          minLines: 1,
          maxLength: 200,
          decoration: InputDecoration(
            counterText: '',
            labelText: context.tr(
              th: 'ที่อยู่ (แก้ไขได้ หรือพิมพ์เอง)',
              en: 'Address (edit it or type your own)',
            ),
            helperText: point == null
                ? null
                : context.tr(
                    th: 'ที่อยู่ใกล้ที่สุดจาก GPS ถ้าไม่ตรง กรุณาแก้ไข',
                    en: 'Closest address from GPS. Correct it if it is wrong.',
                  ),
            prefixIcon: const Icon(Icons.home_outlined),
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
        FilledButton.icon(
          onPressed: _save,
          icon: const Icon(Icons.save),
          label: Text(context.tr(th: 'บันทึกรายงาน', en: 'Save report')),
        ),
      ],
    );
  }
}

// Two framed tiles per row, rows of equal height.
class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i += 2) ...[
          if (i > 0) const SizedBox(height: AppSpace.sm),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: children[i]),
                const SizedBox(width: AppSpace.sm),
                Expanded(
                  child: i + 1 < children.length
                      ? children[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

// A framed tile with an icon over its label; a selected tile turns into an ink block.
class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool selected;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final fg = selected ? t.ground : t.ink;
    return SoftTile(
      selected: selected,
      onTap: onTap,
      padding: const EdgeInsets.all(AppSpace.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (busy)
            const SizedBox.square(
              dimension: AppIconSize.md,
              child: CircularProgressIndicator(strokeWidth: AppStroke.frame),
            )
          else
            Icon(selected ? Icons.check_box : icon, color: fg),
          const SizedBox(height: AppSpace.xs),
          Text(
            label,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fg),
          ),
        ],
      ),
    );
  }
}

// One saved report in the list, with a photo thumbnail when there is one.
class _ReportTile extends StatelessWidget {
  const _ReportTile({required this.report});

  final DamageReport report;

  // Older reports saved the English name itself; show those as they are.
  static String _label(BuildContext context, String category) {
    final c = _ReportScreenState._categories[category];
    return c == null ? category : context.tr(th: c.th, en: c.en);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final photo = report.photoPath;
    final category = _ReportScreenState._categories[report.category];
    return SoftCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox.square(
            dimension: AppSize.thumb,
            child: photo == null
                ? Icon(category?.icon ?? Icons.report, size: AppIconSize.lg)
                : Image.file(
                    File(photo),
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stack) =>
                        const Icon(Icons.broken_image, size: AppIconSize.lg),
                  ),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _label(context, report.category),
                  style: theme.textTheme.titleSmall,
                ),
                if (report.note.isNotEmpty)
                  Text(report.note, style: theme.textTheme.bodyMedium),
                Text(
                  [
                    context.stamp(report.createdAt),
                    if (report.address != null) report.address!,
                  ].join(' · '),
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
