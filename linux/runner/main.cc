#include "my_application.h"

#include <cstdlib>

int main(int argc, char** argv) {
  // Unter (GNOME-)Wayland darf eine App ihre Fensterposition nicht selbst setzen
  // -> Sticky-Notes koennten sich Position/Lage nicht merken. Den GTK-Backend
  // daher standardmaessig auf X11 (XWayland) zwingen; dort funktionieren
  // setPosition/getPosition wie auf Windows. Muss VOR jeder GTK/GDK-Nutzung
  // gesetzt sein, daher ganz am Anfang von main(). Greift fuer jeden Prozess
  // (Hauptfenster + alle Sticky-Fenster, gleiche Binary). Mit overwrite=0
  // ueberschreibbar: `GDK_BACKEND=wayland ./notizblock` erzwingt natives Wayland.
  setenv("GDK_BACKEND", "x11", 0);

  g_autoptr(MyApplication) app = my_application_new();
  return g_application_run(G_APPLICATION(app), argc, argv);
}
