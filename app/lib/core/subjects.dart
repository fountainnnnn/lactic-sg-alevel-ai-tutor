/// Canonical A-Level subject catalogue, grouped by level. Single source of truth
/// shared by onboarding (subjects_screen) and the profile editor (edit_profile)
/// so the two pickers never drift apart. Subjects a student can take vary by the
/// level they take them at (e.g. General Paper at H1, Further Mathematics at H2).
library;

const subjectLevels = ['H1', 'H2', 'H3'];

const subjectsByLevel = <String, List<String>>{
  'H1': ['General Paper', 'Mathematics', 'Physics', 'Chemistry', 'Biology', 'Economics', 'Geography', 'History', 'Literature (Eng)'],
  'H2': ['Mathematics', 'Further Mathematics', 'Physics', 'Chemistry', 'Biology', 'Economics', 'Geography', 'History', 'Literature (Eng)', 'Computing'],
  'H3': ['Mathematics', 'Physics', 'Chemistry', 'Biology', 'Economics', 'History', 'Geography', 'Literature (Eng)'],
};

/// Every distinct subject name across all levels — for detecting which subjects a
/// saved profile already has, regardless of level tag.
final allSubjectNames = subjectsByLevel.values.expand((e) => e).toSet();
