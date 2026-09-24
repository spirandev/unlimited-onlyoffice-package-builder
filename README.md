# onlyoffice-ems-builder

Compila o **ONLYOFFICE Document Server Community** a partir do código-fonte oficial, com a **edição mobile liberada**,
e gera um pacote `.deb` e uma imagem Docker que substitui a oficial (`onlyoffice/documentserver`).

É um fork do [btactic-oo/unlimited-onlyoffice-package-builder](https://github.com/btactic-oo/unlimited-onlyoffice-package-builder),
revisado e adaptado. Não é um build oficial da ONLYOFFICE: problemas devem ser reproduzidos na imagem oficial antes de
serem reportados a eles.

## O que muda em relação ao oficial

| Trava do Community | Situação | Como |
|---|---|---|
| Edição nos editores mobile | **Liberada** | [`patches/web-apps/0001-enable-mobile-edit.patch`](patches/web-apps/0001-enable-mobile-edit.patch): `isSupportEditFeature()` retorna `true` (3 linhas) |
| 20 conexões simultâneas | Já removida pelo upstream a partir da **9.4.0** | Sem patch. O build **falha** se uma versão futura voltar a limitar (`check_no_connection_limit` em `lib/common.sh`) |

Mais nada é alterado: logo, marca, créditos, configuração, fontes e o restante do código são os oficiais.

## Diferenças em relação ao builder do btactic

- **Origem do código:** tudo é clonado de `github.com/ONLYOFFICE` na tag oficial, e o `HEAD` é conferido contra o SHA
  da tag no upstream. O original clonava forks do btactic e usava a tag desses forks, que podia apontar para outro
  commit.
- **Patches como arquivos** em `patches/<repo>/`, aplicados com `git apply --check`/`git apply`. O original fazia
  cherry-pick de commits de repositórios de terceiros.
- **Sem o patch de conexões** (desnecessário na 9.4) e **sem o Admin Panel**. O código do painel fica no repositório
  `ONLYOFFICE/server-admin-panel`, que não é público, e o patch do btactic só ligava o empacotamento dele.
- **Compatível com o `build_tools` 9.4**, que prepara python/Qt/sysroot no `automate.py` e não mais no Dockerfile. O
  comando do original não funciona nessa versão.
- **Build retomável:** tudo fica em `work/`, que é mantido entre execuções.
- **Imagem Docker:** gerada com o `Dockerfile` oficial do `ONLYOFFICE/Docker-DocumentServer` na mesma tag, sem
  alterações, instalando o nosso `.deb`.
- O workflow de GitHub Actions do original foi removido, porque o build é feito localmente. O workflow também apagava
  todas as imagens Docker do host.

## Requisitos

- Linux x86_64 com Docker e o usuário no grupo `docker` (não precisa de `sudo`).
- **16 GB de RAM** livres (ou 8 GB + 8 GB de swap) e **60 GB de disco** livres.
- `git`, `curl` e `python3` no host.
- Conexão com a internet: o `build_tools` baixa dependências (Qt, sysroot, v8, boost, etc.), igual ao build oficial.
- Tempo: várias horas com 4 CPUs. Rode dentro de `tmux`/`screen`.

## Uso

A versão base fica no arquivo [`VERSION`](VERSION). Para descobrir o `BUILD_NUMBER` de uma versão oficial:
`apt-cache show onlyoffice-documentserver` (repositório oficial) → `Version: 9.4.0-129` → `BUILD_NUMBER=129`.

```bash
# 1. binários + pacote .deb (em work/document-server-package/deb/)
./onlyoffice-package-builder.sh

# 2. imagem Docker ems-documentserver:<versão>.<build>-ems.<revisão>
./docker/build-image.sh

# 3. teste rápido (healthcheck + edição mobile no bundle)
./tests/smoke.sh
```

Se o build falhar por rede ou disco, basta rodar de novo: o que já foi baixado e compilado em `work/` é
reaproveitado. `--clean` recomeça do zero. `--binaries-only` e `--deb-only` executam só uma das etapas.

Os roteiros manuais de validação estão em [`tests/mobile.md`](tests/mobile.md) e
[`tests/connections.md`](tests/connections.md).

## Atualizar para uma nova versão oficial

1. Atualizar `PRODUCT_VERSION`/`BUILD_NUMBER` em `VERSION` e voltar `EMS_REVISION` para `1`.
2. `./onlyoffice-package-builder.sh`. O `work/` é limpo automaticamente ao trocar de versão.
   - Se um patch não aplicar, o build para e informa qual. Ajuste o arquivo em `patches/` na nova tag.
   - Se o upstream voltar a limitar conexões, o build para em `check_no_connection_limit`.
3. `./docker/build-image.sh`, `./tests/smoke.sh` e os roteiros manuais.

Correções de segurança publicadas pela ONLYOFFICE devem entrar aqui com a mesma prioridade da imagem oficial.

## Licença

- O ONLYOFFICE Document Server é licenciado sob a **AGPL v3** com os termos adicionais da §7 (logo e marca). A imagem
  gerada preserva logo e créditos da ONLYOFFICE. Por causa da §13, este repositório (com os patches) fica público para
  quem usa o serviço pela rede.
- Os scripts deste builder são **GPL v3** ([LICENSE](LICENSE)), herdados do btactic. Os copyrights originais foram
  mantidos nos arquivos.
- `development_logs/` são os registros originais do btactic, mantidos como referência histórica.
