#!/usr/bin/env bash
# shellcheck disable=SC2016,SC2034  # literales a propósito; variables de salida para quien hace source
# ==============================================================================
# bashrc-overlay.sh — Asegura que ~/.bashrc cargue el overlay ravn-omarchy
# ==============================================================================
# Se carga con `source` desde onboard-machine.sh (paso 2.10) y desde el test
# tests/onboarding/test-bashrc-overlay.sh.
#
# El stub canónico es /usr/share/omarchy/etc-overrides/dot.bashrc (lo empaqueta
# omarchy-settings). Un ~/.bashrc copiado de un stub viejo no trae las dos
# líneas del overlay y entonces no cargan los alias rs/ri ni el env/rc de
# /usr/share/ravn/omarchy/bash/.
#
# asegurar_bashrc_overlay <bashrc> [stub]
#   - Si <bashrc> no existe: lo crea copiando el stub.
#   - Si existe: inserta cada línea que falte justo después de su ancla; si el
#     ancla no está, la pone en su sección (env: antes del corte de shells no
#     interactivos o al principio; rc: al final).
#   - Solo si cambia algo, respalda en <bashrc>.bak-<timestamp>.
#   - Nunca borra contenido del usuario. Idempotente.
#   - Respeta DRY_RUN=true (no escribe nada).
# Deja en BASHRC_CAMBIOS el número de cambios (0 o 1) y en BASHRC_DETALLE
# una descripción corta.
# ==============================================================================

BASHRC_STUB_DEFAULT="/usr/share/omarchy/etc-overrides/dot.bashrc"
BASHRC_ANCLA_ENV='[[ -r /usr/share/omarchy/default/bash/env-bootstrap ]] && source /usr/share/omarchy/default/bash/env-bootstrap'
BASHRC_LINEA_ENV='[[ -r /usr/share/ravn/omarchy/bash/env ]] && source /usr/share/ravn/omarchy/bash/env'
BASHRC_ANCLA_RC='source "$OMARCHY_PATH/default/bash/rc"'
BASHRC_LINEA_RC='[[ -r /usr/share/ravn/omarchy/bash/rc ]] && source /usr/share/ravn/omarchy/bash/rc'
BASHRC_CORTE_INTERACTIVO='[[ $- != *i* ]] && return'

# Calcula en stdout el contenido nuevo de un bashrc existente.
_bashrc_overlay_contenido() {
  awk -v ae="$BASHRC_ANCLA_ENV" -v le="$BASHRC_LINEA_ENV" \
      -v ar="$BASHRC_ANCLA_RC" -v lr="$BASHRC_LINEA_RC" \
      -v corte="$BASHRC_CORTE_INTERACTIVO" '
    function trim(s) { sub(/^[ \t]+/, "", s); sub(/[ \t\r]+$/, "", s); return s }
    { l[NR] = $0; t = trim($0)
      if (t == le) tiene_le = 1
      if (t == lr) tiene_lr = 1
      if (t == ae && !pos_ae) pos_ae = NR
      if (t == ar && !pos_ar) pos_ar = NR
      if (t == corte && !pos_corte) pos_corte = NR }
    END {
      # env: tras su ancla; si no, antes del corte interactivo; si no, al principio.
      if (!tiene_le && !pos_ae && !pos_corte) print le
      for (i = 1; i <= NR; i++) {
        if (!tiene_le && !pos_ae && pos_corte == i) print le
        print l[i]
        if (!tiene_le && pos_ae == i) print le
        if (!tiene_lr && pos_ar == i) print lr
      }
      # rc: tras su ancla; si no, al final.
      if (!tiene_lr && !pos_ar) print lr
    }' "$1"
}

asegurar_bashrc_overlay() {
  local bashrc="$1" stub="${2:-${BASHRC_STUB:-$BASHRC_STUB_DEFAULT}}" tmp ts
  BASHRC_CAMBIOS=0
  BASHRC_DETALLE=""
  # Si ~/.bashrc es un symlink (dotfiles), se edita el archivo real.
  [[ -L "$bashrc" ]] && bashrc="$(readlink -f "$bashrc")"

  if [[ ! -e "$bashrc" ]]; then
    if [[ ! -r "$stub" ]]; then
      BASHRC_DETALLE="falta $bashrc y no existe el stub $stub; no se crea"
      return 1
    fi
    BASHRC_CAMBIOS=1
    BASHRC_DETALLE="creado $bashrc desde $stub"
    [[ "${DRY_RUN:-false}" == true ]] && return 0
    cp "$stub" "$bashrc"
    chmod 644 "$bashrc"
    return 0
  fi

  tmp="$(mktemp "${bashrc}.tmp.XXXXXX")" || return 1
  _bashrc_overlay_contenido "$bashrc" > "$tmp"
  if cmp -s "$tmp" "$bashrc"; then
    rm -f "$tmp"
    BASHRC_DETALLE="$bashrc ya carga el overlay ravn-omarchy"
    return 0
  fi
  BASHRC_CAMBIOS=1
  BASHRC_DETALLE="insertadas las líneas del overlay ravn-omarchy en $bashrc"
  if [[ "${DRY_RUN:-false}" == true ]]; then
    rm -f "$tmp"
    return 0
  fi
  ts="$(date +%Y%m%d-%H%M%S)"
  cp -p "$bashrc" "${bashrc}.bak-${ts}"
  BASHRC_DETALLE="$BASHRC_DETALLE (respaldo: ${bashrc}.bak-${ts})"
  # Conserva permisos y dueño del original; reemplazo atómico.
  chmod --reference="$bashrc" "$tmp" 2>/dev/null || true
  chown --reference="$bashrc" "$tmp" 2>/dev/null || true
  mv -f "$tmp" "$bashrc"
  return 0
}
