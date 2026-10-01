class InsufficientStockException implements Exception {
  final String message;
  InsufficientStockException(this.message);

  @override
  String toString() => 'InsufficientStockException: $message';
}
