class MoneyService {
  const MoneyService();

  int toMinorUnits(double value) => (value * 100).round();

  double fromMinorUnits(int minorUnits) => minorUnits / 100;
}
