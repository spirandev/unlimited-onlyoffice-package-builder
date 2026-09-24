#!/bin/bash

#######################################################################
# OnlyOffice Deb Builder (fork EMS)

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

# Roda dentro do container ems-oo-deb-builder, chamado pelo
# onlyoffice-package-builder.sh. Espera:
#   /root/document-server-package  clone oficial (já verificado no host)
#   /root/build_tools/out          binários compilados
# e as variáveis PRODUCT_VERSION, BUILD_NUMBER e DEBIAN_PACKAGE_SUFFIX.
#
# No original do btactic este script clonava o document-server-package de
# um fork e aplicava um cherry-pick (Admin Panel). Aqui o clone é feito e
# conferido no host, e o Admin Panel não entra (o código dele não é público).

set -e

for _var in PRODUCT_VERSION BUILD_NUMBER DEBIAN_PACKAGE_SUFFIX; do
  if [ -z "${!_var}" ]; then
    echo "ERRO: variável ${_var} não informada" >&2
    exit 1
  fi
done

DOCUMENT_SERVER_PACKAGE_PATH="/root/document-server-package"
cd "${DOCUMENT_SERVER_PACKAGE_PATH}"

# Instala as dependências de build declaradas no debian/control gerado.
# O Makefile oficial não tem um alvo só para gerar os arquivos de debian/,
# por isso o alvo deb_dependencies é acrescentado (uma vez só, para permitir
# reexecução).
if ! grep -q '^deb_dependencies:' Makefile; then
  cat << EOF >> Makefile

deb_dependencies: \$(DEB_DEPS)

EOF
fi

PRODUCT_VERSION="${PRODUCT_VERSION}" BUILD_NUMBER="${BUILD_NUMBER}${DEBIAN_PACKAGE_SUFFIX}" make deb_dependencies
cd "${DOCUMENT_SERVER_PACKAGE_PATH}/deb/build"
apt-get -qq build-dep -y ./

cd "${DOCUMENT_SERVER_PACKAGE_PATH}"
PRODUCT_VERSION="${PRODUCT_VERSION}" BUILD_NUMBER="${BUILD_NUMBER}${DEBIAN_PACKAGE_SUFFIX}" make deb
