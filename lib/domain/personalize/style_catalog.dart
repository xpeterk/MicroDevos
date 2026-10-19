class StyleProfile {
  const StyleProfile({
    required this.key,
    required this.label,
    required this.blurb,
    required this.kind,
  });

  final String key;
  final String label;
  final String blurb;
  final String kind;

  bool get isClassic => kind == 'classic';
}

/// Reader-facing catalog. Matches the style_profiles seed.
/// generation_notes is not in the app.
const styleCatalog = <StyleProfile>[
  StyleProfile(
    key: 'purpose',
    label: 'Purpose & practical living',
    blurb: 'short, numbered steps',
    kind: 'style',
  ),
  StyleProfile(
    key: 'invitation',
    label: 'Good news & invitation',
    blurb: 'clear, hopeful call to faith',
    kind: 'style',
  ),
  StyleProfile(
    key: 'healing',
    label: 'Healing & faith',
    blurb: 'bold confidence in God\'s promises',
    kind: 'style',
  ),
  StyleProfile(
    key: 'grace',
    label: 'Grace & the Spirit',
    blurb: 'rest in grace, spiritual gifts',
    kind: 'style',
  ),
  StyleProfile(
    key: 'bible',
    label: 'Bible on the go',
    blurb: 'quick, conversational teaching',
    kind: 'style',
  ),
  StyleProfile(
    key: 'spurgeon',
    label: 'C. H. Spurgeon',
    blurb: 'vivid, warm, rich imagery',
    kind: 'classic',
  ),
  StyleProfile(
    key: 'murray',
    label: 'Andrew Murray',
    blurb: 'quiet, prayer-centered depth',
    kind: 'classic',
  ),
  StyleProfile(
    key: 'meyer',
    label: 'F. B. Meyer',
    blurb: 'devotional, character-focused',
    kind: 'classic',
  ),
  StyleProfile(
    key: 'henry',
    label: 'Matthew Henry',
    blurb: 'plain verse commentary',
    kind: 'classic',
  ),
];

StyleProfile? styleByKey(String key) {
  for (final style in styleCatalog) {
    if (style.key == key) return style;
  }
  return null;
}

const suggestedTopics = [
  'Anxiety',
  'Patience',
  'Gratitude',
  'New job',
  'Forgiveness',
  'Waiting',
  'Grief',
  'Marriage',
];

const lifeSituationChoices = [
  'Parenting',
  'Caregiving',
  'Work',
  'Student',
  'Grief',
  'Retirement',
];
