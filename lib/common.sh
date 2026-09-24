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
