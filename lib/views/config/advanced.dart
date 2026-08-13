import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/views/config/dns.dart';
import 'package:fl_clash/views/config/network.dart';
import 'package:fl_clash/views/config/on_demand.dart';
import 'package:fl_clash/views/config/scripts.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';

class AdvancedConfigView extends StatelessWidget {
  const AdvancedConfigView({super.key});

  @override
  Widget build(BuildContext context) {
    final appLocalizations = context.appLocalizations;
    final List<Widget> items = [
      ListItem.open(
        title: Text(appLocalizations.network),
        subtitle: Text(appLocalizations.networkDesc),
        leading: const Icon(Icons.vpn_key),
        delegate: OpenDelegate(
          blur: false,
          widget: BaseScaffold(
            title: appLocalizations.network,
            body: const NetworkListView(),
          ),
        ),
      ),
      ListItem.open(
        title: Text(appLocalizations.onDemand),
        subtitle: Text(appLocalizations.onDemandDesc),
        leading: const Icon(Icons.ssid_chart, fontWeight: FontWeight.w900),
        delegate: const OpenDelegate(widget: OnDemandView(), blur: false),
      ),
      ListItem.open(
        title: const Text('DNS'),
        subtitle: Text(appLocalizations.dnsDesc),
        leading: const Icon(Icons.dns),
        delegate: const OpenDelegate(widget: DnsSettingsView(), blur: false),
      ),
      ListItem.open(
        title: Text(appLocalizations.script),
        subtitle: Text(appLocalizations.overrideScript),
        leading: const Icon(Icons.rocket, fontWeight: FontWeight.w900),
        delegate: const OpenDelegate(widget: ScriptsView(), blur: false),
      ),
    ];
    return BaseScaffold(
      title: appLocalizations.advancedConfig,
      body: SettingsPageLayout(
        children: [
          SettingsSection(
            title: appLocalizations.advancedConfig,
            description: appLocalizations.advancedConfigDesc,
            icon: Icons.settings_input_component_outlined,
            children: items,
          ),
        ],
      ),
    );
  }
}
