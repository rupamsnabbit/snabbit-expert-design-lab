import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  static const Color brand = Color(0xffF70F79); //Palatinate blue
  static const Color brandInverted = Color(0xffEAEAF1); //Palatinate blue
  /// Accent light background (e.g. service tags) — matches Figma accent-light
  static const Color accentLight = Color(0xffFFF3F8);

  static const Color n90 = Color(0xff101840);
  static const Color n80 = Color(0xff525871);
  static const Color n70 = Color(0xff696F8C);
  static const Color n60 = Color(0xff8F95B2);
  static const Color n50 = Color(0xffC1C4D6);
  static const Color n40 = Color(0xffD8DAE5);
  static const Color n30 = Color(0xffE6E8F0);
  static const Color n20 = Color(0xffF5F5F5);
  static const Color n10 = Color(0xffFCFCFC);
  static const Color n0 = Color(0xffFFFFFF);

  static const Color b50 = Color(0xff2626A6);
  static const Color b40 = Color(0xff3030D6);
  static const Color b30 = Color(0xff3939FF);
  static const Color b20 = Color(0xff8787FF);
  static const Color b10 = Color(0xffE9E9FF);

  static const Color p50 = Color(0xffF70F79);
  // static const Color p40 = Color(0xff3030D6);
  // static const Color p30 = Color(0xff3939FF);
  static const Color p20 = Color(0xffFF86BD);
  static const Color p10 = Color(0xffFFE8F2);

  static const Color g50 = Color(0xff317159);
  static const Color g40 = Color(0xff429777);
  static const Color g30 = Color(0xff52BD94);
  static const Color g20 = Color(0xffA3E6CD);
  static const Color g10 = Color(0xffDCF2EA);
  static const Color g0 = Color(0xffF5FBF8);

  static const Color y60 = Color(0xff66460D);
  static const Color y50 = Color(0xff996A13);
  static const Color y45 = Color(0xffFFA600);
  static const Color y40 = Color(0xffFFB020);
  static const Color y30 = Color(0xffFFD079);
  static const Color y20 = Color(0xffFFDFA6);
  static const Color y10 = Color(0xffFFEFD2);
  static const Color y0 = Color(0xffFFFAF1);

  static const Color r60 = Color(0xff7D2828);
  static const Color r50 = Color(0xffA73636);
  static const Color r40 = Color(0xffD14343);
  static const Color r30 = Color(0xffEE9191);
  static const Color r20 = Color(0xffF4B6B6);
  static const Color r10 = Color(0xffF9DADA);
  static const Color r0 = Color(0xffFDF4F4);

  /// Informational wash — mirrors the KMP Design System's `bgInfo` semantic
  /// token (`SnabbitColorsLight.bgInfo`, identical in dark). Used where a
  /// Flutter surface must match its KMP twin pixel-for-pixel; keep in sync
  /// with the DS if that token moves.
  static const Color bgInfo = Color(0xFFEFF6FF);

  // Shield
  static const Color shieldBlue = Color(0xFF1B7DE9);

  // Auto-OT specific colors from Figma
  static const Color autoOtTextPrimary = Color(0xFF1D2129);
  static const Color autoOtHomeIndicator = Color(0xFF232330);
  static const Color autoOtGradientStart = Color(0xFFE0FFD8);
  static const Color autoOtButtonGreen = Color(0xFF37A660);

  // AWOL overlay colors
  static const Color awolBreachGradientStart = Color(0xFFFFE0DF);
  static const Color awolReEnteredGradientStart = Color(0xFFE9FFDF);
  static const Color awolDarkText = Color(0xFF1F1F1F);
  static const Color awolTimerArc = Color(0xFFCC0700);
  static const Color dcTimerArcStart = Color(0xFFA11D00);
  static const Color dcTimerArcEnd = Color(0xFFFF504D);

  // Pre-action nudge strip — risk / opportunity / bonus themes
  static const Color nudgeRiskBg = Color(0xFFFEF2F2);
  static const Color nudgeRiskBorder = Color(0xFFFCA5A5);
  static const Color nudgeRiskText = Color(0xFFDC2626);
  static const Color nudgeRiskBadge = Color(0xFFFEE2E2);
  static const Color nudgeRiskSubtitle = Color(0xFF374151);

  static const Color nudgeOpportunityBg = Color(0xFFFFFBEB);
  static const Color nudgeOpportunityBorder = Color(0xFFFDE68A);
  static const Color nudgeOpportunityText = Color(0xFFD97706);
  static const Color nudgeOpportunityBadge = Color(0xFFFEF3C7);

  static const Color nudgeBonusBg = Color(0xFF1D4ED8);
  static const Color nudgeBonusBorder = Color(0xFF93C5FD);
  static const Color nudgeBonusBadge = Color(0xFF3B82F6);
  // nudgeBonusText uses n0 (white)

  static const Color dragHandle = Color(0xffD1D1D1);

  static const Color referralBannerBg = Color(0xFFF7F4DF);
  static const Color referralBannerTitle = Color(0xFF374151);
  static const Color referralBannerAmount = Color(0xFFD97706);
  static const Color referralBannerCta = Color(0xFF111827);

  //? Tiering Nudge Colors
  static const Color tierNudgePinkStart = Color(0xFFFEF1F7);
  static const Color tierNudgePinkEnd = Color(0xFFFDE4EF);
  static const Color tierNudgeText = Color(0xFF374151);

  //? Snabbit Udaan Banner Colors
  static const Color udaanBannerBorder = Color(0xFFF9AECF);
  static const Color udaanBannerFooterBg = Color(0xFFFEF1F7);
  static const Color udaanBannerTitle = Color(0xFF670632);
  static const Color udaanBannerSubtitle = Color(0xFF4B5563);
  static const Color udaanBannerButton = Color(0xFF1F2937);
  static const Color udaanPlayVideoBg = Color(0xFFF3F4F6);
  static const Color udaanPlayVideoTitle = Color(0xFF374151);

  //? Tier Background Colors (drawer "View tier" entry)
  static const Color tierBgBase = Color(0xFF4E3D2D);
  static const Color tierBgSilver = Color(0xFF363A3E);
  static const Color tierBgGold = Color(0xFF4E2B01);
  static const Color tierBgDiamond = Color(0xFF353C4D);
  static const Color tierBgPinkDiamond = Color(0xFF730552);

  //? Home tier-nudge theme colors (border == leading-image tint).
  static const Color nudgeGenericBorder = Color(0xFFF70F79);
  static const Color nudgeGenericTitle = Color(0xFF111827);
  static const Color nudgeBenefitsAccent = Color(0xFF059669);
  static const Color nudgeBenefitsTitle = Color(0xFF047857);
  static const Color nudgeBenefitsTint = Color(0xFFECFDF5);
  static const Color nudgeMotivationAccent = Color(0xFF2563EB);
  static const Color nudgeMotivationTint = Color(0xFFEFF6FF);
  // Tier-specific theme — border == title == image tint == accent; bg white → tint.
  static const Color nudgeTierBaseAccent = Color(0xFF755E49);
  static const Color nudgeTierBaseTint = Color(0xFFFFFBEB);
  static const Color nudgeTierSilverAccent = Color(0xFF6B7280);
  static const Color nudgeTierSilverTint = Color(0xFFF9FAFB);
  static const Color nudgeTierGoldAccent = Color(0xFFA1700F);
  static const Color nudgeTierGoldTint = Color(0xFFFFFBEB);
  static const Color nudgeTierDiamondAccent = Color(0xFF33647C);
  static const Color nudgeTierDiamondTint = Color(0xFFEBFAFF);
  static const Color nudgeTierPinkDiamondAccent = Color(0xFFB31884);
  static const Color nudgeTierPinkDiamondTint = Color(0xFFFEF1F7);

  //? Tier Badge v2 (pill per tier: background · border · label)
  static const Color tierBadgeBaseBg = Color(0xFFDFCFC2);
  static const Color tierBadgeBaseBorder = Color(0xFFFFFFFF);
  static const Color tierBadgeBaseText = Color(0xFF2A180E);
  static const Color tierBadgeSilverBg = Color(0xFFE5E7EB);
  static const Color tierBadgeSilverBorder = Color(0xFF9CA3AF);
  static const Color tierBadgeSilverText = Color(0xFF374151);
  static const Color tierBadgeGoldBg = Color(0xFFFEF3C7);
  static const Color tierBadgeGoldBorder = Color(0xFFFDE68A);
  static const Color tierBadgeGoldText = Color(0xFFB45309);
  static const Color tierBadgeDiamondBg = Color(0xFFCEE8F6);
  static const Color tierBadgeDiamondBorder = Color(0xFFA6C8D8);
  static const Color tierBadgeDiamondText = Color(0xFF2C466F);
  static const Color tierBadgePinkDiamondBg = Color(0xFFFDE4EF);
  static const Color tierBadgePinkDiamondBorder = Color(0xFFFBC9DF);
  static const Color tierBadgePinkDiamondText = Color(0xFFB31884);

  //? Tier Week Flag — per-tier flag background ("Week N" pennants)
  static const Color tierWeekFlagBase = Color(0xFF755E49);
  static const Color tierWeekFlagSilver = Color(0xFF4B5563);
  static const Color tierWeekFlagGold = Color(0xFFA1700F);
  static const Color tierWeekFlagDiamond = Color(0xFF33647C);
  static const Color tierWeekFlagPinkDiamond = Color(0xFFB31884);
}
