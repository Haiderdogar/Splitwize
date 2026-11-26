import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:splitwize/utils/expense_icon.dart';

void main() {
  test('a title is matched to a fitting icon', () {
    expect(expenseIcon('Dinner with friends'), Icons.restaurant_rounded);
    expect(expenseIcon('Coffee catch-up'), Icons.local_cafe_rounded);
    expect(expenseIcon('Airport taxi'), Icons.directions_car_rounded);
    expect(expenseIcon('Weekend trip'), Icons.flight_rounded);
    expect(expenseIcon('Monthly rent'), Icons.home_rounded);
    expect(expenseIcon('Electricity bill'), Icons.bolt_rounded);
    expect(expenseIcon('Weekly groceries'), Icons.shopping_cart_rounded);
    expect(expenseIcon('Movie night'), Icons.movie_rounded);
  });

  test('matching is by whole word, ignores case and accepts plurals', () {
    // "team" must not be read as "tea".
    expect(expenseIcon('Team offsite'), Icons.receipt_long_outlined);
    expect(expenseIcon('LUNCH'), Icons.restaurant_rounded);
    expect(expenseIcon('Taxis to the venue'), Icons.directions_car_rounded);
  });

  test('the first matching category wins', () {
    expect(expenseIcon('Coffee before the flight'), Icons.local_cafe_rounded);
    expect(expenseIcon('Team dinner at a long named restaurant'),
        Icons.restaurant_rounded);
  });

  test('anything unrecognised gets the neutral receipt icon', () {
    expect(expenseIcon(''), Icons.receipt_long_outlined);
    expect(expenseIcon('???'), Icons.receipt_long_outlined);
    expect(expenseIcon('Miscellaneous'), Icons.receipt_long_outlined);
  });
}
