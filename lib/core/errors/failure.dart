abstract class Failure implements Exception {
  const Failure(this.message);

  final String message;

  @override
  String toString() => message;
}

class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

class SecurityFailure extends Failure {
  const SecurityFailure(super.message);
}

class ValidationFailure extends Failure {
  const ValidationFailure(super.message);
}
