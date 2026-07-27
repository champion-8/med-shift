import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../core/locale/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../models/staff_profile_model.dart';
import '../../models/skill_model.dart';
import '../../providers/auth_provider.dart';
import '../../utils/smart_route_helper.dart';

class EditProfileScreen extends StatefulWidget {
  final StaffProfileModel profile;

  const EditProfileScreen({super.key, required this.profile});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _specialtyController;
  late TextEditingController _licenseController;
  late TextEditingController _nationalIdController;

  List<SkillModel> _skills = [];
  bool _isLoading = false;
  bool _isUploadingPhoto = false;
  Uint8List? _localPreviewBytes;

  // Bank account fields
  String? _selectedBankName;
  late TextEditingController _bankAccountNumberController;
  late TextEditingController _bankAccountNameController;
  bool _bankAccountVerified = false;
  double? _currentLocationLat;
  double? _currentLocationLng;
  bool _isLocating = false;

  static const _bankOptions = [
    'ธนาคารกสิกรไทย',
    'ธนาคารกรุงเทพ',
    'ธนาคารกรุงไทย',
    'ธนาคารไทยพาณิชย์',
    'ธนาคารกรุงศรีอยุธยา',
    'ธนาคารออมสิน',
    'ธนาคารทหารไทยธนชาต',
    'ธนาคารอาคารสงเคราะห์',
  ];

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(
      text: widget.profile.firstName,
    );
    _lastNameController = TextEditingController(text: widget.profile.lastName);
    _phoneController = TextEditingController(text: widget.profile.phone);
    _specialtyController = TextEditingController(
      text: widget.profile.specialty,
    );
    _licenseController = TextEditingController(
      text: widget.profile.licenseNumber,
    );
    _nationalIdController = TextEditingController(
      text: widget.profile.nationalId ?? '',
    );
    _selectedBankName = widget.profile.bankName;
    _bankAccountNumberController = TextEditingController(
      text: widget.profile.bankAccountNumber ?? '',
    );
    _bankAccountNameController = TextEditingController(
      text: widget.profile.bankAccountName ?? '',
    );
    _bankAccountVerified = widget.profile.bankAccountVerified;
    _currentLocationLat = widget.profile.currentLocationLat;
    _currentLocationLng = widget.profile.currentLocationLng;

    // Prefer rich skills from profile
    _skills = List<SkillModel>.from(widget.profile.skills);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _specialtyController.dispose();
    _licenseController.dispose();
    _nationalIdController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    super.dispose();
  }

  List<SkillModel> _generateMockSkills() {
    return [
      SkillModel(
        id: 'skill-001',
        name: 'ฉีดยา',
        minRate: 300,
        maxRate: 300,
        yearsExperience: 5,
        isVerified: true,
        certification: 'BLS',
      ),
      SkillModel(
        id: 'skill-002',
        name: 'การดูแลผู้สูงอายุ',
        minRate: 250,
        maxRate: 250,
        yearsExperience: 3,
        isVerified: true,
      ),
      SkillModel(
        id: 'skill-003',
        name: 'เจาะเลือด',
        minRate: 200,
        maxRate: 200,
        yearsExperience: 4,
        isVerified: false,
      ),
      SkillModel(
        id: 'skill-004',
        name: 'ใส่สายสวนปัสสาวะ',
        minRate: 350,
        maxRate: 350,
        yearsExperience: 2,
        isVerified: true,
        certification: 'ACLS',
      ),
    ];
  }

  Future<void> _pickAndUploadPhoto() async {
    if (_isUploadingPhoto) return;

    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null || !mounted) return;

    final bytes = await picked.readAsBytes();
    if (!mounted) return;

    setState(() {
      _localPreviewBytes = bytes;
      _isUploadingPhoto = true;
    });

    final auth = context.read<AuthProvider>();
    final ok = await auth.uploadProfileImage(
      fileName: picked.name.isNotEmpty ? picked.name : 'profile.jpg',
      filePath: picked.path,
      bytes: bytes,
    );

    if (!mounted) return;

    setState(() {
      _isUploadingPhoto = false;
      if (ok) _localPreviewBytes = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.tr('profile_photo_ok')
              : (auth.errorMessage ?? context.tr('profile_photo_fail')),
        ),
        backgroundColor: ok ? AppTheme.successColor : AppTheme.errorColor,
      ),
    );
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    final updated = widget.profile.copyWith(
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim(),
      specialty: _specialtyController.text.trim(),
      licenseNumber: _licenseController.text.trim(),
      nationalId: _nationalIdController.text.trim().isEmpty
          ? null
          : _nationalIdController.text.trim(),
      bankName: _selectedBankName,
      bankAccountNumber: _bankAccountNumberController.text.trim().isEmpty
          ? null
          : _bankAccountNumberController.text.trim(),
      bankAccountName: _bankAccountNameController.text.trim().isEmpty
          ? null
          : _bankAccountNameController.text.trim(),
      bankAccountVerified: _bankAccountVerified,
      currentLocationLat: _currentLocationLat,
      currentLocationLng: _currentLocationLng,
      skills: List<SkillModel>.from(_skills),
      updatedAt: DateTime.now(),
    );

    final ok = await context.read<AuthProvider>().updateProfile(updated);

    if (!mounted) return;

    setState(() => _isLoading = false);

    if (!ok) {
      final err = context.read<AuthProvider>().errorMessage;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err ?? context.tr('error')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('success')),
        backgroundColor: AppTheme.successColor,
      ),
    );

    Navigator.pop(context);
  }

  Future<void> _captureCurrentLocation() async {
    setState(() => _isLocating = true);
    final position = await SmartRouteHelper.getCurrentLocation();
    if (!mounted) return;
    setState(() => _isLocating = false);

    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('profile_location_denied')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    setState(() {
      _currentLocationLat = position.latitude;
      _currentLocationLng = position.longitude;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('profile_location_saved')),
        backgroundColor: AppTheme.successColor,
      ),
    );
  }

  void _verifyBankAccount() {
    // Validate fields first
    if (_selectedBankName == null || _selectedBankName!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('bank_no_bank')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (_bankAccountNumberController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('bank_no_number')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }
    if (_bankAccountNameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('bank_no_name')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final profileFullName =
        '${_firstNameController.text.trim()} ${_lastNameController.text.trim()}';
    final bankName = _bankAccountNameController.text.trim();
    if (bankName.toLowerCase() == profileFullName.toLowerCase()) {
      setState(() => _bankAccountVerified = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.tr('profile_bank_verified_snack')),
          backgroundColor: AppTheme.successColor,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            context.trParams('profile_bank_name_mismatch', {'name': profileFullName}),
          ),
          backgroundColor: AppTheme.errorColor,
        ),
      );
    }
  }

  void _addSkill() {
    showDialog(
      context: context,
      builder: (context) => AddSkillDialog(
        onAdd: (skill) {
          setState(() {
            _skills.add(skill);
          });
        },
      ),
    );
  }

  void _editSkill(int index) {
    showDialog(
      context: context,
      builder: (context) => EditSkillDialog(
        skill: _skills[index],
        onSave: (updatedSkill) {
          setState(() {
            _skills[index] = updatedSkill;
          });
        },
      ),
    );
  }

  void _deleteSkill(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Icon(Icons.delete_outline, color: AppTheme.errorColor),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(context.tr('skill_delete'))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.tr('skill_delete_confirm_full')),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorColor.withOpacity(0.06),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3), width: 1.5),
              ),
              child: Row(
                children: [
                  const Icon(Icons.work_outline,
                      size: 18, color: AppTheme.errorColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _skills[index].name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('cancel')),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _skills.removeAt(index);
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.errorColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  child: Text(context.tr('delete')),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('profile_edit')),
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveProfile,
              tooltip: context.tr('save'),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Profile Photo Section
            Center(
              child: Stack(
                children: [
                  Builder(
                    builder: (context) {
                      final live = context.watch<AuthProvider>().currentUser;
                      final networkUrl =
                          live?.resolvedProfileImageUrl ??
                              widget.profile.resolvedProfileImageUrl;
                      final ImageProvider? bg = _localPreviewBytes != null
                          ? MemoryImage(_localPreviewBytes!)
                          : (networkUrl != null
                              ? NetworkImage(networkUrl)
                              : null);

                      return CircleAvatar(
                        radius: 50,
                        backgroundColor:
                            AppTheme.primaryColor.withOpacity(0.1),
                        backgroundImage: bg,
                        child: _isUploadingPhoto
                            ? const SizedBox(
                                width: 28,
                                height: 28,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : (bg == null
                                ? const Icon(
                                    Icons.person,
                                    size: 50,
                                    color: AppTheme.primaryColor,
                                  )
                                : null),
                      );
                    },
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.camera_alt, size: 20),
                        color: Colors.white,
                        onPressed:
                            _isUploadingPhoto ? null : _pickAndUploadPhoto,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Basic Information
            _buildSectionTitle(context, context.tr('profile_personal')),
            const SizedBox(height: 16),

            TextFormField(
              controller: _firstNameController,
              decoration: InputDecoration(
                labelText: context.tr('profile_first_name'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('profile_required_first_name');
                }
                return null;
              },
            ),

            const SizedBox(height: 16),
            TextFormField(
              controller: _lastNameController,
              decoration: InputDecoration(
                labelText: context.tr('profile_last_name'),
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('profile_required_last_name');
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _phoneController,
              decoration: InputDecoration(
                labelText: context.tr('profile_phone'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone_outlined),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('profile_required_phone');
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _nationalIdController,
              decoration: InputDecoration(
                labelText: context.tr('profile_national_id'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card_outlined),
                hintText: 'x-xxxx-xxxxx-xx-x',
                counterText: '',
              ),
              keyboardType: TextInputType.number,
              maxLength: 13,
              validator: (value) {
                if (value != null && value.isNotEmpty && value.length != 13) {
                  return context.tr('profile_national_id_invalid');
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _specialtyController,
              decoration: InputDecoration(
                labelText: context.tr('profile_specialty'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.medical_services_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('profile_required_specialty');
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            TextFormField(
              controller: _licenseController,
              decoration: InputDecoration(
                labelText: context.tr('profile_license'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return context.tr('profile_required_license');
                }
                return null;
              },
            ),

            const SizedBox(height: 32),

            // Skills Section
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    context.tr('skill_section'),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _addSkill,
                  icon: const Icon(Icons.add, size: 20),
                  label: Text(context.tr('add')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            if (_skills.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: AppTheme.textSecondaryColor.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.work_outline,
                      size: 48,
                      color: AppTheme.textSecondaryColor.withOpacity(0.5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      context.tr('skill_no_skills'),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.tr('skill_no_skills_sub'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              )
            else
              ...List.generate(_skills.length, (index) {
                final skill = _skills[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header: icon + (name + verified badge) + menu
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  Text(
                                    skill.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                    ),
                                  ),
                                  if (skill.isVerified) ...[
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor
                                            .withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.verified,
                                              size: 12,
                                              color: AppTheme.successColor),
                                          const SizedBox(width: 4),
                                          Text(
                                            context.tr('profile_verified'),
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: AppTheme.successColor,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            PopupMenuButton<String>(
                              padding: EdgeInsets.zero,
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: Row(children: [
                                    const Icon(Icons.edit, size: 20),
                                    const SizedBox(width: 8),
                                    Text(context.tr('edit')),
                                  ]),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Row(children: [
                                    const Icon(Icons.delete,
                                        size: 20,
                                        color: AppTheme.errorColor),
                                    const SizedBox(width: 8),
                                    Text(context.tr('delete'),
                                        style: const TextStyle(
                                            color: AppTheme.errorColor)),
                                  ]),
                                ),
                              ],
                              onSelected: (value) {
                                if (value == 'edit') {
                                  _editSkill(index);
                                } else if (value == 'delete') {
                                  _deleteSkill(index);
                                }
                              },
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        // Info rows (each on its own line)
                        Row(
                          children: [
                            const Icon(Icons.attach_money,
                                size: 14, color: AppTheme.textSecondaryColor),
                            const SizedBox(width: 4),
                            Text(skill.rateLabel(context.tr, trParams: context.trParams),
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today,
                                size: 14, color: AppTheme.textSecondaryColor),
                            const SizedBox(width: 4),
                            Text('${context.tr('skill_experience_prefix')} ${skill.experienceLabel(context.tr, trParams: context.trParams)}',
                                style: const TextStyle(fontSize: 13)),
                          ],
                        ),
                        if (skill.certification != null) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.card_membership,
                                  size: 14,
                                  color: AppTheme.textSecondaryColor),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(skill.certification!,
                                    style: const TextStyle(fontSize: 13)),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),

            const SizedBox(height: 32),

            // Bank Account Section
            _buildSectionTitle(context, context.tr('bank_title')),
            const SizedBox(height: 8),
            Text(
              context.tr('profile_bank_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _bankOptions.contains(_selectedBankName)
                  ? _selectedBankName
                  : null,
              decoration: InputDecoration(
                labelText: context.tr('bank_name'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.account_balance),
              ),
              items: _bankOptions
                  .map(
                    (b) => DropdownMenuItem(value: b, child: Text(b)),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedBankName = v;
                  _bankAccountVerified = false;
                });
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankAccountNumberController,
              decoration: InputDecoration(
                labelText: context.tr('bank_account_no'),
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.credit_card),
                hintText: 'xxx-x-xxxxx-x',
              ),
              keyboardType: TextInputType.number,
              onChanged: (_) {
                if (_bankAccountVerified) {
                  setState(() => _bankAccountVerified = false);
                }
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _bankAccountNameController,
              decoration: InputDecoration(
                labelText: context.tr('bank_account_name'),
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.badge_outlined),
                hintText: context.tr('profile_bank_name_hint'),
                suffixIcon: _bankAccountVerified
                    ? const Icon(Icons.verified, color: AppTheme.successColor)
                    : null,
              ),
              textCapitalization: TextCapitalization.words,
              onChanged: (_) {
                if (_bankAccountVerified) {
                  setState(() => _bankAccountVerified = false);
                }
              },
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _verifyBankAccount,
              icon: Icon(
                _bankAccountVerified ? Icons.verified : Icons.fact_check_outlined,
                size: 18,
              ),
              label: Text(
                _bankAccountVerified
                    ? context.tr('bank_verified_btn')
                    : context.tr('profile_verify_name_btn'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: _bankAccountVerified
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
                side: BorderSide(
                  color: _bankAccountVerified
                      ? AppTheme.successColor
                      : AppTheme.primaryColor,
                  width: 1.5,
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Current location (for job distance filter)
            _buildSectionTitle(context, context.tr('profile_location')),
            const SizedBox(height: 8),
            Text(
              context.tr('profile_location_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.textSecondaryColor,
                  ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.textSecondaryColor.withOpacity(0.25),
                ),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    _currentLocationLat != null
                        ? Icons.location_on
                        : Icons.location_off_outlined,
                    color: _currentLocationLat != null
                        ? AppTheme.successColor
                        : AppTheme.textSecondaryColor,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _currentLocationLat != null &&
                              _currentLocationLng != null
                          ? '${_currentLocationLat!.toStringAsFixed(5)}, ${_currentLocationLng!.toStringAsFixed(5)}'
                          : context.tr('profile_location_none'),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _isLocating ? null : _captureCurrentLocation,
              icon: _isLocating
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.my_location, size: 18),
              label: Text(
                _isLocating ? context.tr('profile_location_reading') : context.tr('profile_location_use'),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryColor,
                side: const BorderSide(color: AppTheme.primaryColor, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(context.tr('profile_save')),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// Dialog for adding new skill
class AddSkillDialog extends StatefulWidget {
  final Function(SkillModel) onAdd;
  const AddSkillDialog({super.key, required this.onAdd});
  @override
  State<AddSkillDialog> createState() => _AddSkillDialogState();
}
class _AddSkillDialogState extends State<AddSkillDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _minRateController = TextEditingController();
  final _yearsController = TextEditingController(text: '0');
  final _certController = TextEditingController();
  @override
  void dispose() {
    _nameController.dispose();
    _minRateController.dispose();
    _yearsController.dispose();
    _certController.dispose();
    super.dispose();
  }
  void _save() {
    if (_formKey.currentState!.validate()) {
      final rate = double.parse(_minRateController.text);
      final skill = SkillModel(
        id: 'skill-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameController.text,
        minRate: rate,
        maxRate: rate,
        yearsExperience: int.parse(_yearsController.text),
        certification:
            _certController.text.isEmpty ? null : _certController.text,
      );
      widget.onAdd(skill);
      Navigator.pop(context);
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Icon(Icons.add_circle_outline,
                color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(context.tr('skill_add'))),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('skill_name'),
                  hintText: context.tr('skill_name_hint'),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.tr('skill_required_name');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minRateController,
                decoration: InputDecoration(
                  labelText: context.tr('skill_min_rate'),
                  suffixText: '฿/ชม.',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.tr('skill_rate_required');
                  }
                  final rate = int.tryParse(value);
                  if (rate == null || rate <= 0) {
                    return context.tr('skill_rate_positive');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearsController,
                decoration: InputDecoration(
                  labelText: context.tr('skill_experience'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.tr('skill_required_experience');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _certController,
                decoration: InputDecoration(
                  labelText: context.tr('skill_cert'),
                  hintText: context.tr('skill_cert_hint'),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(context.tr('cancel')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(context.tr('add')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
// Dialog for editing existing skill
class EditSkillDialog extends StatefulWidget {
  final SkillModel skill;
  final Function(SkillModel) onSave;
  const EditSkillDialog({
    super.key,
    required this.skill,
    required this.onSave,
  });
  @override
  State<EditSkillDialog> createState() => _EditSkillDialogState();
}
class _EditSkillDialogState extends State<EditSkillDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _minRateController;
  late TextEditingController _yearsController;
  late TextEditingController _certController;
  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.skill.name);
    final rate = widget.skill.minRate > 0
        ? widget.skill.minRate
        : widget.skill.maxRate;
    _minRateController = TextEditingController(
      text: rate > 0 ? rate.toInt().toString() : '',
    );
    _yearsController = TextEditingController(
      text: widget.skill.yearsExperience.toString(),
    );
    _certController = TextEditingController(
      text: widget.skill.certification ?? '',
    );
  }
  @override
  void dispose() {
    _nameController.dispose();
    _minRateController.dispose();
    _yearsController.dispose();
    _certController.dispose();
    super.dispose();
  }
  void _save() {
    if (_formKey.currentState!.validate()) {
      final rate = double.parse(_minRateController.text);
      final updatedSkill = widget.skill.copyWith(
        name: _nameController.text,
        minRate: rate,
        maxRate: rate,
        yearsExperience: int.parse(_yearsController.text),
        certification:
            _certController.text.isEmpty ? null : _certController.text,
      );
      widget.onSave(updatedSkill);
      Navigator.pop(context);
    }
  }
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child:
                const Icon(Icons.edit_outlined, color: AppTheme.primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(context.tr('skill_edit'))),
        ],
      ),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: context.tr('skill_name'),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.tr('skill_required_name');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _minRateController,
                decoration: InputDecoration(
                  labelText: context.tr('skill_min_rate'),
                  suffixText: '฿/ชม.',
                  border: const OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.tr('skill_rate_required');
                  }
                  final rate = int.tryParse(value);
                  if (rate == null || rate <= 0) {
                    return context.tr('skill_rate_positive');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _yearsController,
                decoration: InputDecoration(
                  labelText: context.tr('skill_experience'),
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return context.tr('skill_required_experience');
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _certController,
                decoration: InputDecoration(
                  labelText: context.tr('skill_cert'),
                  hintText: context.tr('skill_cert_hint'),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: const BorderSide(color: AppTheme.primaryColor, width: 2),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(context.tr('cancel')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text(context.tr('save')),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
