/// App-wide constants for COUGHFEE.
library;

/// Menu category labels (matches CATS in HTML reference).
const List<String> kCategories = [
  'All',
  'Hot Coffee',
  'Iced Coffee',
  'Non-Coffee',
  'Pastries',
  'Merch',
];

/// Drink size options: [label, price delta].
const List<(String, int)> kSizes = [
  ('Small', -15),
  ('Medium', 0),
  ('Large', 25),
];

/// Milk options: [label, price delta].
const List<(String, int)> kMilks = [
  ('Whole', 0),
  ('Oat', 30),
  ('Almond', 30),
  ('Soy', 20),
];

/// Sugar level options.
const List<String> kSugarLevels = ['0%', '25%', '50%', '75%', '100%'];

/// Ice level options.
const List<String> kIceLevels = ['No ice', 'Less', 'Regular'];

/// Add-on options: [label, price].
const List<(String, int)> kAddons = [
  ('Extra shot', 40),
  ('Vanilla syrup', 25),
  ('Caramel syrup', 25),
  ('Whipped cream', 20),
];

/// Order status steps (matches STEPS in HTML reference).
const List<String> kOrderSteps = [
  'received',
  'preparing',
  'ready',
  'completed',
];

/// Human-readable labels for order statuses (matches LABEL in HTML reference).
const Map<String, String> kOrderLabels = {
  'received': 'Received',
  'preparing': 'Preparing',
  'ready': 'Ready for pickup',
  'completed': 'Completed',
};


