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
  String get searchCityHint => 'Digite a cidade';

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
  String get sortVisibleStartTime => 'Início da Visibilidade';

  @override
  String get sortTransitTime => 'Horário de Trânsito';

  @override
  String get sortVisibleDuration => 'Duração Visível';

  @override
  String get sortSize => 'Tamanho (Maior)';

  @override
  String visibleFromTooltip(String time) {
    return 'Visível a partir de $time';
  }

  @override
  String visibilityWindowSpan(String start, String end) {
    return 'Visível: $start – $end';
  }

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

  @override
  String get observingTimeWindow => 'Janela de Tempo de Observação';

  @override
  String get astronomicalDarkness => 'Escuridão Astronômica';

  @override
  String get astroDarknessShort => 'Escur. Astronômica';

  @override
  String get customTimeLimit => 'Limite de Tempo Personalizado';

  @override
  String get customWindowShort => 'Janela Personalizada';

  @override
  String get startTime => 'INÍCIO';

  @override
  String get endTime => 'TÉRMINO';

  @override
  String get window => 'JANELA';

  @override
  String get hoursShort => 'h';

  @override
  String get duskMidnight => 'Crepúsculo - Meia-noite';

  @override
  String get midnightDawn => 'Meia-noite - Alvorecer';

  @override
  String get visibilityAltitudeRange => 'Visibilidade e Faixa de Altitude';

  @override
  String get zenith => '(Zênite)';

  @override
  String minimumAltitude(String degrees) {
    return 'Altitude Mínima: $degrees°';
  }

  @override
  String maximumAltitude(String degrees) {
    return 'Altitude Máxima: $degrees°';
  }

  @override
  String minimumDuration(String hours) {
    return 'Duração Mínima: ${hours}h';
  }

  @override
  String durationLabel(String hours) {
    return 'Duração: ${hours}h';
  }

  @override
  String get directionAzimuthRange => 'Direção e Faixa de Azimute';

  @override
  String get directionPresetMode => 'Predefinição / Modo de Direção';

  @override
  String get quadrantAll => 'Todas as Direções (0° - 360°)';

  @override
  String get quadrantN => 'Norte (315° - 45°)';

  @override
  String get quadrantE => 'Leste (45° - 135°)';

  @override
  String get quadrantS => 'Sul (135° - 225°)';

  @override
  String get quadrantW => 'Oeste (225° - 315°)';

  @override
  String get quadrantNE => 'Nordeste (0° - 90°)';

  @override
  String get quadrantSE => 'Sudeste (90° - 180°)';

  @override
  String get quadrantSW => 'Sudoeste (180° - 270°)';

  @override
  String get quadrantNW => 'Noroeste (270° - 360°)';

  @override
  String get quadrantCustom => 'Faixa de Graus Personalizada';

  @override
  String minAzimuthLabel(String deg, String cardinal) {
    return 'Mín: $deg° ($cardinal)';
  }

  @override
  String maxAzimuthLabel(String deg, String cardinal) {
    return 'Máx: $deg° ($cardinal)';
  }

  @override
  String get compassAll360 => 'Todos 360°';

  @override
  String get compassClosed => '0° (Fechado)';

  @override
  String compassSpan(String span) {
    return 'Extensão: $span°';
  }

  @override
  String get customHorizonMask => 'Máscara de Obstrução de Horizonte';

  @override
  String get customHorizonProfile => 'Perfil de Horizonte Personalizado';

  @override
  String get noObstaclePoints => 'Nenhum obstáculo definido (horizonte plano)';

  @override
  String obstaclePointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pontos de obstáculo configurados em 360°',
      one: '1 ponto de obstáculo configurado em 360°',
    );
    return '$_temp0';
  }

  @override
  String get createHorizonProfile => 'Criar Perfil de Horizonte...';

  @override
  String get openHorizonMaker => 'Abrir Criador de Horizonte...';

  @override
  String get moonDistance => 'Distância da Lua';

  @override
  String minMoonDistanceLabel(String degrees) {
    return 'Distância mín. da Lua: $degrees°';
  }

  @override
  String get catalogs => 'Catálogos';

  @override
  String get objectTypes => 'Tipos de Objeto';

  @override
  String get magnitudeApparentSize => 'Magnitude e Tamanho Aparente';

  @override
  String faintestLimitLabel(String mag) {
    return 'Limite Menos Brilhante (Mag Máx): $mag';
  }

  @override
  String get lowerBrighter => '(menor = mais brilhante)';

  @override
  String minSizeLabelAlt(String size) {
    return 'Tamanho Mín: $size\'';
  }

  @override
  String get equipmentRigsTooltip => 'Equipamentos e Óptica';

  @override
  String get equipmentRigsButton => 'Equipamentos';

  @override
  String get settingsAndDataTooltip => 'Configurações e Dados';

  @override
  String get settingsDialogTitle => 'Configurações e Dados';

  @override
  String get settingsDialogSubtitle =>
      'Gerencie predefinições de filtros e armazenamento de dados do aplicativo.';

  @override
  String get settingsSectionFilters => 'Filtros de Alvos';

  @override
  String get settingsSectionData => 'Armazenamento e Dados Locais';

  @override
  String get settingsLocation => 'Local do Observador...';

  @override
  String get actionCannotBeUndone => 'Esta ação não pode ser desfeita.';

  @override
  String get cleanDataSuccessSnackBar =>
      'Todos os dados salvos, configurações e listas de observação foram apagados.';

  @override
  String get selectedCoordsElevation => 'Coordenadas Selecionadas e Elevação';

  @override
  String get popularAstroSites => 'Locais Populares de Astrofotografia:';

  @override
  String get applyLocation => 'Aplicar Localização';

  @override
  String get cancel => 'Cancelar';

  @override
  String get retry => 'Tentar Novamente';

  @override
  String get failedLoadCore => 'Falha ao carregar o núcleo astronômico';

  @override
  String get initializingEngine =>
      'Inicializando motor astronômico e banco de dados...';

  @override
  String get equipmentDialogTitle => 'Equipamentos e Óptica';

  @override
  String get addEquipmentRig => 'Adicionar Equipamento';

  @override
  String get editEquipmentRig => 'Editar Equipamento';

  @override
  String get backToList => 'Voltar para Lista';

  @override
  String get editRig => 'Editar';

  @override
  String get deleteRigTooltip => 'Excluir Equipamento';

  @override
  String get createNewRig => 'Criar Novo Equipamento';

  @override
  String get rigProfileName => 'Nome do Perfil do Equipamento';

  @override
  String get telescopeOptics => 'Telescópio / Óptica';

  @override
  String get searchScopeHint =>
      'Buscar telescópio: ex: RedCat, FRA400, 72ED, C8, Seestar...';

  @override
  String get telescopeName => 'Nome do Telescópio';

  @override
  String get focalLengthMm => 'Distância Focal (mm)';

  @override
  String get apertureMm => 'Abertura (mm)';

  @override
  String get reducerFactor => 'Redutor (ex: 0.8)';

  @override
  String get cameraSensor => 'Câmera / Sensor';

  @override
  String get searchCameraHint =>
      'Buscar câmera: ex: ASI2600, ASI533, IMX571, Sony A7, Canon...';

  @override
  String get cameraName => 'Nome da Câmera';

  @override
  String get sensorWidthMm => 'Largura do Sensor (mm)';

  @override
  String get sensorHeightMm => 'Altura do Sensor (mm)';

  @override
  String get pixelSizeMicrons => 'Tamanho do Pixel (µm)';

  @override
  String get computedOpticalSpecs => 'Especificações Ópticas Calculadas';

  @override
  String get effectiveFocal => 'Focal Efetiva';

  @override
  String get focalRatio => 'Razão Focal';

  @override
  String get sensorFov => 'FOV do Sensor';

  @override
  String get imageScale => 'Escala de Imagem';

  @override
  String get sampling => 'Amostragem';

  @override
  String get saveRig => 'Salvar Equipamento';

  @override
  String get gearButton => 'Equip.';

  @override
  String get switchRigTooltip => 'Trocar Equipamento';

  @override
  String get rigsLabel => 'Equipamentos';

  @override
  String get manageRigsTooltip => 'Gerenciar Equipamentos / Adicionar Óptica';

  @override
  String get closeFramingSimulator => 'Fechar Simulador de Enquadramento';

  @override
  String get framingSimulatorTitle => 'Simulador de Enquadramento';

  @override
  String activeRigLabel(String rigName) {
    return 'Equipamento Ativo: $rigName';
  }

  @override
  String get cameraRotatorAngle => 'Ângulo de Rotação da Câmera';

  @override
  String get fitToSensor => 'Ajustar ao Sensor';

  @override
  String get autoAlignTarget => 'Alinhar';

  @override
  String get autoAlignTargetTooltip =>
      'Autoalinhar com Ângulo de Posição do Alvo';

  @override
  String get ruleOfThirdsGrid => 'Grade da Regra dos Terços';

  @override
  String get ruleOfThirdsSubtitle =>
      'Linhas de composição sobre o quadro do sensor';

  @override
  String get opticalSystemMetrics => 'Métricas do Sistema Óptico';

  @override
  String get effectiveFocalLength => 'Distância Focal Efetiva';

  @override
  String get sensorFovDegrees => 'Campo de Visão do Sensor';

  @override
  String get sensorFovArcmin => 'FOV do Sensor (Minutos de Arco)';

  @override
  String get imageScalePixelSize => 'Escala de Imagem (Tamanho do Pixel)';

  @override
  String get samplingDiagnosis => 'Diagnóstico de Amostragem';

  @override
  String get sensorResolution => 'Resolução do Sensor';

  @override
  String get copyFramingInfo => 'Copiar Info';

  @override
  String get copyFramingSpecsTooltip =>
      'Copiar Especificações de Enquadramento (N.I.N.A. / ASIAIR / Stellarium)';

  @override
  String get framingSpecsCopied =>
      'Especificações de enquadramento copiadas para a área de transferência';

  @override
  String get framingPanOffset => 'Deslocamento de Enquadramento';

  @override
  String get stepSize => 'Passo';

  @override
  String get centered => 'Centralizado';

  @override
  String offsetLabel(String offset) {
    return '$offset\' deslocado';
  }

  @override
  String get useArrowsToFrame => 'Use as setas para enquadrar fora do centro';

  @override
  String get resetToCenter => 'Redefinir para o Centro do Alvo';

  @override
  String get darkTime => 'Escuro';

  @override
  String get moonPhaseNewMoon => 'Lua Nova';

  @override
  String get moonPhaseWaxingCrescent => 'Lua Crescente';

  @override
  String get moonPhaseFirstQuarter => 'Quarto Crescente';

  @override
  String get moonPhaseWaxingGibbous => 'Crescente Gibosa';

  @override
  String get moonPhaseFullMoon => 'Lua Cheia';

  @override
  String get moonPhaseWaningGibbous => 'Minguante Gibosa';

  @override
  String get moonPhaseThirdQuarter => 'Quarto Minguante';

  @override
  String get moonPhaseWaningCrescent => 'Lua Minguante';

  @override
  String get elevationShort => 'Elevação';

  @override
  String searchResultSubtitle(String lat, String lon, String elev) {
    return 'Lat: $lat° | Lon: $lon° | Elevação: ${elev}m';
  }

  @override
  String get visualSkyPreview => 'Pré-visualização do Céu';

  @override
  String get noObservingListsFound =>
      'Nenhuma lista de observação encontrada. Crie uma lista primeiro!';

  @override
  String get defaultListNotes => 'Alvo para astrofotografia';

  @override
  String addToListDialogTitle(String targetName) {
    return 'Adicionar $targetName à Lista';
  }

  @override
  String get targetObservingListLabel => 'Lista de Observação';

  @override
  String get sessionNotesLabel => 'Notas da Sessão / Filtros';

  @override
  String get addBtn => 'Adicionar';

  @override
  String addedToObservingListSuccess(String targetName) {
    return 'Adicionado $targetName à lista de observação';
  }

  @override
  String get simbadQuerying => 'Consultando CDS / SIMBAD...';

  @override
  String simbadVerified(String objectType) {
    return 'Verificado no SIMBAD: $objectType';
  }

  @override
  String get simbadNotFound => 'Nenhum registro online adicional encontrado.';

  @override
  String get removeFromFavorites => 'Remover dos Favoritos';

  @override
  String get addToFavorites => 'Adicionar aos Favoritos';

  @override
  String addedToFavorites(String targetName) {
    return 'Adicionado $targetName aos Favoritos';
  }

  @override
  String removedFromFavorites(String targetName) {
    return 'Removido $targetName dos Favoritos';
  }

  @override
  String get closeDetailsTooltip => 'Fechar detalhes (Esc)';

  @override
  String get closeBtn => 'Fechar';

  @override
  String get transitTimeMetric => 'Horário de Trânsito';

  @override
  String get visibleDurationMetric => 'Duração Visível';

  @override
  String get moonDistanceMetric => 'Distância da Lua';

  @override
  String get apparentSizeMetric => 'Tamanho Aparente';

  @override
  String get verifyOnlineSimbad => 'Verificar Online (SIMBAD)';

  @override
  String get simulatingYearlyVisibility =>
      'Simulando visibilidade de 12 meses ao longo do ano...';

  @override
  String get visibleTonight => 'Visível Esta Noite';

  @override
  String get unreachable => 'Inalcançável';

  @override
  String get notObservableFiltered => 'Não observável com filtros ativos';

  @override
  String get notObservableBelowLimits => 'Não observável (abaixo dos limites)';

  @override
  String startsTomorrow(String date) {
    return 'Começa amanhã ($date)';
  }

  @override
  String startsInDays(int days, String date) {
    return 'Começa em $days dias ($date)';
  }

  @override
  String startsOnDate(String date) {
    return 'Começa em $date';
  }

  @override
  String get inSeasonBelowLimits =>
      'Em Temporada · Abaixo dos limites esta noite';

  @override
  String offSeasonEnded(String date) {
    return 'Fora de Temporada (Terminou em $date)';
  }

  @override
  String get simulationModeLabel => 'MODO DE SIMULAÇÃO:';

  @override
  String get activeFiltersMode => 'Filtros Ativos';

  @override
  String get fullSkyNightMode => 'Céu Completo e Noite';

  @override
  String get yearlyObservingWindow => 'JANELA ANUAL DE OBSERVAÇÃO';

  @override
  String yearlyDaysObservablePeak(int days, String hours, String date) {
    return '$days dias observáveis este ano • Pico Anual: ${hours}h em $date';
  }

  @override
  String periodPeakDate(String date) {
    return 'Pico no Período: $date';
  }

  @override
  String plannedPeriodBannerTitle(String start, String end) {
    return 'PERÍODO PLANEJADO: $start – $end';
  }

  @override
  String periodBestNightSummary(String date, String hours) {
    return 'Melhor Noite no Período: $date (${hours}h visíveis)';
  }

  @override
  String periodDaysObservableSummary(int observable, int total) {
    return '$observable de $total noites observáveis neste período';
  }

  @override
  String periodPeakAltSummary(String alt) {
    return 'Altitude Máxima: $alt°';
  }

  @override
  String periodEvaluatedNote(String date) {
    return 'Métricas e curva de altitude abaixo são avaliadas para $date (melhor noite do período).';
  }

  @override
  String get periodNotObservableSummary =>
      'O alvo não atende aos limites dos filtros durante este período (0 noites observáveis).';

  @override
  String periodEvaluatedStartDateNote(String date) {
    return 'Métricas e curva de altitude abaixo são avaliadas para $date (início do período).';
  }

  @override
  String visibleOnDate(String date) {
    return 'Observável em $date';
  }

  @override
  String visibleFromDate(String date) {
    return 'Observável a partir de $date';
  }

  @override
  String outsideFiltersOnDate(String date) {
    return 'Fora dos limites em $date';
  }

  @override
  String theoreticalMaxAtTransit(String alt, String extra) {
    return 'Máximo teórico: $alt° no trânsito$extra';
  }

  @override
  String limitsSubtitle(String minAlt, String minHours) {
    return 'Limites: ≥$minAlt° por ≥${minHours}h';
  }

  @override
  String get yearRoundCircumpolar => 'Ano Todo (Circumpolar)';

  @override
  String get notObservableWithFilters => 'Não observável com os filtros atuais';

  @override
  String neverReachesLatitude(String minAlt, String maxAlt) {
    return 'Nunca atinge $minAlt° nesta latitude (Máx: $maxAlt°)';
  }

  @override
  String get clearSearchTooltip => 'Limpar busca';

  @override
  String get searchTargetTooltip => 'Buscar alvo';

  @override
  String get windowFullDarkness => 'Janela: Escuridão (Noite Toda)';

  @override
  String targetsFoundCount(int count) {
    return '$count alvos encontrados';
  }

  @override
  String get showingMatchingOnly =>
      'Exibindo apenas alvos correspondentes aos filtros ativos esta noite.';

  @override
  String get searchIncludesOutsideFilters =>
      'A busca inclui alvos fora dos filtros ativos esta noite. Clique em qualquer alvo para ver sua janela anual.';

  @override
  String get showAll => 'Mostrar Todos';

  @override
  String get hideNonMatching => 'Ocultar Não Correspondentes';

  @override
  String visibleDurationShort(String hours) {
    return '${hours}h visível';
  }

  @override
  String visibleDurationAbove(String hours, String alt) {
    return '${hours}h acima de $alt°';
  }

  @override
  String get outsideFilters => 'Fora dos Filtros';

  @override
  String get outsideActiveFilters => 'Fora dos Filtros Ativos';

  @override
  String get belowZero => 'Abaixo de 0°';

  @override
  String get belowHorizon => 'Abaixo do Horizonte';

  @override
  String peakAltitudeShort(String alt) {
    return 'Pico: $alt°';
  }

  @override
  String moonSeparationShort(String sep) {
    return 'Lua: $sep°';
  }

  @override
  String get selectSkySurveyTooltip => 'Selecionar Levantamento do Céu';

  @override
  String get openFramingSimulatorTooltip =>
      'Abrir Simulador de Enquadramento Completo';

  @override
  String get framingSimulatorShort => 'Simulador';

  @override
  String get toggleFramingBoxTooltip =>
      'Alternar Caixa de Enquadramento do Sensor';

  @override
  String get framingModeShort => 'Enquadramento';

  @override
  String get photoReticleTooltip => 'Foto + Retículo';

  @override
  String get photoCleanTooltip => 'Modo Foto (Imagem Limpa)';

  @override
  String get vectorSizeTooltip => 'Tamanho Aparente Vetorial';

  @override
  String get zoomOutTooltip => 'Diminuir Zoom (FOV Mais Amplo)';

  @override
  String get zoomInTooltip => 'Aumentar Zoom (FOV Mais Próximo)';

  @override
  String get resetFovTooltip => 'Redefinir FOV de Enquadramento';

  @override
  String get rotateMinus15 => 'Girar -15°';

  @override
  String get rotatePlus15 => 'Girar +15°';

  @override
  String get fitFovToSensorTooltip => 'Ajustar FOV ao Tamanho do Sensor';

  @override
  String get offlineSkyFallback => 'Modo Céu Offline';

  @override
  String get noAltitudeData =>
      'Nenhum dado de altitude disponível para a janela';

  @override
  String altitudeVsTimeTarget(String targetName) {
    return 'Altitude vs. Tempo: $targetName';
  }

  @override
  String get astronomicalDarknessLabel => 'ESCURIDÃO ASTRONÔMICA';

  @override
  String get observingWindowLabel => 'JANELA DE OBSERVAÇÃO';

  @override
  String get settingsSectionAbout => 'Sobre o Menelway';

  @override
  String get aboutBtn => 'Sobre o Menelway';

  @override
  String get aboutDialogTitle => 'Sobre o Menelway';

  @override
  String get aboutCloseBtn => 'Fechar';

  @override
  String get aboutCreatedBy => 'Criado por Rodrigo F. Mello';

  @override
  String get aboutAppName => 'Menelway Astro Planner';

  @override
  String get aboutNameOrigin =>
      '“Menelway” = “Menel” (palavra em élfico de Tolkien para Céus/Firmamento) + Arroway (do livro/filme Contato)';

  @override
  String get futureObservationPlanner => 'Planejador de Observações Futuras';

  @override
  String get presetNext7Days => 'Próximos 7 Dias';

  @override
  String get presetThisWeekend => 'Este Fim de Semana';

  @override
  String get presetNextMonth => 'Próximo Mês';

  @override
  String get presetNext30Days => 'Próximos 30 Dias';

  @override
  String get presetCustomPeriod => 'Período Personalizado...';

  @override
  String plannerWindowCustom(String start, String end) {
    return 'Janela: $start – $end';
  }

  @override
  String get plannerWindowFullNight => 'Janela: Noite Toda';

  @override
  String plannerDirectionLabel(String direction) {
    return 'Direção: $direction';
  }

  @override
  String plannerAltMinLabel(String alt) {
    return 'Alt ≥ $alt°';
  }

  @override
  String plannerDurationMinLabel(String hours) {
    return 'Duração ≥ ${hours}h';
  }

  @override
  String get searchPeriodTargetsHint =>
      'Buscar alvos no período (ex: M42, Roseta, Nebulosa)...';

  @override
  String get searchPeriodTargetsHintShort => 'Buscar alvos no período...';

  @override
  String get sortMostObservableDays => 'Mais Dias Observáveis';

  @override
  String get sortPeakDate => 'Data do Pico';

  @override
  String get sortHighestAltitude => 'Maior Altitude';

  @override
  String get sortBrightestFirst => 'Mais Brilhantes Primeiro';

  @override
  String simulatingSkyPeriod(int days) {
    return 'Simulando o céu ao longo de $days noites...';
  }

  @override
  String get noTargetsMatchPeriod => 'Nenhum Alvo Corresponde a Este Período';

  @override
  String noTargetsPeriodSubtitle(String minAlt, String direction) {
    return 'Nenhum dos candidatos do catálogo atende aos seus limites ativos (Alt ≥ $minAlt°, $direction) neste intervalo.\nTente selecionar um período mais amplo ou relaxar os limites de direção.';
  }

  @override
  String get adjustFiltersBtn => 'Ajustar Filtros';

  @override
  String errorCalculatingPeriodTargets(String error) {
    return 'Erro ao calcular alvos do período: $error';
  }

  @override
  String targetInConstellation(String type, String constellation) {
    return '$type em $constellation';
  }

  @override
  String periodDaysObservableShort(int observable, int total) {
    return '$observable de $total dias observáveis';
  }

  @override
  String get outsideFiltersInPeriod => 'Fora dos filtros ativos neste período';

  @override
  String periodPeakAltAndMaxHours(String alt, String hours) {
    return 'Alt. Máx: $alt° • Máx: ${hours}h/noite';
  }

  @override
  String periodNeverClearsAlt(String alt) {
    return 'Nunca atinge $alt° na janela ativa';
  }

  @override
  String periodDaysRatio(int observable, int total) {
    return '$observable / $total dias';
  }

  @override
  String periodDaysOnlySpan(String ratio, int day) {
    return '$ratio • Apenas dia $day';
  }

  @override
  String addNamedTargetTo(String targetName) {
    return 'Adicionar $targetName a:';
  }

  @override
  String observingListItemCount(int count) {
    return '$count itens';
  }

  @override
  String addedTargetToList(String targetName, String listName) {
    return '$targetName adicionado à lista \'$listName\'!';
  }

  @override
  String daysCountSuffix(int days) {
    return '($days d)';
  }

  @override
  String get okBtn => 'OK';

  @override
  String listItemsPlannedCount(int count) {
    return '$count alvos planejados';
  }

  @override
  String get exportCsvFramingTooltip => 'Exportar CSV / Enquadramento';

  @override
  String get deleteListTooltip => 'Excluir lista';

  @override
  String get noTargetsInList =>
      'Nenhum alvo nesta lista. Adicione alvos pela busca!';

  @override
  String tourStepIndicator(int current, int total) {
    return 'Passo $current de $total';
  }

  @override
  String get tourSkip => 'Pular Tour';

  @override
  String get tourNext => 'Próximo →';

  @override
  String get tourBack => '← Voltar';

  @override
  String get tourFinish => 'Começar a Explorar';

  @override
  String get tourLocationTitle => '1. Defina seu Local de Observação';

  @override
  String get tourLocationDesc =>
      'As curvas de altitude, nascer/pôr e horas de escuridão são calculadas para suas coordenadas exatas. Clique aqui para buscar sua cidade ou inserir coordenadas.';

  @override
  String get tourEquipmentTitle => '2. Configure Equipamentos e Ópticas';

  @override
  String get tourEquipmentDesc =>
      'Cadastre seus telescópios, sensores de câmera e redutores. O Menelway simula o campo de visão (FoV) real do seu sensor e enquadramento.';

  @override
  String get tourFiltersTitle => '3. Filtros e Critérios de Alvos';

  @override
  String get tourFiltersDesc =>
      'Filtre milhares de objetos do céu profundo por altitude mínima, separação da Lua, tipo de DSO e janela de trânsito para planejar sua sessão.';

  @override
  String get settingsSectionTour => 'Guia Rápido e Tour';

  @override
  String get settingsTourDesc =>
      'Reveja o tour interativo destacando local, equipamentos e filtros.';

  @override
  String get settingsReplayTourBtn => 'Rever Tour Rápido';
}
