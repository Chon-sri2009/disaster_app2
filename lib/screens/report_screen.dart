import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/l10n.dart';
import '../models/damage_report.dart';
import '../services/location_service.dart';
import '../services/storage_service.dart';
import '../theme/app_tokens.dart';
import '../widgets/content_width.dart';
import '../widgets/notice_ui.dart';
import '../widgets/warning_banner.dart';
import 'settings_screen.dart';

// Report screen: a ruled damage-report form (category, note, photo, GPS) and the saved reports.
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
    final t = context.tokens;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: t.brightness == Brightness.light
          ? SystemUiOverlayStyle.dark
          : SystemUiOverlayStyle.light,
      // The title sits on the ground, so the status bar is inset; the nav bar is the Scaffold's.
      child: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: widget.storage,
          builder: (context, _) {
            final reports = widget.storage.reports;
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.md,
                0,
                AppSpace.md,
                AppSpace.lg,
              ),
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScreenTitle(
                      context.tr(th: 'แจ้งความเสียหาย', en: 'Report damage'),
                      trailing: SettingsButton(storage: widget.storage),
                      // Big text: a smaller title keeps the form in view.
                      compact: context.textScale > AppSize.compactTextScale,
                    ),
                    Form(key: _formKey, child: _buildForm()),
                    Section(
                      title: context.tr(
                        th: 'รายงานที่บันทึกไว้ (${reports.length})',
                        en: 'Saved reports (${reports.length})',
                      ),
                      children: [
                        if (reports.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.md),
                            child: WarningBanner(
                              kind: BannerKind.offline,
                              message: context.tr(
                                th:
                                    'ยังไม่มีรายงาน รายงานที่บันทึกจะเก็บไว้ในเครื่องนี้เท่านั้น '
                                    'ใช้ได้โดยไม่ต้องมีอินเทอร์เน็ต และยังไม่ได้ส่งให้ใคร',
                                en:
                                    'No reports yet. Reports you save stay on this phone only, '
                                    'work without internet, and are not sent to anyone yet.',
                              ),
                            ),
                          ),
                        for (final r in reports) _ReportRow(report: r),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // Builds the form: category rows, note, attachments, address, the "not sent" line, save.
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
          builder: (field) => Section(
            title: context.tr(th: 'ประเภท', en: 'Category'),
            children: [
              const SizedBox(height: AppSpace.md),
              for (final c in _categories.entries)
                _ChoiceRow(
                  icon: c.value.icon,
                  label: context.tr(th: c.value.th, en: c.value.en),
                  selected: field.value == c.key,
                  onTap: () {
                    field.didChange(c.key);
                    setState(() => _category = c.key);
                  },
                ),
              if (field.errorText != null)
                Row(
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
            ],
          ),
        ),
        Section(
          title: context.tr(th: 'รายละเอียด', en: 'Details'),
          children: [
            const SizedBox(height: AppSpace.md),
            _LabeledField(
              label: context.tr(
                th: 'หมายเหตุ (ไม่บังคับ)',
                en: 'Note (optional)',
              ),
              child: TextFormField(
                controller: _noteController,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(counterText: ''),
              ),
            ),
            const SizedBox(height: AppSpace.sm),
            Container(height: AppStroke.rule, color: t.hairline),
            RuledRow(
              icon: Icons.photo_camera,
              title: context.tr(th: 'ถ่ายรูป', en: 'Camera'),
              onTap: () => _pickPhoto(ImageSource.camera),
            ),
            RuledRow(
              icon: Icons.photo_library,
              title: context.tr(th: 'คลังภาพ', en: 'Gallery'),
              onTap: () => _pickPhoto(ImageSource.gallery),
            ),
            RuledRow(
              icon: point != null ? Icons.check : Icons.my_location,
              // While reading GPS the row shows a spinner instead of the icon.
              leading: _locating
                  ? const SizedBox(
                      width: AppIconSize.md,
                      height: AppIconSize.md,
                      child: CircularProgressIndicator(
                        strokeWidth: AppStroke.frame,
                      ),
                    )
                  : null,
              title: _locating
                  ? context.tr(th: 'กำลังหา…', en: 'Finding…')
                  : point != null
                  ? context.tr(th: 'มีตำแหน่งแล้ว', en: 'Location added')
                  : context.tr(th: 'เพิ่มตำแหน่ง', en: 'Add location'),
              onTap: _locating ? null : _useLocation,
            ),
            if (photo != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: t.hairline,
                      width: AppStroke.rule,
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.control),
                  ),
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
                          errorBuilder: (context, error, stack) =>
                              const SizedBox(
                                width: AppSize.photoPreview,
                                child: Icon(
                                  Icons.broken_image,
                                  size: AppIconSize.xl,
                                ),
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
                        tooltip: context.tr(
                          th: 'เอารูปออก',
                          en: 'Remove photo',
                        ),
                        onPressed: () => setState(() => _photoPath = null),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: AppSpace.md),
            _LabeledField(
              label: context.tr(
                th: 'ที่อยู่ (แก้ไขได้ หรือพิมพ์เอง)',
                en: 'Address (edit it or type your own)',
              ),
              child: TextFormField(
                controller: _addressController,
                textInputAction: TextInputAction.done,
                maxLines: 2,
                minLines: 1,
                maxLength: 200,
                decoration: InputDecoration(
                  counterText: '',
                  helperText: point == null
                      ? null
                      : context.tr(
                          th: 'ที่อยู่ใกล้ที่สุดจาก GPS ถ้าไม่ตรง กรุณาแก้ไข',
                          en: 'Closest address from GPS. Correct it if it is wrong.',
                        ),
                  prefixIcon: const Icon(Icons.home_outlined),
                ),
              ),
            ),
            if (message != null)
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.sm),
                child: WarningBanner(
                  kind: _locationIsError
                      ? BannerKind.error
                      : BannerKind.offline,
                  message: message,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.lg),
        // Said before saving, not only in the toast after: nobody receives a report.
        WarningBanner(
          message: context.tr(
            th: 'บันทึกในเครื่องนี้เท่านั้น ไม่มีใครได้รับแจ้ง', // DRAFT
            en: 'Saved on this phone only. No one is told.', // DRAFT
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

// An outlined input with its label written above it, so a long Thai label wraps in full at large
// text instead of being cut inside the field. The field is spoken with the same label.
class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ExcludeSemantics(
          child: Text(label, style: Theme.of(context).textTheme.titleSmall),
        ),
        const SizedBox(height: AppSpace.xs),
        Semantics(label: label, child: child),
      ],
    );
  }
}

// One category: a bordered 8 dp row with its icon and word. The chosen row takes a brand outline
// and a check icon, so the choice never rests on colour alone.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.selected,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final shape = BorderRadius.circular(AppRadius.control);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Semantics(
        button: true,
        selected: selected,
        inMutuallyExclusiveGroup: true,
        child: Material(
          type: MaterialType.transparency,
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: shape,
              border: Border.all(
                color: selected ? t.brand : t.hairline,
                width: selected ? AppStroke.frame : AppStroke.rule,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: shape,
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSize.primaryButton,
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.md,
                    vertical: AppSpace.sm,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: selected ? t.brand : t.mark),
                      const SizedBox(width: AppSpace.md),
                      Expanded(
                        child: Text(
                          label,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: AppSpace.sm),
                        Icon(Icons.check, color: t.brand),
                      ],
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
}

// One saved report in the list, with a photo thumbnail when there is one.
class _ReportRow extends StatelessWidget {
  const _ReportRow({required this.report});

  final DamageReport report;

  // Older reports saved the English name itself; show those as they are.
  static String _label(BuildContext context, String category) {
    final c = _ReportScreenState._categories[category];
    return c == null ? category : context.tr(th: c.th, en: c.en);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.tokens;
    final photo = report.photoPath;
    final category = _ReportScreenState._categories[report.category];
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: t.hairline, width: AppStroke.rule),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: AppSize.thumb,
              height: AppSize.thumb,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                border: Border.all(color: t.hairline, width: AppStroke.rule),
                borderRadius: BorderRadius.circular(AppRadius.control),
              ),
              child: photo == null
                  ? Icon(
                      category?.icon ?? Icons.report,
                      size: AppIconSize.lg,
                      color: t.mark,
                    )
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
      ),
    );
  }
}
