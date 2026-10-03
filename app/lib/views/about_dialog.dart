import 'package:flutter/material.dart';

import '../core/url_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/astro_theme.dart';

/// A dedicated About window dialog for Menelway Astro Planner,
/// sharing the project's origin story, design philosophy, and attribution.
class AboutDialogView extends StatelessWidget {
  const AboutDialogView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isPt = Localizations.localeOf(context).languageCode == 'pt';
    final isNarrow = MediaQuery.of(context).size.width < 600;

    final palette = AstroPalette.of(context);
    final bgColor = palette.surface;
    final cardBgColor = palette.surfaceVariant;
    final borderColor = palette.border;
    final textColor = palette.textPrimary;
    final textSubColor = palette.textSecondary;
    final accentColor = palette.accent;

    return Dialog(
      backgroundColor: bgColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.2),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 24,
        vertical: isNarrow ? 16 : 24,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Padding(
          padding: EdgeInsets.all(isNarrow ? 16 : 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: palette.isRedNightMode
                        ? ColorFiltered(
                            colorFilter: const ColorFilter.mode(
                              AstroColors.nightVisionRed,
                              BlendMode.modulate,
                            ),
                            child: Image.asset(
                              'assets/app_icon.png',
                              width: 36,
                              height: 36,
                              fit: BoxFit.contain,
                            ),
                          )
                        : Image.asset(
                            'assets/app_icon.png',
                            width: 36,
                            height: 36,
                            fit: BoxFit.contain,
                          ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Row(
                      children: [
                        Text(
                          "MENELWAY",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            "v1.0.0",
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.aboutCloseBtn,
                    icon: Icon(Icons.close_rounded, size: 20, color: textColor.withValues(alpha: 0.8)),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Divider(height: 1, color: borderColor),
              const SizedBox(height: 16),

              // Scrollable Story & Features Content
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section: Personal Necessity & Story
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.format_quote_rounded, size: 18, color: accentColor),
                                const SizedBox(width: 8),
                                Text(
                                  isPt ? "Motivação e Objetivo do Projeto" : "Project Motivation and Goal",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isPt
                                  ? "Este projeto nasceu de uma necessidade pessoal. Observar e fotografar da minha varanda é uma batalha constante contra obstruções: tenho apenas uma fatia de céu entre o Norte e o Oeste, um horizonte local bloqueado pela geografia da cidade e um beiral que restringe minha altitude máxima — sem falar no sinal limitado de internet."
                                  : "This project was born out of personal necessity. Observing and imaging from my balcony is a constant battle with obstructions: I only have a slice of sky between North and West, a blocked local horizon due to my city geography, and an overhang that restricts my maximum altitude — not to mention limited internet signal.",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: textSubColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isPt
                                  ? "Embora existam outros aplicativos nesse espaço (até o próprio Stellarium pode ser usado com esse objetivo), a maioria é freemium, e nenhum (que encontrei) é verdadeiramente gratuito e com a simplicidade e recursos que eu precisava em um único app, como:"
                                  : "While there are existing apps in this space (even Stellarium itself can be used with this goal), most are freemium, and none (that I found) is truly free and with the simplicity and features that I needed in one single app like:",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: textSubColor,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Section: Key Pillars (4 Bullets)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildPillarRow(
                              icon: Icons.wifi_off_rounded,
                              accentColor: accentColor,
                              textColor: textColor,
                              textSubColor: textSubColor,
                              title: isPt ? "100% Offline" : "Work 100% Offline",
                              description: isPt
                                  ? "Funciona de forma independente, sem necessidade de conexão com a internet."
                                  : "Operates completely offline without requiring an active internet connection.",
                            ),
                            const SizedBox(height: 12),
                            _buildPillarRow(
                              icon: Icons.crop_free_rounded,
                              accentColor: accentColor,
                              textColor: textColor,
                              textSubColor: textSubColor,
                              title: isPt ? "Prévia Fácil de Equipamento" : "Easy Equipment Preview",
                              description: isPt
                                  ? "Streaming de imagens de levantamentos HiPS quando online e uma ótima alternativa vetorial quando offline."
                                  : "Target HiPS image streaming when online, and a good vector-based fallback when offline.",
                            ),
                            const SizedBox(height: 12),
                            _buildPillarRow(
                              icon: Icons.calendar_month_rounded,
                              accentColor: accentColor,
                              textColor: textColor,
                              textSubColor: textSubColor,
                              title: isPt ? "Planejador de Alvos Futuros" : "Simple Future Targets Planner",
                              description: isPt
                                  ? "Verifique com facilidade quais alvos estarão disponíveis para você em qualquer período no próximo ano."
                                  : "Easily check which targets will be available for you in any upcoming time period next year.",
                            ),
                            const SizedBox(height: 12),
                            _buildPillarRow(
                              icon: Icons.verified_user_rounded,
                              accentColor: accentColor,
                              textColor: textColor,
                              textSubColor: textSubColor,
                              title: isPt ? "Leve e sem Restrições" : "Lightweight & Bloat-Free",
                              description: isPt
                                  ? "Builds para Windows e Android com zero bloatware, limitações, paywalls ou anúncios."
                                  : "Lightweight Windows and Android builds with zero bloat, limitations, paywalls, or ads.",
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Section: Horizon & Looking to the Future
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: borderColor),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.wb_twilight_rounded, size: 18, color: accentColor),
                                const SizedBox(width: 8),
                                Text(
                                  isPt ? "Horizonte e Futuro (v2)" : "Horizon Filter & Future Ideas",
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(
                              isPt
                                  ? "O filtro simples de horizonte deste app não é tão preciso quanto preciso para minhas obstruções (talvez uma versão 2 no futuro? Tenho muitas ideias legais para ele!). Mas, honestamente, só poder filtrar Altitude Mín/Máx, faixas de Azimute e tempo mínimo visível já economiza muito tempo procurando possíveis alvos no Stellarium."
                                  : "This app's simple horizon filter is not as precise as I need for my obstructions (maybe a version 2 of this app in the future? I have many cool ideas for it!). But honestly, just being able to filter the Min/Max altitude, Azimuth ranges, and minimum visible time is enough to save a lot of time in Stellarium searching for possible targets.",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: textSubColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              isPt
                                  ? "Todos os recursos que eu pessoalmente precisava foram implementados, mas feedbacks são sempre bem-vindos."
                                  : "All features that I personally needed are implemented, but feedback is always welcome.",
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: textSubColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: [
                                Icon(Icons.auto_awesome_rounded, size: 16, color: accentColor),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    isPt
                                        ? "Espero que ajude outros astrofotógrafos. Céus limpos!"
                                        : "I hope it helps fellow astrophotographers. Clear skies!",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Section: Author & Name Origin Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: palette.isRedNightMode
                                ? [
                                    cardBgColor,
                                    cardBgColor.withValues(alpha: 0.7),
                                  ]
                                : [
                                    accentColor.withValues(alpha: 0.08),
                                    cardBgColor,
                                  ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: accentColor.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isPt ? "Criado por Rodrigo F. Mello" : "Created by Rodrigo F. Mello",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Menelway Astro Planner",
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: accentColor,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: bgColor.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: borderColor),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.stars_rounded, size: 16, color: accentColor),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      isPt
                                          ? "“Menelway” = “Menel” palavra em élfico (Tolkien) para Céus/Firmamento + Arroway (do livro/filme Contato)"
                                          : "\"Menelway\" = \"Menel\" elvish word (Tolkien) for Skies/Heavens + Arroway (from the Contact book/movie)",
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontStyle: FontStyle.italic,
                                        height: 1.4,
                                        color: textSubColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Buy Me A Coffee Button
                      Center(
                        child: FilledButton.icon(
                          onPressed: () => UrlService.openUrl("https://buymeacoffee.com/rodrigofmello"),
                          icon: const Icon(
                            Icons.coffee_rounded,
                            size: 19,
                            color: Color(0xFF000000),
                          ),
                          label: const Text(
                            "Buy Me A Coffee",
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.2,
                              color: Color(0xFF000000),
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: palette.isRedNightMode
                                ? palette.accent
                                : const Color(0xFFFFDD00),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(24),
                            ),
                            elevation: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPillarRow({
    required IconData icon,
    required Color accentColor,
    required Color textColor,
    required Color textSubColor,
    required String title,
    required String description,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 2),
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 15, color: accentColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.35,
                  color: textSubColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
