#!/bin/bash

#######################################################################
# OnlyOffice Package Builder (fork EMS)

# Copyright (C) 2024 BTACTIC, SCCL
# Copyright (C) 2026 Pandora Tecnologia (alterações do fork EMS)

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#######################################################################

# Diferenças em relação ao builder original do btactic:
# - todo código é clonado de github.com/ONLYOFFICE e o HEAD é conferido
#   contra a tag oficial (nada vem de forks de terceiros);
# - as alterações são arquivos em patches/<repo>/, aplicados com git apply;
# - o build_tools da 9.4 prepara python/Qt/sysroot no automate.py (não mais
#   no Dockerfile), por isso o build roda por ele;
# - tudo fica em work/, que sobrevive entre execuções para retomar um build
#   que falhou por rede ou disco.

set -o pipefail

source "$(dirname "$0")/lib/common.sh"

usage() {
cat <<EOF

  $0 [opções]

  Compila o ONLYOFFICE Document Server a partir do código oficial com os
  patches de patches/ e gera o pacote .deb. Versão padrão: arquivo VERSION.

  Opções:
    --product-version=X.Y.Z       sobrescreve PRODUCT_VERSION do VERSION
    --build-number=N              sobrescreve BUILD_NUMBER do VERSION
    --debian-package-suffix=-SUF  sufixo do pacote (padrão: -ems)
    --binaries-only               só compila (build_tools)
    --deb-only                    só empacota (exige binários já compilados)
    --clean                       apaga work/ antes de começar

  Exemplo: $0
           $0 --product-version=9.4.0 --build-number=129

EOF
}

BINARIES_ONLY="false"
DEB_ONLY="false"
CLEAN="false"
DEBIAN_PACKAGE_SUFFIX="-ems"

for option in "$@"; do
  case "$option" in
    -h | --help)
      usage
      exit 0
    ;;
    --product-version=*)
      PRODUCT_VERSION="${option#--product-version=}"
    ;;
    --build-number=*)
      BUILD_NUMBER="${option#--build-number=}"
    ;;
    --debian-package-suffix=*)
      DEBIAN_PACKAGE_SUFFIX="${option#--debian-package-suffix=}"
    ;;
    --binaries-only)
      BINARIES_ONLY="true"
    ;;
    --deb-only)
      DEB_ONLY="true"
    ;;
    --clean)
      CLEAN="true"
    ;;
    *)
      usage
      die "opção desconhecida: $option"
    ;;
  esac
done

load_version

[ "${BINARIES_ONLY}" == "true" ] && [ "${DEB_ONLY}" == "true" ] \
  && die "--binaries-only e --deb-only são excludentes"

docker info > /dev/null 2>&1 || die "sem acesso ao Docker (usuário precisa estar no grupo docker)"

log "versão ${PRODUCT_VERSION} build ${BUILD_NUMBER} (tag ${UPSTREAM_TAG}), sufixo ${DEBIAN_PACKAGE_SUFFIX}"

[ "${CLEAN}" == "true" ] && wipe_work_dir
prepare_work_dir

build_oo_binaries() {
  clone_official server "${UPSTREAM_TAG}"
  clone_official web-apps "${UPSTREAM_TAG}"
  clone_official build_tools "${UPSTREAM_TAG}"

  check_no_connection_limit
  apply_patches server
  apply_patches web-apps
  prepare_depot_tools

  # packages_complete marca que o deps.py instalou os pacotes do sistema. Os
  # pacotes vivem no container (descartado a cada execução), então a marca é
  # removida para que sejam reinstalados. python3, qt_build e sysroot ficam em
  # work/build_tools e são reaproveitados.
  rm -f "${WORK_DIR}/build_tools/tools/linux/packages_complete"

  # Contexto vazio: o ADD . do Dockerfile não é usado (work/ é montado no
  # docker run) e, a partir da segunda execução, work/build_tools tem o sysroot
  # baixado pelo container, com diretórios do root que o docker build não lê.
  # O /build_tools da imagem fica vazio, o que não importa: o docker run usa
  # -w /work/build_tools/tools/linux. O diretório temporário é apagado nos dois
  # caminhos (sucesso e falha).
  log "gerando a imagem do build_tools"
  local empty_ctx
  empty_ctx="$(mktemp -d)"
  docker build --tag "ems-oo-build-tools:${UPSTREAM_TAG}" \
    -f "${WORK_DIR}/build_tools/Dockerfile" "${empty_ctx}" \
    || { rmdir "${empty_ctx}"; die "falha no docker build do build_tools"; }
  rmdir "${empty_ctx}"

  # work/ é montado inteiro: os repositórios que o build_tools clona (core,
  # sdkjs, ...) ficam ao lado de server/ e web-apps/ e persistem entre execuções.
  # O container roda como root sobre repositórios do usuário: safe.directory
  # evita a recusa do git por "dubious ownership".
  # DEPOT_TOOLS_DIR absoluto: o v8_89.py chama ./depot_tools/fetch com caminho
  # relativo, e o depot_tools exporta esse caminho e
  # depois faz cd para dentro dele antes de rodar ./cipd, que então procura
  # depot_tools/depot_tools/cipd_client_version.digests ("Platform linux-amd64
  # is not supported by CIPD client bootstrap"). Como todos os scripts usam
  # ${DEPOT_TOOLS_DIR:-...}, o valor fixado aqui vence. O caminho acompanha o
  # ponto de montagem /work abaixo: se ele mudar, ajuste os dois.
  # depot_tools fixado: o /root/.gitconfig do container redireciona o git clone
  # do depot_tools feito pelo v8_89.py para o espelho em work/cache (ver
  # prepare_depot_tools em lib/common.sh), e DEPOT_TOOLS_UPDATE=0 impede o
  # depot_tools de se atualizar sozinho. O arquivo é escrito com printf porque
  # o git só é instalado depois, pelo deps.py. Precisa ser a config global
  # (não GIT_CONFIG_*), porque o upload-pack do clone local não herda essas
  # variáveis e recusaria o espelho, que é do usuário, por "dubious ownership".
  log "compilando (módulo server). Isso leva horas."
  docker run --rm \
    -e PRODUCT_VERSION="${PRODUCT_VERSION}" \
    -e BUILD_NUMBER="${BUILD_NUMBER}" \
    -e NODE_ENV='production' \
    -e DEPOT_TOOLS_DIR=/work/core/Common/3dParty/v8_89/depot_tools \
    -e DEPOT_TOOLS_UPDATE=0 \
    -v "${WORK_DIR}:/work" \
    -w /work/build_tools/tools/linux \
    "ems-oo-build-tools:${UPSTREAM_TAG}" \
    /bin/bash -c "printf '[safe]\\n\\tdirectory = /work/cache/depot_tools.git\\n[url \"/work/cache/depot_tools.git\"]\\n\\tinsteadOf = ${DEPOT_TOOLS_URL}\\n' >> /root/.gitconfig; \
      git config --global --add safe.directory '*' 2>/dev/null || true; \
      python3 ./automate.py server --branch=tags/${UPSTREAM_TAG} --update-light=1 --clean=0" \
    || die "falha no build_tools"

  [ -d "${WORK_DIR}/build_tools/out/linux_64/onlyoffice/documentserver" ] \
    || die "build terminou sem gerar out/linux_64/onlyoffice/documentserver"
  log "binários prontos em work/build_tools/out"
}

build_oo_deb() {
  [ -d "${WORK_DIR}/build_tools/out/linux_64/onlyoffice/documentserver" ] \
    || die "binários não encontrados; rode sem --deb-only primeiro"

  clone_official document-server-package "${UPSTREAM_TAG}" --recurse-submodules
  apply_patches document-server-package

  log "gerando a imagem do empacotador"
  docker build --tag ems-oo-deb-builder -f "${BUILDER_ROOT}/deb_build/Dockerfile-manual-debian-13" \
    "${BUILDER_ROOT}/deb_build" || die "falha no docker build do empacotador"

  docker run --rm \
    --env PRODUCT_VERSION="${PRODUCT_VERSION}" \
    --env BUILD_NUMBER="${BUILD_NUMBER}" \
    --env DEBIAN_PACKAGE_SUFFIX="${DEBIAN_PACKAGE_SUFFIX}" \
    -v "${BUILDER_ROOT}/deb_build:/usr/local/unlimited-onlyoffice-package-builder:ro" \
    -v "${WORK_DIR}/build_tools:/root/build_tools:ro" \
    -v "${WORK_DIR}/document-server-package:/root/document-server-package" \
    ems-oo-deb-builder \
    /bin/bash -c "git config --global --add safe.directory '*' 2>/dev/null || true; \
      /usr/local/unlimited-onlyoffice-package-builder/onlyoffice-deb-builder.sh" \
    || die "falha ao gerar o .deb"

  local _deb
  _deb="$(find "${WORK_DIR}/document-server-package/deb" -maxdepth 1 \
    -name "onlyoffice-documentserver_${PRODUCT_VERSION}-${BUILD_NUMBER}${DEBIAN_PACKAGE_SUFFIX}_amd64.deb" | head -n1)"
  [ -n "${_deb}" ] || die ".deb não encontrado em work/document-server-package/deb"
  log "pacote gerado: ${_deb}"
}

if [ "${DEB_ONLY}" != "true" ]; then
  build_oo_binaries
fi

if [ "${BINARIES_ONLY}" != "true" ]; then
  build_oo_deb
fi
