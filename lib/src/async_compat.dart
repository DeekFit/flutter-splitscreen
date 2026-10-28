/// Marks intentionally unawaited work without requiring Dart 2.15's helper.
/// Errors remain observable; this does not attach an error handler.
void ignoreFuture(Future<void>? future) {}
