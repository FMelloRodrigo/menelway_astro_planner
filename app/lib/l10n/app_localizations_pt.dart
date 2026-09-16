// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Menelway Astro Planner';

  @override
  String get appSubtitle => 'Planejador de Alvos e Sessões Astronômicas';

  @override
  String get tabTargets => 'Alvos';

  @override
  String get tabPlanner => 'Planejador';

  @override
  String get tabObservingLists => 'Listas de Observação';

  @override
  String get tabFavorites => 'Favoritos';

  @override
  String get observerLocation => 'Local do Observador';

  @override
  String get darkness => 'Escuridão';

  @override
  String get moon => 'Lua';

  @override
  String get databaseSize => 'Banco de Dados';

  @override
  String get nightModeRed => 'Modo Vermelho Telescópio';

  @override
  String get nightModeStandard => 'Obsidiana Espaço Profundo';

  @override
  String get equipmentRigs => 'Equipamentos e Óptica';

  @override
  String get settingsAndData => 'Configurações e Dados';

  @override
  String get language => 'Idioma';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get languageSystem => 'Padrão do Sistema';

  @override
  String get resetFilters => 'Redefinir Filtros de Alvos';

  @override
  String get resetFiltersDesc => 'Limpa limites de filtro e mantém localização';

  @override
  String get cleanData => 'Limpar Todos os Dados Salvos...';

  @override
  String get cleanDataDesc =>
      'Apaga listas, local personalizado e configurações';

  @override
  String get cleanDataConfirmTitle => 'Limpar Todos os Dados Salvos?';

  @override
  String get cleanDataWarning =>
      'Isso apagará permanentemente sua configuração local e restaurará tudo aos padrões de fábrica:';

  @override
  String get cleanDataPoint1 =>
      '• Localização geográfica e coordenadas do observador';

  @override
  String get cleanDataPoint2 =>
      '• Todos os filtros de alvos e perfis de horizonte';

  @override
  String get cleanDataPoint3 =>
      '• Perfis de óptica de equipamentos e sensores de câmera';

  @override
  String get cleanDataPoint4 =>
      '• Alvos favoritos e listas de observação personalizadas';

  @override
  String get cleanDataCancel => 'Cancelar';

  @override
  String get cleanDataConfirm => 'Sim, Redefinir Tudo';

  @override
  String get cleanDataSuccess =>
      'Todos os dados locais foram redefinidos. Aplicativo restaurado ao padrão.';

  @override
  String get filtersResetSuccess =>
      'Filtros de alvos redefinidos para o padrão (localização preservada).';

  @override
  String get locationEditTitle => 'Local do Observador';

  @override
  String get searchCityOnline => 'Buscar Cidade e País (Online)';

  @override
  String get searchCityHint =>
      'Digite a cidade (ex: Campinas, Londres, Atacama, Tóquio)...';

  @override
  String get searchOnlineTooltip => 'Buscar online';

  @override
  String get manualCoordinates => 'Coordenadas Manuais';

  @override
  String get latitude => 'Latitude (°)';

  @override
  String get longitude => 'Longitude (°)';

  @override
  String get elevation => 'Elevação (m)';

  @override
  String get locationNameLabel => 'Nome do Local';

  @override
  String get saveLocation => 'Salvar Localização';

  @override
  String locationNotFound(String query) {
    return 'Nenhuma cidade encontrada para \'$query\'.';
  }

  @override
  String get connectionError =>
      'Erro de conexão. Verifique sua conexão com a internet.';

  @override
  String get searchTargetsHint =>
      'Buscar alvo (ex: M31, NGC 7000, Órion, Dumbbell)...';

  @override
  String get filtersButton => 'Filtros';

  @override
  String get sortBy => 'Ordenar por';

  @override
  String get sortPeakAltitude => 'Altitude Máxima';

  @override
  String get sortMagnitude => 'Magnitude (Mais Brilho)';

  @override
  String get sortTransitTime => 'Horário de Trânsito';

  @override
  String get sortVisibleDuration => 'Duração Visível';

  @override
  String get sortSize => 'Tamanho (Maior)';

  @override
  String get noTargetsFound =>
      'Nenhum alvo corresponde aos critérios de filtro.';

  @override
  String get noTargetsSubtitle =>
      'Tente flexibilizar limites de altitude, magnitude ou limpar termos de busca.';

  @override
  String get altitude => 'Altitude';

  @override
  String get peakAltitude => 'Alt. Máx.';

  @override
  String get transit => 'Trânsito';

  @override
  String get visibleDuration => 'Visível';

  @override
  String get moonSeparation => 'Sep. Lua';

  @override
  String get magnitudeLabel => 'Mag';

  @override
  String get sizeLabel => 'Tam.';

  @override
  String get surfaceBrightnessLabel => 'Brilho Superficial';

  @override
  String get addToObservingList => 'Adicionar à Lista';

  @override
  String addedToObservingList(String listName) {
    return 'Adicionado à lista: $listName';
  }

  @override
  String get targetDetails => 'Detalhes do Alvo';

  @override
  String get constellationLabel => 'Constelação';

  @override
  String get coordinatesLabel => 'Coordenadas';

  @override
  String get visibilityWindow => 'Janela de Visibilidade';

  @override
  String get filterDialogTitle => 'Filtrar Alvos';

  @override
  String get tabGeneral => 'Geral e Altitude';

  @override
  String get tabAreaHorizon => 'Área e Horizonte';

  @override
  String get tabObjectTypes => 'Tipos de Objeto';

  @override
  String get tabCatalogs => 'Catálogos';

  @override
  String get tabWindow => 'Janela de Tempo';

  @override
  String minAltitudeLabel(String degrees) {
    return 'Altitude Mínima: $degrees°';
  }

  @override
  String maxAltitudeLabel(String degrees) {
    return 'Altitude Máxima: $degrees°';
  }

  @override
  String minDurationLabel(String hours) {
    return 'Duração Mínima: ${hours}h';
  }

  @override
  String minMoonSeparationLabel(String degrees) {
    return 'Separação Mínima da Lua: $degrees°';
  }

  @override
  String magnitudeRangeLabel(String minMag, String maxMag) {
    return 'Faixa de Magnitude: $minMag a $maxMag';
  }

  @override
  String sizeRangeLabel(String minSize, String maxSize) {
    return 'Tamanho Angular: $minSize\' a $maxSize\'';
  }

  @override
  String get resetAllFilters => 'Redefinir Filtros';

  @override
  String get applyFilters => 'Aplicar Filtros';

  @override
  String get selectAll => 'Selecionar Todos';

  @override
  String get deselectAll => 'Desmarcar Todos';

  @override
  String get objGalaxy => 'Galáxia';

  @override
  String get objPlanetaryNebula => 'Nebulosa Planetária';

  @override
  String get objBrightNebula => 'Nebulosa Brilhante';

  @override
  String get objDarkNebula => 'Nebulosa Escura';

  @override
  String get objOpenCluster => 'Aglomerado Aberto';

  @override
  String get objGlobularCluster => 'Aglomerado Globular';

  @override
  String get objSupernovaRemnant => 'Remanescente de Supernova';

  @override
  String get objStar => 'Estrela';

  @override
  String get objDoubleStar => 'Estrela Dupla';

  @override
  String get objAsterism => 'Asterismo';

  @override
  String get objOther => 'Outro';

  @override
  String get createNewList => 'Criar Nova Lista';

  @override
  String get listName => 'Nome da Lista';

  @override
  String get listDescription => 'Descrição (opcional)';

  @override
  String targetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alvos',
      one: '1 alvo',
    );
    return '$_temp0';
  }

  @override
  String get deleteList => 'Excluir Lista';

  @override
  String get deleteListConfirm =>
      'Tem certeza de que deseja excluir esta lista de observação?';

  @override
  String get emptyObservingLists =>
      'Nenhuma lista de observação ainda. Crie uma para organizar sua sessão!';

  @override
  String get noFavoritesYet => 'Nenhum alvo favorito ainda';

  @override
  String get noFavoritesDesc =>
      'Clique no ícone de estrela em qualquer card ou tela de detalhes para fixar favoritos aqui.';

  @override
  String get exploreTargets => 'Explorar Alvos';
}
