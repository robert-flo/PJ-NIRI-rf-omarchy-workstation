#!/usr/bin/env bash
# Menú rápido de energía para Wayland usando fuzzel

OPCIONES="🔄 Reiniciar Equipo (Reboot)\n🛑 Apagar Equipo (Power Off)\n🚪 Cerrar Sesión (Log Out)\n💤 Suspender (Suspend)"

SELECCION=$(echo -e "$OPCIONES" | fuzzel --dmenu --prompt "Energía: " --width 30 --lines 4)

case "$SELECCION" in
    *"Reiniciar"*)
        systemctl reboot -i
        ;;
    *"Apagar"*)
        systemctl poweroff -i
        ;;
    *"Cerrar Sesión"*)
        hyprctl dispatch exit 2>/dev/null || niri msg action quit 2>/dev/null || loginctl terminate-session "${XDG_SESSION_ID:-self}"
        ;;
    *"Suspender"*)
        systemctl suspend
        ;;
esac
