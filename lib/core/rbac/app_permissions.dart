// lib/core/rbac/app_permissions.dart
// Fonte única de verdade para todas as permissões do BarberOS.
// Todos os arquivos que precisam verificar roles devem importar daqui.

/// Papéis disponíveis no sistema.
/// O campo `category` da tabela `barbers` (via userProfileProvider) contém esses valores.
class AppRoles {
  // Setor Barbearia
  static const String barbeiroLider    = 'Barbeiro Líder';
  static const String barbeiroProMax   = 'Barbeiro Pro Max';
  static const String barbeiroPro      = 'Barbeiro Pro';
  static const String barbeiro         = 'Barbeiro';

  // Setor Salão
  static const String cabelereiraLider  = 'Cabeleireira Líder';
  static const String cabelereiraProMax = 'Cabeleireira Pro Max';
  static const String cabeleireiraPro   = 'Cabeleireira Pro';
  static const String cabeleireira      = 'Cabeleireira';

  // Todos os papéis do setor Barbearia
  static const List<String> barbearia = [
    barbeiroLider, barbeiroProMax, barbeiroPro, barbeiro,
  ];

  // Todos os papéis do setor Salão
  static const List<String> salao = [
    cabelereiraLider, cabelereiraProMax, cabeleireiraPro, cabeleireira,
  ];

  // Papéis que são "Líderes" em seus respectivos setores
  static const List<String> lideres = [barbeiroLider, cabelereiraLider];
}

/// Extensão sobre o mapa de perfil retornado por [userProfileProvider].
/// Uso: `final p = AppPermissions(userProfile); if (p.isGlobalAdmin) { ... }`
class AppPermissions {
  final Map<String, dynamic> profile;

  const AppPermissions(this.profile);

  String get category => profile['category'] as String? ?? '';
  String get role     => profile['role']     as String? ?? '';

  // -----------------------------------------------------------------------
  // VERIFICAÇÕES DE PAPEL
  // -----------------------------------------------------------------------

  /// Dono do negócio. Acesso total. Único que acessa o Premium.
  bool get isGlobalAdmin =>
      category == AppRoles.barbeiroLider || role == 'admin';

  /// Líder de qualquer setor (Barbeiro Líder OU Cabeleireira Líder).
  bool get isAnyLeader =>
      AppRoles.lideres.contains(category) || role == 'admin';

  /// Pertence ao setor Barbearia (qualquer nível).
  bool get isBarbearia => AppRoles.barbearia.contains(category);

  /// Pertence ao setor Salão (qualquer nível).
  bool get isSalao => AppRoles.salao.contains(category);

  // -----------------------------------------------------------------------
  // PERMISSÕES DE FUNCIONALIDADE
  // -----------------------------------------------------------------------

  /// Pode ver e acessar dados financeiros (FinancialScreen, relatórios).
  bool get canAccessFinancial => isGlobalAdmin;

  /// Pode ver e gerenciar todas as unidades.
  bool get canManageUnits => isGlobalAdmin;

  /// Pode cadastrar, editar e excluir serviços do catálogo.
  bool get canManageServices => isGlobalAdmin;

  /// Pode cadastrar, editar e excluir produtos.
  bool get canManageProducts => isGlobalAdmin;

  /// Pode editar dados de clientes (nome, telefone, plano).
  bool get canEditClients => isGlobalAdmin;

  /// Pode VER o WhatsApp/telefone de um cliente após o cadastro.
  bool get canViewClientPhone => isGlobalAdmin;

  /// Pode cadastrar NOVOS clientes (qualquer nível pode; só líder edita).
  bool get canCreateClients => true;

  /// Pode gerenciar a equipe (cadastrar/editar/desativar profissionais).
  bool get canManageTeam => isGlobalAdmin;

  /// Pode criar agendamentos para QUALQUER barbeiro (não só para si).
  bool get canScheduleForOthers => isGlobalAdmin;

  /// Pode ver e criar agendamentos (todos os níveis podem para si mesmos).
  bool get canSchedule => true;

  /// Pode acessar o DesktopShell (visão de líder em tela grande).
  bool get canAccessDesktop => isGlobalAdmin;

  /// Pode acessar a tela do Espaço Premium.
  bool get canAccessPremium => isGlobalAdmin;

  /// Pode acessar a tela do Salão de Beleza.
  bool get canAccessSalon => isSalao || isGlobalAdmin;

  /// Ícone representativo do papel para UI.
  static String roleIcon(String category) {
    switch (category) {
      case AppRoles.barbeiroLider:
      case AppRoles.cabelereiraLider:
        return '👑';
      case AppRoles.barbeiroProMax:
      case AppRoles.cabelereiraProMax:
        return '⭐';
      case AppRoles.barbeiroPro:
      case AppRoles.cabeleireiraPro:
        return '✂️';
      default:
        return '💈';
    }
  }
}
