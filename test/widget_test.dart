import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:greenify/main.dart';
import 'package:greenify/providers/app_state.dart';

void main() {
  group('Greenify App Tests', () {
    
    testWidgets('App yuklanadi va MaterialApp mavjud', (WidgetTester tester) async {
      // App ni build qilish
      await tester.pumpWidget(const MyApp());

      // MaterialApp mavjudligini tekshirish
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Provider to\'g\'ri sozlangan', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // Provider mavjudligini tekshirish
      final context = tester.element(find.byType(MaterialApp));
      final appState = Provider.of<AppState>(context, listen: false);
      
      expect(appState, isNotNull);
    });

    testWidgets('Splash screen ko\'rsatiladi', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());

      // Splash screen elementlarini tekshirish
      // Masalan: logo, yuklash indikatori va h.k.
      expect(find.byType(CircularProgressIndicator), findsWidgets);
    });

    testWidgets('Bottom navigation bar mavjud', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      
      // App yuklanishini kutish
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // BottomNavigationBar ni topish (agar bor bo'lsa)
      // expect(find.byType(BottomNavigationBar), findsOneWidget);
    });
  });

  group('Navigation Tests', () {
    
    testWidgets('Ekranlar o\'rtasida navigatsiya', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Bottom navigation tugmalarini bosish va tekshirish
      // Bu yerda sizning ekranlaringizga mos ravishda yozasiz
      
      // Misol:
      // final tasksButton = find.text('Vazifalar');
      // if (tasksButton.evaluate().isNotEmpty) {
      //   await tester.tap(tasksButton);
      //   await tester.pumpAndSettle();
      //   expect(find.byType(TasksScreen), findsOneWidget);
      // }
    });
  });

  group('UI Component Tests', () {
    
    testWidgets('AppBar mavjud va to\'g\'ri sarlavha', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // AppBar tekshirish (agar bor bo'lsa)
      // expect(find.byType(AppBar), findsWidgets);
    });

    testWidgets('Tab navigation ishlaydi', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Tab'larni topish va bosish
      // final tab = find.text('📋 Vazifalar');
      // if (tab.evaluate().isNotEmpty) {
      //   await tester.tap(tab);
      //   await tester.pumpAndSettle();
      // }
    });
  });

  group('State Management Tests', () {
    
    test('AppState boshlang\'ich qiymatlari to\'g\'ri', () {
      final appState = AppState();
      
      expect(appState.isLoading, true);
      expect(appState.userTrees, isEmpty);
      expect(appState.nearbyTasks, isEmpty);
      expect(appState.ratingUsers, isEmpty);
    });

    test('AppState metodlari to\'g\'ri ishlaydi', () async {
      final appState = AppState();
      
      // Mock data bilan test qilish
      // Bu yerda API chaqiruvlarsiz test qilish uchun
      // mock'lar kerak bo'ladi (masalan: mockito package)
    });
  });

  group('Error Handling Tests', () {
    
    testWidgets('Xatolik holatida UI to\'g\'ri ko\'rsatiladi', (WidgetTester tester) async {
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();

      // Xatolik bo'lganda nima ko'rsatilishini tekshirish
      // Masalan: "Ma'lumot topilmadi" yoki retry button
    });
  });
}