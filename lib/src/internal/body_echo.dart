/// Where a native body control keeps the value it reports, by node type.
const _reportedKey = {
  'toggle': 'value',
  'checkbox': 'value',
  'slider': 'value',
  'textField': 'text',
  'picker': 'selectedIndex',
  'segmented': 'selectedIndex',
};

/// Writes the value control [id] just reported into [node], an encoded body
/// as it was last sent, and says whether [id] was found.
///
/// The control already shows that value. The page usually hands it straight
/// back (`onBodyEvent` → `setState` → a new tree), and with the snapshot
/// brought up to date that echo encodes the same as what was sent, so it is
/// not sent again: a slider dragged in a native body used to send the whole
/// tree back on every frame.
bool adoptBodyEvent(Object? node, String id, Object? value) {
  if (node is! Map) return false;
  if (node['id'] == id) {
    final type = node['type'];
    final key = _reportedKey[type];
    final payload = node[type];
    if (key != null && payload is Map) payload[key] = value;
    return true;
  }
  final children = node['children'];
  if (children is! List) return false;
  return children.any((child) => adoptBodyEvent(child, id, value));
}
