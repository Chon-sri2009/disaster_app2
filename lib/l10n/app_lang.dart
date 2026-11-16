// The two UI languages. Thai is the default; the choice is saved by StorageService.
enum AppLang {
  th('th'),
  en('en');

  const AppLang(this.code);

  final String code;

  static AppLang fromCode(String? code) =>
      code == 'en' ? AppLang.en : AppLang.th;
}
