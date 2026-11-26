import 'package:flutter/material.dart';

/// A recognisable icon for an expense, chosen from the words in its title.
///
/// This is decoration only: it never changes an amount or how a bill is
/// stored. A title that matches nothing gets the neutral receipt icon.
///
/// Matching is on whole words (so "team" is not "tea"), and the order below
/// decides ties: "Coffee before the flight" is a coffee.
IconData expenseIcon(String title) {
  final words = RegExp(r'[a-z]+')
      .allMatches(title.toLowerCase())
      .map((match) => match.group(0)!)
      .toSet();

  bool mentions(Set<String> keys) => words.any((word) =>
      keys.contains(word) ||
      (word.endsWith('s') && keys.contains(word.substring(0, word.length - 1))));

  for (final entry in _expenseIcons) {
    if (mentions(entry.$2)) return entry.$1;
  }
  return Icons.receipt_long_outlined;
}

const List<(IconData, Set<String>)> _expenseIcons = [
  (
    Icons.local_cafe_rounded,
    {'coffee', 'tea', 'chai', 'cafe', 'latte', 'juice', 'drink', 'smoothie'},
  ),
  (
    Icons.restaurant_rounded,
    {
      'dinner',
      'lunch',
      'breakfast',
      'brunch',
      'restaurant',
      'food',
      'meal',
      'pizza',
      'burger',
      'biryani',
      'bbq',
      'snack',
      'takeaway',
      'iftar',
      'sehri',
      'dessert',
      'eat',
    },
  ),
  (
    Icons.shopping_cart_rounded,
    {'grocery', 'groceries', 'supermarket', 'vegetable', 'fruit', 'mart'},
  ),
  (
    Icons.directions_car_rounded,
    {
      'taxi',
      'uber',
      'careem',
      'ride',
      'cab',
      'bus',
      'train',
      'metro',
      'fuel',
      'petrol',
      'diesel',
      'parking',
      'toll',
    },
  ),
  (
    Icons.flight_rounded,
    {
      'flight',
      'hotel',
      'trip',
      'tour',
      'airbnb',
      'hostel',
      'vacation',
      'holiday',
      'camping',
      'stay',
      'travel',
    },
  ),
  (
    Icons.home_rounded,
    {'rent', 'house', 'apartment', 'furniture', 'home', 'maintenance'},
  ),
  (
    Icons.bolt_rounded,
    {
      'electricity',
      'electric',
      'gas',
      'water',
      'utility',
      'utilities',
      'wifi',
      'internet',
      'phone',
      'recharge',
    },
  ),
  (
    Icons.movie_rounded,
    {
      'movie',
      'cinema',
      'netflix',
      'spotify',
      'concert',
      'game',
      'party',
      'bowling',
      'event',
    },
  ),
  (
    Icons.medical_services_rounded,
    {'doctor', 'medicine', 'pharmacy', 'hospital', 'medical', 'gym'},
  ),
  (
    Icons.shopping_bag_rounded,
    {'shopping', 'clothes', 'mall', 'gift', 'shoes'},
  ),
  (
    Icons.school_rounded,
    {'tuition', 'school', 'course', 'book', 'class', 'exam'},
  ),
];
