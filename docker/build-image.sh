#!/bin/bash
#######################################################################
# Gera a imagem Docker do Document Server a partir do .deb do fork.
#
# Copyright (C) 2026 Pandora Tecnologia
# Licenciado sob a GNU General Public License 3.0 (ver LICENSE).
#######################################################################

# Usa o Dockerfile oficial do ONLYOFFICE/Docker-DocumentServer na mesma tag,
# sem alterações. Ele baixa o pacote de ${PACKAGE_BASEURL}/<nome do .deb>;
# aqui o PACKAGE_BASEURL aponta para um servidor HTTP local e temporário que
# serve só o nosso .deb.

set -o pipefail

source "$(dirname "$0")/../lib/common.sh"

usage() {
cat <<EOF

  $0 [--image=NOME] [--debian-package-suffix=-SUF]

  Gera a imagem <NOME>:<versão>.<build>-ems.<EMS_REVISION> (VERSION).
  Padrão: --image=ems-documentserver --debian-package-suffix=-ems

EOF
}

IMAGE_NAME="ems-documentserver"
DEBIAN_PACKAGE_SUFFIX="-ems"

for option in "$@"; do
  case "$option" in
    -h | --help)
      usage
      exit 0
    ;;
    --image=*)
      IMAGE_NAME="${option#--image=}"
    ;;
    --debian-package-suffix=*)
      DEBIAN_PACKAGE_SUFFIX="${option#--debian-package-suffix=}"
    ;;
    *)
      usage
      die "opção desconhecida: $option"
    ;;
  esac
done

load_version

PACKAGE_VERSION="${PRODUCT_VERSION}-${BUILD_NUMBER}${DEBIAN_PACKAGE_SUFFIX}"
DEB_FILE="onlyoffice-documentserver_${PACKAGE_VERSION}_amd64.deb"
DEB_DIR="${WORK_DIR}/document-server-package/deb"
IMAGE_TAG="${IMAGE_NAME}:${PRODUCT_VERSION}.${BUILD_NUMBER}-ems.${EMS_REVISION}"

[ -f "${DEB_DIR}/${DEB_FILE}" ] || die "não encontrei ${DEB_DIR}/${DEB_FILE}; rode o onlyoffice-package-builder.sh antes"
[ "$(cat "${WORK_DIR}/.tag" 2>/dev/null)" == "${UPSTREAM_TAG}" ] || die "work/ não corresponde a ${UPSTREAM_TAG}"

clone_official Docker-DocumentServer "${UPSTREAM_TAG}"

# Porta livre escolhida pelo sistema, só em 127.0.0.1.
HTTP_PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1", 0)); print(s.getsockname()[1])')"
python3 -m http.server "${HTTP_PORT}" --bind 127.0.0.1 --directory "${DEB_DIR}" > /dev/null 2>&1 &
HTTP_PID=$!
trap 'kill ${HTTP_PID} 2>/dev/null' EXIT

for _ in $(seq 1 20); do
  curl -fsI "http://127.0.0.1:${HTTP_PORT}/${DEB_FILE}" > /dev/null 2>&1 && break
  sleep 0.5
done
curl -fsI "http://127.0.0.1:${HTTP_PORT}/${DEB_FILE}" > /dev/null 2>&1 || die "servidor HTTP local não respondeu"

log "gerando ${IMAGE_TAG} a partir de ${DEB_FILE}"
# --network host: o build precisa alcançar o servidor em 127.0.0.1.
docker build \
  --network host \
  --target documentserver-community \
  --build-arg PACKAGE_BASEURL="http://127.0.0.1:${HTTP_PORT}" \
  --build-arg PACKAGE_VERSION="${PACKAGE_VERSION}" \
  --label "org.opencontainers.image.version=${PRODUCT_VERSION}.${BUILD_NUMBER}-ems.${EMS_REVISION}" \
  --label "org.opencontainers.image.base.name=ONLYOFFICE Document Server ${UPSTREAM_TAG}" \
  --label "org.opencontainers.image.licenses=AGPL-3.0-only" \
  --tag "${IMAGE_TAG}" \
  "${WORK_DIR}/Docker-DocumentServer" \
  || die "falha no docker build da imagem"

log "imagem pronta: ${IMAGE_TAG}"
