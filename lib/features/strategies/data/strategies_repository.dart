import '../../../models/app_user.dart';
import '../../../models/support_strategy.dart';

abstract class StrategiesRepository {
  Stream<List<SupportStrategy>> watchStrategies(String childId);

  Future<void> addStrategy(SupportStrategy strategy);

  Future<void> updateStrategy(
    SupportStrategy strategy, {
    required AppUser actor,
  });

  Future<void> deleteStrategy(
    SupportStrategy strategy, {
    required AppUser actor,
  });
}
