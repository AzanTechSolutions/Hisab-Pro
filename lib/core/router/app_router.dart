import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return const Placeholder();
        },
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) {
          return const Placeholder();
        },
      ),
      GoRoute(
        path: '/profiles',
        builder: (context, state) {
          return const Placeholder();
        },
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) {
          return const Placeholder();
        },
      ),
    ],
  );
}
