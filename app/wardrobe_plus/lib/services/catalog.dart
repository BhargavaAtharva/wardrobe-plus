import 'package:flutter/material.dart';

/// Clothing types, colours and occasions the app understands. These names must
/// match the backend (backend/recommender.py and backend/color_detect.py).
class Catalog {
  /// The model predicts Tshirts, Shirts, Pants and Dresses. Outerwear is set
  /// by the user when editing an item. (Kurtas were dropped: the model can't
  /// recognise them; old kurta items still show but aren't suggested.)
  static const types = ['Tshirts', 'Shirts', 'Pants', 'Dresses', 'Outerwear'];

  static const tops = {'Tshirts', 'Shirts'};

  /// Tops and pants can be matched with each other ("Find a match").
  static bool matchable(String? type) => tops.contains(type) || type == 'Pants';

  static const occasions = ['Casual', 'Office', 'Party', 'Travel'];

  /// Older versions of the app/model saved these names; map them to current ones.
  static const legacyTypes = {'Jeans': 'Pants', 'Trousers': 'Pants', 'Jackets': 'Outerwear'};

  static const _typeLabels = {
    'Tshirts': 'T-shirt',
    'Shirts': 'Shirt',
    'Kurtas': 'Kurta',
    'Pants': 'Pants',
    'Dresses': 'Dress',
    'Outerwear': 'Outerwear',
  };

  static String typeLabel(String? type) => _typeLabels[type] ?? (type ?? 'Item');

  static const colors = <String, Color>{
    'black': Color(0xFF1E1E20),
    'dark grey': Color(0xFF4B4B4E),
    'grey': Color(0xFF969698),
    'white': Color(0xFFF5F5F2),
    'beige': Color(0xFFC8B28C),
    'brown': Color(0xFF734E32),
    'navy': Color(0xFF263055),
    'blue': Color(0xFF325AAA),
    'light blue': Color(0xFF96B4D7),
    'teal': Color(0xFF1E8080),
    'green': Color(0xFF3C7D4B),
    'olive': Color(0xFF6E6E3C),
    'red': Color(0xFFBE232D),
    'maroon': Color(0xFF6E202D),
    'pink': Color(0xFFE896B4),
    'purple': Color(0xFF6E418C),
    'yellow': Color(0xFFE8C841),
    'orange': Color(0xFFE4782D),
  };

  /// All colour names including "multicolor" (shown as a gradient swatch).
  static List<String> get colorNames => [...colors.keys, 'multicolor'];

  static String colorLabel(String? color) {
    if (color == null || color.isEmpty || color == 'unknown') return 'Unknown colour';
    if (color == 'multicolor') return 'Multicolour';
    return color[0].toUpperCase() + color.substring(1);
  }
}
