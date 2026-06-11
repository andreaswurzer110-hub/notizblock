#include "my_application.h"

#include <cstdlib>

int main(int argc, char** argv) {
  // Unter (GNOME-)Wayland darf eine App ihre Fensterposition nicht selbst setzen
  // -> Sticky-Notes koennten sich Position/Lage nicht merken. Den GTK-Backend
  // daher auf X11 (XWayland) zwingen; dort funktionieren setPosition/getPosition
  // wie auf Windows. Muss VOR jeder GTK/GDK-Nutzung gesetzt sein, daher ganz am
  // Anfang von main(). Greift fuer jeden Prozess (Hauptfenster + alle
  // Sticky-Fenster, gleiche Binary).
  //
  // Im Snap setzt der gnome-Launcher GDK_BACKEND=wayland VOR uns -> dann bliebe
  // es bei Wayland und die Position ginge verloren. Daher unter Snap (SNAP
  // gesetzt) hart erzwingen (overwrite=1). Sonst overwrite=0, damit man es per
  // `GDK_BACKEND=wayland ./notizblock` weiterhin auf natives Wayland stellen kann.
  if (getenv("SNAP") != nullptr) {
    setenv("GDK_BACKEND", "x11", 1);
  } else {
    setenv("GDK_BACKEND", "x11", 0);
  }

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
