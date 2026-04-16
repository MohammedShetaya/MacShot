import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            WallpaperSettingsView()
                .tabItem {
                    Label("Wallpaper", systemImage: "photo")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            QuickAccessSettingsView()
                .tabItem {
                    Label("Quick Access", systemImage: "bolt.circle")
                }

            AnnotateSettingsView()
                .tabItem {
                    Label("Annotate", systemImage: "pencil.tip.crop.circle")
                }

            AdvancedSettingsView()
                .tabItem {
                    Label("Advanced", systemImage: "gearshape.2")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .tabViewStyle(.automatic)
        .frame(width: 550, height: 420)
    }
}
