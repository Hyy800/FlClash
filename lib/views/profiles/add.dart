import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/pages/scan.dart';
import 'package:fl_clash/providers/action.dart';
import 'package:fl_clash/state.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AddProfileView extends StatelessWidget {
  final BuildContext context;

  const AddProfileView({super.key, required this.context});

  Future<void> _handleAddProfileFormFile() async {
    globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormFile();
  }

  Future<void> _handleAddProfileFormURL(String url, {String? userAgent}) async {
    globalState.container
        .read(profilesActionProvider.notifier)
        .addProfileFormURL(url, userAgent: userAgent);
  }

  Future<void> _toScan() async {
    if (system.isDesktop) {
      globalState.container
          .read(profilesActionProvider.notifier)
          .addProfileFormQrCode();
      return;
    }
    final url = await BaseNavigator.push(context, const ScanPage());
    if (url != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _handleAddProfileFormURL(url);
      });
    }
  }

  Future<void> _toAdd() async {
    final data = await globalState.showCommonDialog<AddProfileFormData>(
      child: const URLFormDialog(),
    );
    if (data != null) {
      _handleAddProfileFormURL(data.url, userAgent: data.userAgent);
    }
  }

  @override
  Widget build(context) {
    final appLocalizations = context.appLocalizations;
    return ListView(
      children: [
        ListItem(
          leading: const Icon(Icons.qr_code_sharp),
          title: Text(appLocalizations.qrcode),
          subtitle: Text(appLocalizations.qrcodeDesc),
          onTap: _toScan,
        ),
        ListItem(
          leading: const Icon(Icons.upload_file_sharp),
          title: Text(appLocalizations.file),
          subtitle: Text(appLocalizations.fileDesc),
          onTap: _handleAddProfileFormFile,
        ),
        ListItem(
          leading: const Icon(Icons.cloud_download_sharp),
          title: Text(appLocalizations.url),
          subtitle: Text(appLocalizations.urlDesc),
          onTap: _toAdd,
        ),
      ],
    );
  }
}

class AddProfileFormData {
  final String url;
  final String? userAgent;

  const AddProfileFormData({required this.url, this.userAgent});
}

class URLFormDialog extends StatefulWidget {
  const URLFormDialog({super.key});

  @override
  State<URLFormDialog> createState() => _URLFormDialogState();
}

class _URLFormDialogState extends State<URLFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  String _userAgent = '';

  Future<void> _handleAddProfileFormURL() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }
    Navigator.of(context).pop(
      AddProfileFormData(
        url: _urlController.text,
        userAgent: _userAgent.isEmpty ? null : _userAgent,
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    return CommonDialog(
      title: appLocalizations.importFromURL,
      actions: [
        TextButton(
          onPressed: _handleAddProfileFormURL,
          child: Text(appLocalizations.submit),
        ),
      ],
      child: Form(
        key: _formKey,
        child: SizedBox(
          width: 360,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                keyboardType: TextInputType.url,
                minLines: 1,
                maxLines: 5,
                inputFormatters: TextInputLimits.limit(TextInputLimits.url),
                onFieldSubmitted: (_) {
                  _handleAddProfileFormURL();
                },
                controller: _urlController,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return appLocalizations.emptyTip('').trim();
                  }
                  if (!value.isUrl) {
                    return appLocalizations.urlTip('').trim();
                  }
                  return null;
                },
                decoration: InputDecoration(labelText: appLocalizations.url),
              ),
              const SizedBox(height: 12),
              UserAgentSelector(
                value: _userAgent,
                onChanged: (value) => setState(() => _userAgent = value),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
