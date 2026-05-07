class AppRoutes {
  AppRoutes._();

  static const root = '/';
  static const onboarding = '/onboarding';
  static const lock = '/lock';
  static const documents = '/documents';
  static const documentDetail = '/documents/:id';

  static String documentDetailPath(String id) => '/documents/$id';
}
