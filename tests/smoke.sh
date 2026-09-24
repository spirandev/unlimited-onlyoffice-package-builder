#!/bin/bash
#######################################################################
# Teste rápido da imagem gerada: sobe um container temporário, espera o
# healthcheck e confere que os editores mobile saíram com a edição liberada.
#
# Copyright (C) 2026 Pandora Tecnologia
# Licenciado sob a GNU General Public License 3.0 (ver LICENSE).
#######################################################################

# Uso: tests/smoke.sh [imagem:tag] [porta]
# Padrão: ems-documentserver:<versão do VERSION> na porta 8099.
# Também serve para confirmar que a imagem oficial FALHA na checagem mobile:
#   tests/smoke.sh onlyoffice/documentserver:9.4.0.1

set -o pipefail

source "$(dirname "$0")/../lib/common.sh"
load_version

IMAGE="${1:-ems-documentserver:${PRODUCT_VERSION}.${BUILD_NUMBER}-ems.${EMS_REVISION}}"
PORT="${2:-8099}"
NAME="ems-ds-smoke-$$"
FAILED=0

cleanup() {
  docker rm -f "${NAME}" > /dev/null 2>&1
}
trap cleanup EXIT

check() {
  local _desc=$1
  shift
  if "$@"; then
    echo "  OK    ${_desc}"
  else
    echo "  FALHA ${_desc}"
    FAILED=1
  fi
}

log "subindo ${IMAGE} em 127.0.0.1:${PORT}"
docker run -d --name "${NAME}" -p "127.0.0.1:${PORT}:80" \
  -e JWT_ENABLED=true -e JWT_SECRET="smoke-$(date +%s)" \
  "${IMAGE}" > /dev/null || die "falha ao subir o container"

log "aguardando o healthcheck (até 5 min)"
HEALTH=""
for _ in $(seq 1 60); do
  HEALTH="$(curl -fs "http://127.0.0.1:${PORT}/healthcheck" 2>/dev/null)"
  [ "${HEALTH}" == "true" ] && break
  sleep 5
done

# Cada editor mobile deve ter isSupportEditFeature retornando true. O bundle é
# minificado, então aceitamos as formas "() => true", "()=>!0" e
# "function(){return!0}"; qualquer "false"/"!1" reprova.
mobile_edit_enabled() {
  local _app=$1 _found
  _found="$(docker exec "${NAME}" sh -c \
    "grep -rhoE 'isSupportEditFeature *= *[^;,]{0,40}' /var/www/onlyoffice/documentserver/web-apps/apps/${_app}/mobile 2>/dev/null" | head -n1)"
  echo "        ${_app}: ${_found:-(não encontrado)}"
  [ -n "${_found}" ] && echo "${_found}" | grep -qE 'true|!0' && ! echo "${_found}" | grep -qE 'false|!1'
}

echo
echo "Resultados (${IMAGE}):"
check "healthcheck responde true" test "${HEALTH}" == "true"
check "api.js disponível" curl -fs -o /dev/null "http://127.0.0.1:${PORT}/web-apps/apps/api/documents/api.js"
check "edição mobile liberada (documento)" mobile_edit_enabled documenteditor
check "edição mobile liberada (apresentação)" mobile_edit_enabled presentationeditor
check "edição mobile liberada (planilha)" mobile_edit_enabled spreadsheeteditor
echo

if [ "${FAILED}" -ne 0 ]; then
  echo "Logs do container (últimas 30 linhas):"
  docker logs --tail 30 "${NAME}" 2>&1
  die "smoke test reprovado"
fi
log "smoke test aprovado"
