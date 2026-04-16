import 'package:riverpod/legacy.dart';

// Provider global — null significa "unidade padrão do usuário logado"
final selectedUnitIdProvider = StateProvider<String?>((ref) => null);
