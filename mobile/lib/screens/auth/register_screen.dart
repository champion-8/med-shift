import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/locale/app_localizations.dart';
import '../../core/theme/app_theme.dart';
import '../../providers/auth_provider.dart';

enum _PayoutMethod { bookbank, promptPay }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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

  final _formKeys = List.generate(6, (_) => GlobalKey<FormState>());
  int _step = 0;
  bool _isLoading = false;

  // Account
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

  // Personal
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _laserCodeController = TextEditingController();

  // Professional
  String _profession = 'Nurse';
  final _licenseController = TextEditingController();
  DateTime? _licenseExpiry;

  // Payout
  _PayoutMethod _payoutMethod = _PayoutMethod.bookbank;
  String? _selectedBankName;
  final _bankAccountNumberController = TextEditingController();
  final _bankAccountNameController = TextEditingController();
  final _promptPayController = TextEditingController();

  // Documents (local picks → upload after register)
  XFile? _nationalIdDoc;
  XFile? _selfieDoc;
  XFile? _licenseDoc;
  XFile? _bookbankDoc;
  XFile? _promptPayQrDoc;
  XFile? _nameChangeDoc;

  final _picker = ImagePicker();

  int get _totalSteps => _needsNameChangeProof ? 6 : 5;

  bool get _needsNameChangeProof {
    if (_payoutMethod != _PayoutMethod.bookbank) return false;
    final account = _bankAccountNameController.text.trim();
    if (account.isEmpty) return false;
    return !_namesMatch(
      _firstNameController.text,
      _lastNameController.text,
      account,
    );
  }

  static bool _namesMatch(String first, String last, String account) {
    String norm(String s) =>
        s.trim().toLowerCase().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).join(' ');
    return norm(account) == norm('$first $last');
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _nationalIdController.dispose();
    _laserCodeController.dispose();
    _licenseController.dispose();
    _bankAccountNumberController.dispose();
    _bankAccountNameController.dispose();
    _promptPayController.dispose();
    super.dispose();
  }

  Future<void> _pickDoc(void Function(XFile file) assign) async {
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 2000,
    );
    if (file != null) setState(() => assign(file));
  }

  String? _required(String? v) {
    if (v == null || v.trim().isEmpty) return context.tr('required_field');
    return null;
  }

  bool _validateCurrentStep() {
    final key = _formKeys[_step];
    if (key.currentState != null && !key.currentState!.validate()) return false;

    switch (_step) {
      case 2:
        if (_nationalIdDoc == null) {
          _toast(context.tr('reg_need_id_photo'));
          return false;
        }
        if (_selfieDoc == null) {
          _toast(context.tr('reg_need_selfie'));
          return false;
        }
        return true;
      case 3:
        if (_licenseExpiry == null) {
          _toast(context.tr('reg_need_license_expiry'));
          return false;
        }
        if (_licenseDoc == null) {
          _toast(context.tr('reg_need_license_photo'));
          return false;
        }
        return true;
      case 4:
        if (_payoutMethod == _PayoutMethod.bookbank) {
          if (_selectedBankName == null || _selectedBankName!.isEmpty) {
            _toast(context.tr('reg_need_bank'));
            return false;
          }
          if (_bookbankDoc == null) {
            _toast(context.tr('reg_need_bookbank'));
            return false;
          }
        } else if (_promptPayController.text.trim().isEmpty) {
          _toast(context.tr('reg_need_promptpay'));
          return false;
        }
        return true;
      case 5:
        if (_needsNameChangeProof && _nameChangeDoc == null) {
          _toast(context.tr('reg_need_name_change'));
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppTheme.warningColor),
    );
  }

  void _next() {
    if (!_validateCurrentStep()) return;
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _submit();
    }
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() => _step--);
  }

  Future<void> _submit() async {
    if (!_validateCurrentStep()) return;
    setState(() => _isLoading = true);

    final auth = context.read<AuthProvider>();
    final verified = _payoutMethod == _PayoutMethod.bookbank &&
        _namesMatch(
          _firstNameController.text,
          _lastNameController.text,
          _bankAccountNameController.text,
        );

    final ok = await auth.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      firstName: _firstNameController.text.trim(),
      lastName: _lastNameController.text.trim(),
      phone: _phoneController.text.trim().isEmpty
          ? null
          : _phoneController.text.trim(),
      profession: _profession,
      licenseNumber: _licenseController.text.trim(),
      nationalId: _nationalIdController.text.trim(),
      licenseExpiryDate: _licenseExpiry,
      laserCode: _laserCodeController.text.trim(),
      bankName: _payoutMethod == _PayoutMethod.bookbank ? _selectedBankName : null,
      bankAccountNumber: _payoutMethod == _PayoutMethod.bookbank
          ? _bankAccountNumberController.text.trim()
          : null,
      bankAccountName: _payoutMethod == _PayoutMethod.bookbank
          ? _bankAccountNameController.text.trim()
          : null,
      bankAccountVerified: verified,
      promptPayId: _payoutMethod == _PayoutMethod.promptPay
          ? _promptPayController.text.trim()
          : null,
    );

    if (!mounted) return;

    if (!ok) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(auth.errorMessage ?? context.tr('register_failed')),
          backgroundColor: AppTheme.errorColor,
        ),
      );
      return;
    }

    final uploads = <MapEntry<String, XFile>>[
      MapEntry('NationalId', _nationalIdDoc!),
      MapEntry('Selfie', _selfieDoc!),
      MapEntry('NursingLicense', _licenseDoc!),
      if (_payoutMethod == _PayoutMethod.bookbank && _bookbankDoc != null)
        MapEntry('BookBank', _bookbankDoc!),
      if (_payoutMethod == _PayoutMethod.promptPay && _promptPayQrDoc != null)
        MapEntry('PromptPayQr', _promptPayQrDoc!),
      if (_needsNameChangeProof && _nameChangeDoc != null)
        MapEntry('NameChangeProof', _nameChangeDoc!),
    ];

    for (final entry in uploads) {
      final file = entry.value;
      List<int>? bytes;
      String? path;
      if (kIsWeb) {
        bytes = await file.readAsBytes();
      } else {
        path = file.path;
      }
      final uploaded = await auth.uploadStaffDocument(
        documentType: entry.key,
        fileName: file.name,
        filePath: path,
        bytes: bytes,
      );
      if (!uploaded && mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              auth.errorMessage ?? context.tr('reg_doc_upload_failed'),
            ),
            backgroundColor: AppTheme.errorColor,
          ),
        );
        return;
      }
    }

    if (!mounted) return;
    setState(() => _isLoading = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.tr('register_success_pending')),
        backgroundColor: AppTheme.successColor,
      ),
    );
    // Session already saved — pop to AuthWrapper root.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _pickExpiry() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _licenseExpiry ?? now.add(const Duration(days: 365)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _licenseExpiry = picked);
  }

  @override
  Widget build(BuildContext context) {
    final titles = [
      context.tr('register_step_account'),
      context.tr('register_step_personal'),
      context.tr('reg_step_identity'),
      context.tr('register_step_professional'),
      context.tr('reg_step_payout'),
      if (_needsNameChangeProof) context.tr('reg_step_name_change'),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(context.tr('register_title')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _isLoading ? null : _back,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${context.tr('reg_step_of')} ${_step + 1}/$_totalSteps',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.textSecondaryColor,
                        ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (_step + 1) / _totalSteps,
                    minHeight: 4,
                    backgroundColor: AppTheme.dividerColor,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    titles[_step.clamp(0, titles.length - 1)],
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AbsorbPointer(
                absorbing: _isLoading,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                  child: Form(
                    key: _formKeys[_step],
                    child: _buildStep(),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_step > 0)
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isLoading ? null : _back,
                        child: Text(context.tr('reg_back')),
                      ),
                    ),
                  if (_step > 0) const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _next,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              _step == _totalSteps - 1
                                  ? context.tr('register_btn')
                                  : context.tr('reg_next'),
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

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _buildAccountStep();
      case 1:
        return _buildPersonalStep();
      case 2:
        return _buildIdentityStep();
      case 3:
        return _buildProfessionalStep();
      case 4:
        return _buildPayoutStep();
      default:
        return _buildNameChangeStep();
    }
  }

  Widget _buildAccountStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('register_subtitle'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
        const SizedBox(height: 24),
        TextFormField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: InputDecoration(
            labelText: context.tr('login_email'),
            prefixIcon: const Icon(Icons.email_outlined),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return context.tr('required_field');
            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
              return context.tr('login_email_invalid');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _passwordController,
          obscureText: !_isPasswordVisible,
          decoration: InputDecoration(
            labelText: context.tr('login_password'),
            hintText: context.tr('register_password_hint'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
              ),
              onPressed: () =>
                  setState(() => _isPasswordVisible = !_isPasswordVisible),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return context.tr('required_field');
            if (value.length < 6) return context.tr('register_password_min');
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _confirmPasswordController,
          obscureText: !_isConfirmPasswordVisible,
          decoration: InputDecoration(
            labelText: context.tr('register_confirm_password'),
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              icon: Icon(
                _isConfirmPasswordVisible
                    ? Icons.visibility_off
                    : Icons.visibility,
              ),
              onPressed: () => setState(
                () => _isConfirmPasswordVisible = !_isConfirmPasswordVisible,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: (value) {
            if (value != _passwordController.text) {
              return context.tr('register_password_mismatch');
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPersonalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _firstNameController,
          decoration: InputDecoration(
            labelText: context.tr('register_first_name'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: _required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _lastNameController,
          decoration: InputDecoration(
            labelText: context.tr('register_last_name'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: _required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _phoneController,
          keyboardType: TextInputType.phone,
          decoration: InputDecoration(
            labelText: context.tr('register_phone'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: _required,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nationalIdController,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(13),
          ],
          decoration: InputDecoration(
            labelText: context.tr('reg_national_id'),
            hintText: context.tr('reg_national_id_hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: (v) {
            if (v == null || v.length != 13) {
              return context.tr('reg_national_id_invalid');
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _laserCodeController,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            labelText: context.tr('reg_laser_code'),
            hintText: context.tr('reg_laser_code_hint'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: _required,
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('reg_manual_entry_hint'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
      ],
    );
  }

  Widget _buildIdentityStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('reg_identity_hint'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
        const SizedBox(height: 16),
        _docTile(
          label: context.tr('reg_doc_national_id'),
          file: _nationalIdDoc,
          onPick: () => _pickDoc((f) => _nationalIdDoc = f),
        ),
        const SizedBox(height: 12),
        _docTile(
          label: context.tr('reg_doc_selfie'),
          file: _selfieDoc,
          onPick: () => _pickDoc((f) => _selfieDoc = f),
        ),
      ],
    );
  }

  Widget _buildProfessionalStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _profession,
          decoration: InputDecoration(
            labelText: context.tr('reg_profession'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          items: [
            DropdownMenuItem(value: 'Nurse', child: Text(context.tr('reg_prof_nurse'))),
            DropdownMenuItem(value: 'Doctor', child: Text(context.tr('reg_prof_doctor'))),
            DropdownMenuItem(value: 'Other', child: Text(context.tr('reg_prof_other'))),
          ],
          onChanged: (v) => setState(() => _profession = v ?? 'Nurse'),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _licenseController,
          decoration: InputDecoration(
            labelText: context.tr('register_license'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          ),
          validator: _required,
        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: _pickExpiry,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: context.tr('reg_license_expiry'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
              suffixIcon: const Icon(Icons.calendar_today),
            ),
            child: Text(
              _licenseExpiry == null
                  ? context.tr('reg_pick_date')
                  : '${_licenseExpiry!.day}/${_licenseExpiry!.month}/${_licenseExpiry!.year}',
            ),
          ),
        ),
        const SizedBox(height: 16),
        _docTile(
          label: context.tr('reg_doc_license'),
          file: _licenseDoc,
          onPick: () => _pickDoc((f) => _licenseDoc = f),
        ),
        const SizedBox(height: 8),
        Text(
          context.tr('reg_tnmc_hint'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
      ],
    );
  }

  Widget _buildPayoutStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('reg_payout_hint'),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
        const SizedBox(height: 12),
        SegmentedButton<_PayoutMethod>(
          segments: [
            ButtonSegment(
              value: _PayoutMethod.bookbank,
              label: Text(context.tr('reg_payout_bookbank')),
              icon: const Icon(Icons.account_balance),
            ),
            ButtonSegment(
              value: _PayoutMethod.promptPay,
              label: Text(context.tr('reg_payout_promptpay')),
              icon: const Icon(Icons.qr_code),
            ),
          ],
          selected: {_payoutMethod},
          onSelectionChanged: (s) => setState(() => _payoutMethod = s.first),
        ),
        const SizedBox(height: 20),
        if (_payoutMethod == _PayoutMethod.bookbank) ...[
          DropdownButtonFormField<String>(
            value: _bankOptions.contains(_selectedBankName)
                ? _selectedBankName
                : null,
            decoration: InputDecoration(
              labelText: context.tr('bank_name'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            items: _bankOptions
                .map((b) => DropdownMenuItem(value: b, child: Text(b)))
                .toList(),
            onChanged: (v) => setState(() => _selectedBankName = v),
            validator: (v) =>
                v == null || v.isEmpty ? context.tr('required_field') : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bankAccountNumberController,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              labelText: context.tr('bank_account_no'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            validator: _required,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _bankAccountNameController,
            decoration: InputDecoration(
              labelText: context.tr('bank_account_name'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            onChanged: (_) => setState(() {}),
            validator: _required,
          ),
          if (_bankAccountNameController.text.trim().isNotEmpty &&
              !_namesMatch(
                _firstNameController.text,
                _lastNameController.text,
                _bankAccountNameController.text,
              )) ...[
            const SizedBox(height: 8),
            Text(
              context.tr('reg_name_mismatch_hint'),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.warningColor,
                  ),
            ),
          ],
          const SizedBox(height: 16),
          _docTile(
            label: context.tr('reg_doc_bookbank'),
            file: _bookbankDoc,
            onPick: () => _pickDoc((f) => _bookbankDoc = f),
          ),
        ] else ...[
          TextFormField(
            controller: _promptPayController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.tr('reg_promptpay_id'),
              hintText: context.tr('reg_promptpay_hint'),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
            ),
            validator: _required,
          ),
          const SizedBox(height: 16),
          _docTile(
            label: context.tr('reg_doc_promptpay_qr'),
            file: _promptPayQrDoc,
            optional: true,
            onPick: () => _pickDoc((f) => _promptPayQrDoc = f),
          ),
        ],
      ],
    );
  }

  Widget _buildNameChangeStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('reg_name_change_body'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        _docTile(
          label: context.tr('reg_doc_name_change'),
          file: _nameChangeDoc,
          onPick: () => _pickDoc((f) => _nameChangeDoc = f),
        ),
        const SizedBox(height: 24),
        Text(
          context.tr('reg_review_pending'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.textSecondaryColor,
              ),
        ),
      ],
    );
  }

  Widget _docTile({
    required String label,
    required XFile? file,
    required VoidCallback onPick,
    bool optional = false,
  }) {
    return Material(
      color: AppTheme.surfaceColor,
      child: InkWell(
        onTap: onPick,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.dividerColor),
          ),
          child: Row(
            children: [
              Icon(
                file != null ? Icons.check_circle : Icons.upload_file_outlined,
                color: file != null
                    ? AppTheme.successColor
                    : AppTheme.primaryColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      optional ? '$label (${context.tr('optional')})' : label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    Text(
                      file?.name ?? context.tr('reg_tap_to_upload'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.textSecondaryColor,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
