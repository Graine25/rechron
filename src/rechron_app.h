
// rechron - ReXGlue Recompiled Project
//
// This file is yours to edit. 'rexglue migrate' will NOT overwrite it.
// Customize your app by overriding virtual hooks from rex::ReXApp.

#pragma once

#include <rex/rex_app.h>


class rechronApp : public rex::ReXApp {
 public:
  using rex::ReXApp::ReXApp;

  static std::unique_ptr<rex::ui::WindowedApp> Create(
      rex::ui::WindowedAppContext& ctx) {
    return std::unique_ptr<rechronApp>(new rechronApp(ctx, "rechron",
        PPCImageConfig));
  }

  // Override virtual hooks for customization:
  std::optional<rex::PathConfig> OnFinalizePaths(
      const rex::PathConfig& defaults,
      std::function<void(rex::PathConfig)> resume) override {
    (void)resume;
    rex::PathConfig paths = defaults;
    const std::string root = rex::cvar::GetFlagByName("chron_data_root");
    if (!root.empty()) {
      paths.game_data_root = root;
    }
    return paths;
  }

  // void OnConfigurePaths(rex::PathConfig& paths) override {}
};
