import '../models/menu_item.dart';

const defaultDrinkOptions = MenuOptions(
  sizes: [
    SizeOption(label: 'Small', delta: -15.0),
    SizeOption(label: 'Medium', delta: 0.0),
    SizeOption(label: 'Large', delta: 25.0),
  ],
  milks: [
    MilkOption(label: 'Whole', delta: 0.0),
    MilkOption(label: 'Oat', delta: 30.0),
    MilkOption(label: 'Almond', delta: 30.0),
    MilkOption(label: 'Soy', delta: 20.0),
  ],
  sugar: ['0%', '25%', '50%', '75%', '100%'],
  ice: ['No ice', 'Less', 'Regular'],
  addOns: [
    AddOnOption(label: 'Extra shot', price: 40.0),
    AddOnOption(label: 'Vanilla syrup', price: 25.0),
    AddOnOption(label: 'Caramel drizzle', price: 25.0),
  ],
);

final List<MenuItem> kDefaultMenuItems = [
  const MenuItem(
    id: 'spanish-latte',
    name: 'Spanish Latte',
    category: 'Hot Coffee',
    description: 'Rich espresso blended with velvety condensed milk and steamed fresh milk.',
    basePrice: 140.0,
    options: defaultDrinkOptions,
  ),
  const MenuItem(
    id: 'iced-spanish-latte',
    name: 'Iced Spanish Latte',
    category: 'Iced Coffee',
    description: 'Signature espresso over sweet condensed milk, served over crisp ice.',
    basePrice: 150.0,
    options: defaultDrinkOptions,
  ),
  const MenuItem(
    id: 'caramel-macchiato',
    name: 'Caramel Macchiato',
    category: 'Hot Coffee',
    description: 'Freshly steamed milk with vanilla-flavored syrup marked with espresso and caramel drizzle.',
    basePrice: 155.0,
    options: defaultDrinkOptions,
  ),
  const MenuItem(
    id: 'cold-brew',
    name: 'Signature Cold Brew',
    category: 'Iced Coffee',
    description: 'Steeped for 18 hours in cold filtered water for a naturally sweet, ultra-smooth profile.',
    basePrice: 130.0,
    options: defaultDrinkOptions,
  ),
  const MenuItem(
    id: 'americano',
    name: 'Caffe Americano',
    category: 'Hot Coffee',
    description: 'Espresso shots topped with hot water create a light layer of crema with deep body.',
    basePrice: 110.0,
    options: defaultDrinkOptions,
  ),
  const MenuItem(
    id: 'matcha-latte',
    name: 'Uji Matcha Latte',
    category: 'Non-Coffee',
    description: 'Ceremonial grade Japanese green tea matcha whisked with creamy steamed milk.',
    basePrice: 145.0,
    options: defaultDrinkOptions,
  ),
  const MenuItem(
    id: 'butter-croissant',
    name: 'French Butter Croissant',
    category: 'Pastries',
    description: 'Golden, flaky, multi-layered artisan pastry baked fresh daily.',
    basePrice: 85.0,
  ),
  const MenuItem(
    id: 'coughfee-tumbler',
    name: 'COUGHFEE Matte Tumbler',
    category: 'Merch',
    description: 'Double-walled vacuum insulated 500ml stainless steel tumbler.',
    basePrice: 450.0,
  ),
];
