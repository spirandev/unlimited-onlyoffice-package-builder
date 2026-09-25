#!/bin/bash
#######################################################################
# Funções comuns do onlyoffice-ems-builder.
#
# Copyright (C) 2026 Pandora Tecnologia
# Licenciado sob a GNU General Public License 3.0 (ver LICENSE).
#######################################################################

# Todo código-fonte vem daqui. Nada é clonado de forks de terceiros.
UPSTREAM_GIT_BASE="https://github.com/ONLYOFFICE"

BUILDER_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-${BUILDER_ROOT}/work}"
PATCHES_DIR="${BUILDER_ROOT}/patches"
MOBILE_UI_DIR="${BUILDER_ROOT}/mobile-ui"

log() {
  echo "==> [$(date +%H:%M:%S)] $*"
}

die() {
  echo "ERRO: $*" >&2
  exit 1
}

# Carrega PRODUCT_VERSION, BUILD_NUMBER e EMS_REVISION do arquivo VERSION.
# Variáveis já definidas no ambiente têm precedência.
load_version() {
  local _pv="${PRODUCT_VERSION}" _bn="${BUILD_NUMBER}" _rev="${EMS_REVISION}"
  # shellcheck source=/dev/null
  source "${BUILDER_ROOT}/VERSION"
  PRODUCT_VERSION="${_pv:-$PRODUCT_VERSION}"
  BUILD_NUMBER="${_bn:-$BUILD_NUMBER}"
  EMS_REVISION="${_rev:-$EMS_REVISION}"
  UPSTREAM_TAG="v${PRODUCT_VERSION}.${BUILD_NUMBER}"
}

# SHA do commit para o qual a tag aponta no repositório oficial
# (resolve tags anotadas pelo ^{}).
upstream_tag_sha() {
  local _repo=$1 _tag=$2 _out _sha
  _out="$(git ls-remote --tags "${UPSTREAM_GIT_BASE}/${_repo}.git" "refs/tags/${_tag}" "refs/tags/${_tag}^{}")" \
    || die "não foi possível consultar ${_repo} no upstream"
  _sha="$(echo "${_out}" | awk '/\^\{\}$/ {print $1}')"
  [ -n "${_sha}" ] || _sha="$(echo "${_out}" | awk '{print $1}' | head -n1)"
  [ -n "${_sha}" ] || die "tag ${_tag} não existe em ${UPSTREAM_GIT_BASE}/${_repo}"
  echo "${_sha}"
}

# Garante ${WORK_DIR}/<repo> clonado do ONLYOFFICE oficial na tag pedida e
# confere que o HEAD é exatamente o commit da tag no upstream.
# Uso: clone_official <repo> <tag> [--recurse-submodules]
clone_official() {
  local _repo=$1 _tag=$2 _recurse=$3 _dir="${WORK_DIR}/$1" _expected _head
  # die dentro de $(...) só encerra o subshell, por isso o exit explícito
  _expected="$(upstream_tag_sha "${_repo}" "${_tag}")" || exit 1

  if [ ! -d "${_dir}/.git" ]; then
    log "clonando ${_repo} ${_tag} do upstream oficial"
    if [ "${_recurse}" == "--recurse-submodules" ]; then
      git -c advice.detachedHead=false clone --quiet --depth 1 --branch "${_tag}" --recurse-submodules --shallow-submodules \
        "${UPSTREAM_GIT_BASE}/${_repo}.git" "${_dir}" || die "falha ao clonar ${_repo}"
    else
      git -c advice.detachedHead=false clone --quiet --depth 1 --branch "${_tag}" \
        "${UPSTREAM_GIT_BASE}/${_repo}.git" "${_dir}" || die "falha ao clonar ${_repo}"
    fi
  fi

  _head="$(git -C "${_dir}" rev-parse HEAD)"
  [ "${_head}" == "${_expected}" ] \
    || die "${_repo}: HEAD ${_head} difere da tag oficial ${_tag} (${_expected})"
  log "${_repo}: HEAD ${_head:0:12} confere com ${_tag} oficial"
}

# Aplica patches/<repo>/*.patch em ordem. É idempotente: patch já aplicado
# (retomada de build) é detectado e pulado; patch que não encaixa aborta.
apply_patches() {
  local _repo=$1 _dir="${WORK_DIR}/$1" _patch
  shopt -s nullglob
  for _patch in "${PATCHES_DIR}/${_repo}"/*.patch; do
    if git -C "${_dir}" apply --reverse --check "${_patch}" 2>/dev/null; then
      log "${_repo}: $(basename "${_patch}") já aplicado"
    elif git -C "${_dir}" apply --check "${_patch}"; then
      git -C "${_dir}" apply "${_patch}"
      log "${_repo}: $(basename "${_patch}") aplicado"
    else
      die "${_repo}: $(basename "${_patch}") não aplica em ${UPSTREAM_TAG}; ajuste o patch"
    fi
  done
  shopt -u nullglob
  git -C "${_dir}" --no-pager diff --stat
}

# Troca apps/<editor>/mobile/src/lib/patch.jsx do web-apps por
# mobile-ui/<editor>/patch.jsx (a interface de edição mobile). Antes confere que o
# stub da tag (blob em HEAD, sem depender do que já está no disco) é o de
# mobile-ui/upstream-stubs: se o upstream mudar o stub, o build para. A cópia é
# refeita a cada execução, então retomar o build é seguro.
apply_mobile_ui() {
  local _dir="${WORK_DIR}/web-apps" _stubs="${MOBILE_UI_DIR}/upstream-stubs"
  local _src _editor _path _expected _actual
  shopt -s nullglob
  for _src in "${MOBILE_UI_DIR}"/*/patch.jsx; do
    _editor="$(basename "$(dirname "${_src}")")"
    _path="apps/${_editor}/mobile/src/lib/patch.jsx"
    _expected="$(awk -v e="${_editor}" '$1 == e {print $2}' "${_stubs}")"
    [ -n "${_expected}" ] || die "mobile-ui: ${_editor} sem blob em mobile-ui/upstream-stubs"
    # um patch de patches/web-apps no mesmo arquivo seria sobrescrito aqui e
    # quebraria a retomada (git apply --reverse --check falharia)
    grep -rqs --include='*.patch' -e "^+++ b/${_path}$" "${PATCHES_DIR}/web-apps" \
      && die "mobile-ui: ${_path} também é alterado por um patch de patches/web-apps; tire o trecho do patch"
    _actual="$(git -C "${_dir}" rev-parse "HEAD:${_path}" 2>/dev/null)" \
      || die "web-apps: ${_path} não existe em ${UPSTREAM_TAG}"
    [ "${_actual}" == "${_expected}" ] \
      || die "web-apps: o stub ${_path} mudou em ${UPSTREAM_TAG} (${_actual:0:12}, esperado ${_expected:0:12}); revise mobile-ui/${_editor}/patch.jsx e atualize mobile-ui/upstream-stubs"
    cp "${_src}" "${_dir}/${_path}" || die "falha ao copiar mobile-ui/${_editor}/patch.jsx"
    log "web-apps: mobile-ui/${_editor}/patch.jsx aplicado sobre o stub ${_expected:0:12}"
  done
  shopt -u nullglob
}

# A partir da 9.4.0 o upstream removeu o limite de 20 conexões do Community
# (license.js passou a usar LICENSE_CONNECTIONS_OS). Se uma versão futura voltar
# a usar o limite antigo, o build para aqui, antes de gerar uma imagem limitada.
check_no_connection_limit() {
  local _license="${WORK_DIR}/server/Common/sources/license.js"
  [ -f "${_license}" ] || die "não encontrei ${_license}"
  if ! grep -q "connections: constants.LICENSE_CONNECTIONS_OS" "${_license}" \
     || grep -qE "constants\.LICENSE_CONNECTIONS([^_]|$)" "${_license}"; then
    die "license.js voltou a limitar conexões nesta versão; é preciso um patch em patches/server/"
  fi
  log "server: license.js sem o limite de 20 conexões"
}

# depot_tools fixado. O build_tools (v8_89.py, igual na 9.3.1 e na 9.4.0) clona
# o master do depot_tools e fixa o Python do bootstrap em 3.8.10, mas desde
# 3d401c263 (2025-11-21, "Caffeinate fetches on Mac") o fetch.py do master usa
# argparse.BooleanOptionalAction (Python >= 3.9): o "fetch v8" falha calado e o
# gclient sync dá "client not configured". DEPOT_TOOLS_PIN é o commit anterior,
# o último que roda com 3.8.10. Só atualize quando o build_tools subir a versão
# do Python em change_bootstrap().
DEPOT_TOOLS_URL="https://chromium.googlesource.com/chromium/tools/depot_tools.git"
DEPOT_TOOLS_PIN="b738decbefed1d63cc0238e4f3cac6665574f163"
DEPOT_TOOLS_MIRROR="${WORK_DIR}/cache/depot_tools.git"
V8_DIR="${WORK_DIR}/core/Common/3dParty/v8_89"

# Mantém em ${DEPOT_TOOLS_MIRROR} um clone bare do depot_tools cujo main aponta
# para ${DEPOT_TOOLS_PIN}. O docker run redireciona o git clone do build_tools
# para ele (url.insteadOf), sem alterar o código do build_tools. Um depot_tools
# que já esteja em work/ em outra revisão é apagado junto com o v8 baixado por
# ele, porque o v8_89.py não clona de novo um diretório que já existe.
prepare_depot_tools() {
  local _head
  if [ ! -d "${DEPOT_TOOLS_MIRROR}" ]; then
    log "clonando o depot_tools (espelho local fixado)"
    mkdir -p "$(dirname "${DEPOT_TOOLS_MIRROR}")"
    git clone --quiet --bare "${DEPOT_TOOLS_URL}" "${DEPOT_TOOLS_MIRROR}" \
      || die "falha ao clonar o depot_tools"
  fi
  if ! git -C "${DEPOT_TOOLS_MIRROR}" cat-file -e "${DEPOT_TOOLS_PIN}^{commit}" 2>/dev/null; then
    git -C "${DEPOT_TOOLS_MIRROR}" fetch --quiet origin || die "falha ao atualizar o depot_tools"
    git -C "${DEPOT_TOOLS_MIRROR}" cat-file -e "${DEPOT_TOOLS_PIN}^{commit}" \
      || die "commit ${DEPOT_TOOLS_PIN} não existe no depot_tools"
  fi
  git -C "${DEPOT_TOOLS_MIRROR}" update-ref refs/heads/main "${DEPOT_TOOLS_PIN}"
  git -C "${DEPOT_TOOLS_MIRROR}" symbolic-ref HEAD refs/heads/main

  if [ -d "${V8_DIR}/depot_tools" ]; then
    # os arquivos são do root (criados no container)
    _head="$(git -c safe.directory='*' -C "${V8_DIR}/depot_tools" rev-parse HEAD 2>/dev/null)"
    if [ "${_head}" != "${DEPOT_TOOLS_PIN}" ]; then
      log "depot_tools em work/ está em ${_head:-revisão desconhecida}, apagando o v8_89 para clonar de novo"
      docker run --rm -v "${WORK_DIR}:/w" ubuntu:24.04 rm -rf /w/core/Common/3dParty/v8_89 \
        || die "falha ao apagar ${V8_DIR}"
    fi
  fi
  log "depot_tools fixado em ${DEPOT_TOOLS_PIN:0:12}"
}

# Remove ${WORK_DIR} inteiro. Os arquivos gerados pelos containers pertencem ao
# root, por isso a remoção é feita dentro de um container.
wipe_work_dir() {
  [ -d "${WORK_DIR}" ] || return 0
  log "limpando ${WORK_DIR}"
  docker run --rm -v "${WORK_DIR}:/w" ubuntu:24.04 find /w -mindepth 1 -delete \
    || die "falha ao limpar ${WORK_DIR}"
}

# Prepara ${WORK_DIR} para a tag atual. Se ele contém outra versão, é limpo,
# porque o build_tools não refaz checkout de repositórios que já existem.
prepare_work_dir() {
  mkdir -p "${WORK_DIR}"
  if [ -f "${WORK_DIR}/.tag" ] && [ "$(cat "${WORK_DIR}/.tag")" != "${UPSTREAM_TAG}" ]; then
    log "work/ contém $(cat "${WORK_DIR}/.tag"), trocando para ${UPSTREAM_TAG}"
    wipe_work_dir
  fi
  echo "${UPSTREAM_TAG}" > "${WORK_DIR}/.tag"
}
