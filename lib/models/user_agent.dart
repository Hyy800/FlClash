class UserAgentPreset {
  final String id;
  final String name;
  final String value;

  const UserAgentPreset({
    required this.id,
    required this.name,
    required this.value,
  });

  factory UserAgentPreset.fromJson(Map<String, dynamic> json) {
    return UserAgentPreset(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      value: json['value'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'value': value};

  UserAgentPreset copyWith({String? name, String? value}) {
    return UserAgentPreset(
      id: id,
      name: name ?? this.name,
      value: value ?? this.value,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is UserAgentPreset &&
        other.id == id &&
        other.name == name &&
        other.value == value;
  }

  @override
  int get hashCode => Object.hash(id, name, value);
}

const builtInUserAgentPresets = [
  UserAgentPreset(
    id: 'builtin-clash-verge',
    name: 'Clash Verge',
    value: 'clash-verge/v2.4.2',
  ),
  UserAgentPreset(
    id: 'builtin-clash-for-windows',
    name: 'Clash for Windows',
    value: 'ClashforWindows/0.19.23',
  ),
];
