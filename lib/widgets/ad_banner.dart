import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../providers/monetization_providers.dart';

/// Free-tier banner slot pinned under the Bills list. Collapses to
/// nothing for Ad-Free subscribers, before the ad loads, and in
/// tests (the controller never loads an ad there).
class AdBannerSlot extends StatelessWidget {
  const AdBannerSlot({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final isAdFree = ref.watch(adFreeStatusProvider).value ?? false;
        if (isAdFree) return const SizedBox.shrink();
        final banner = ref.watch(adBannerControllerProvider);
        final ad = banner.ad;
        if (ad == null || !banner.loaded) return const SizedBox.shrink();
        return SafeArea(
          top: false,
          child: SizedBox(
            width: ad.size.width.toDouble(),
            height: ad.size.height.toDouble(),
            child: AdWidget(ad: ad),
          ),
        );
      },
    );
  }
}
