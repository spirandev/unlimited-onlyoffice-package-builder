# Guia de build

Passo a passo para compilar o Document Server com a edição mobile liberada e gerar a imagem Docker
`ems-documentserver:<versão>-ems.<n>`, numa máquina Linux do zero.

Resumo, para quem já tem tudo instalado:

```bash
git clone https://github.com/spirandev/unlimited-onlyoffice-package-builder.git onlyoffice-ems-builder
cd onlyoffice-ems-builder
tmux new -s oo-build
./onlyoffice-package-builder.sh && ./docker/build-image.sh && ./tests/smoke.sh
```

---

## 1. Requisitos da máquina

| Item | Mínimo | Recomendado | Observação |
|---|---|---|---|
| Sistema | Linux x86_64 nativo ou WSL2 | Debian 12/13 ou Ubuntu 22.04/24.04 | macOS e Docker Desktop **não** servem: a geração da imagem usa `--network host` para ler o `.deb` de um servidor em `127.0.0.1` |
| CPU | 4 núcleos | 8 ou mais | O tempo de build cai quase linearmente com os núcleos |
| RAM livre | 16 GB (ou 8 GB + 8 GB de swap) | 32 GB | Pouca memória derruba o compilador no meio do build (erro `Killed`/`signal 9`) |
| Disco livre | 60 GB | 100 GB | Na partição onde fica o repositório (`work/`) **e** na do Docker (`/var/lib/docker`) |
| Rede | estável | cabo | O build baixa vários GB (Qt, sysroot, v8/chromium, boost, npm) de GitHub, Google e npm |

**Vai usar WSL2 no Windows?** Faça antes a [seção 1.1](#11-preparar-o-wsl2-windows). Sem ela, o WSL2 fica com metade
da RAM do Windows e o build tende a morrer por falta de memória.

Confira antes de começar:

```bash
nproc                       # núcleos
free -g                     # RAM (coluna "disponível")
df -h . /var/lib/docker     # disco livre
```

### 1.1 Preparar o WSL2 (Windows)

Só para quem vai compilar dentro do WSL2. Em Linux nativo, pule para a seção 2.

**a) Distribuição.** Use Ubuntu 24.04, no PowerShell:

```powershell
wsl --update
wsl --install -d Ubuntu-24.04
wsl -l -v            # a coluna VERSION precisa ser 2
```

**b) Memória, CPU e swap.** Por padrão o WSL2 usa só 50% da RAM do Windows. Crie ou edite
`%UserProfile%\.wslconfig` (por exemplo, `C:\Users\<você>\.wslconfig`):

```ini
[wsl2]
# deixe uns 4-6 GB para o Windows; o build quer 16 GB ou mais
memory=24GB
# todos os núcleos (ou quase) para o build
processors=12
swap=16GB
# não desligar a VM enquanto o build roda em segundo plano
vmIdleTimeout=-1
```

Ajuste `memory` e `processors` para a sua máquina e aplique no PowerShell com `wsl --shutdown`. Reabra o Ubuntu e
confira com `free -g` e `nproc`.

**c) systemd**, para o Docker subir sozinho. Dentro do Ubuntu:

```bash
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[boot]
systemd=true
EOF
```

Aplique com `wsl --shutdown` no PowerShell e reabra o Ubuntu. `systemctl is-system-running` deve responder `running`
ou `degraded`.

**d) Docker Engine dentro do Ubuntu, não o Docker Desktop.** Instale pela seção 2.2 normalmente. Se o Docker Desktop
estiver instalado no Windows, **desative a integração com essa distribuição** (Docker Desktop → Settings → Resources →
WSL integration). Senão o comando `docker` do Ubuntu passa a falar com o daemon do Desktop, e a geração da imagem
(`--network host` + `127.0.0.1`) pode não enxergar o `.deb`. Confira com `docker info | grep -i "operating system"`:
deve mostrar `Ubuntu`, não `Docker Desktop`.

**e) Clone no sistema de arquivos do Linux (`~/`), nunca em `/mnt/c/...`.** Em `/mnt/c` o build fica muito mais lento,
o Windows pode converter finais de linha para CRLF (o que quebra os scripts) e as permissões de arquivos de root não
funcionam.

```bash
cd ~ && git clone https://github.com/spirandev/unlimited-onlyoffice-package-builder.git onlyoffice-ems-builder
```

Não clone pelo Git do Windows.

**f) Disco.** O Ubuntu do WSL2 fica num disco virtual (`ext4.vhdx`), por padrão em `C:`. Ele **cresce e não encolhe
sozinho**, então o `C:` precisa ter 60 GB ou mais livres. Para colocar a distribuição em outro drive antes de começar
(PowerShell, versões recentes do WSL):

```powershell
wsl --shutdown
wsl --manage Ubuntu-24.04 --move D:\WSL\Ubuntu-24.04
```

Depois do build, para devolver o espaço ao Windows: `wsl --manage Ubuntu-24.04 --set-sparse true`.

**g) Não deixe o Windows dormir** durante o build (Configurações → Energia → Suspensão: Nunca), senão a VM do WSL
pausa. Deixe o terminal do Ubuntu aberto. O `tmux` protege contra fechar a aba, mas não contra suspensão ou
`wsl --shutdown`.

**h) DNS.** Se o `docker pull`/`docker build` falhar com `lookup ... server misbehaving` ou `connection refused` na
porta 53, fixe DNS no Docker:

```bash
echo '{ "dns": ["1.1.1.1", "8.8.8.8"] }' | sudo tee /etc/docker/daemon.json
sudo systemctl restart docker
```

Se já existir um `/etc/docker/daemon.json` (por exemplo, com `data-root`), acrescente a chave `dns` no mesmo JSON.

**i) Testar pelo Windows e pelo celular.** O smoke test roda inteiro dentro do WSL e não precisa disso. Para abrir
o Document Server no navegador do Windows, `http://localhost:<porta>` funciona direto. Para o **teste no celular**
([`tests/mobile.md`](tests/mobile.md)), o aparelho precisa alcançar o WSL pela rede local. O mais simples é o modo
de rede espelhado (Windows 11 22H2 ou mais novo), acrescentando ao `.wslconfig`:

```ini
[wsl2]
networkingMode=mirrored
```

Depois, `wsl --shutdown` e liberar a porta no firewall do Windows (PowerShell como administrador):

```powershell
New-NetFirewallRule -DisplayName "OnlyOffice teste" -Direction Inbound -Protocol TCP -LocalPort 8092 -Action Allow
```

O celular acessa então `http://<ip-do-windows-na-rede>:8092`. Remova a regra depois do teste.

## 2. Instalar as dependências

### 2.1 Pacotes do host

```bash
sudo apt-get update
sudo apt-get install -y git curl python3 tmux ca-certificates
```

### 2.2 Docker Engine

Se o Docker ainda não estiver instalado, use o script oficial (ou siga https://docs.docker.com/engine/install/):

```bash
curl -fsSL https://get.docker.com | sudo sh
```

Coloque o seu usuário no grupo `docker`, para que os scripts rodem **sem `sudo`**:

```bash
sudo usermod -aG docker "$USER"
newgrp docker            # ou saia e entre de novo na sessão
docker run --rm hello-world
```

O `hello-world` precisa funcionar sem `sudo`. Os scripts verificam o acesso e param com
`sem acesso ao Docker` se ele faltar.

### 2.3 (Opcional) Docker em outro disco

Se o disco do sistema for pequeno, mova o armazenamento do Docker antes de começar:

```bash
sudo systemctl stop docker
echo '{ "data-root": "/mnt/disco-grande/docker" }' | sudo tee /etc/docker/daemon.json
sudo systemctl start docker
docker info | grep "Docker Root Dir"
```

Clone o repositório também no disco grande (passo 3), porque o `work/` fica dentro dele. Outra opção é apontar a
variável `WORK_DIR` para outro caminho em todos os comandos: `WORK_DIR=/mnt/disco-grande/oo-work ./...`.

## 3. Clonar o repositório

O repositório é público, então o clone não precisa de autenticação:

```bash
git clone https://github.com/spirandev/unlimited-onlyoffice-package-builder.git onlyoffice-ems-builder
cd onlyoffice-ems-builder
```

Para fazer push dessa máquina também, use SSH com uma chave cadastrada na conta `spirandev`:
`git@github.com:spirandev/unlimited-onlyoffice-package-builder.git`.

Confira a versão que será compilada:

```bash
cat VERSION
```

```
PRODUCT_VERSION=9.4.0
BUILD_NUMBER=129
EMS_REVISION=2
```

Isso gera a tag oficial `v9.4.0.129`, o pacote `onlyoffice-documentserver_9.4.0-129-ems_amd64.deb` e a imagem
`ems-documentserver:9.4.0.129-ems.2`.

## 4. Rodar o build

O build leva **horas** (o btactic registra cerca de 2h30 num runner de 4 núcleos e 16 GB; menos com mais núcleos). Rode dentro do `tmux`
para que uma queda de SSH ou o fechamento do terminal não interrompa:

```bash
tmux new -s oo-build
```

Para sair do `tmux` sem parar o build: `Ctrl+b` e depois `d`. Para voltar: `tmux attach -t oo-build`.

Se quiser guardar o log completo, acrescente `2>&1 | tee build-$(date +%F-%H%M).log` aos comandos abaixo.

### 4.1 Etapa 1: binários e pacote `.deb`

```bash
./onlyoffice-package-builder.sh
```

O que acontece, em ordem (cada linha `==>` do log corresponde a uma etapa):

1. **Clone verificado:** `server`, `web-apps` e `build_tools` são clonados de `github.com/ONLYOFFICE` na tag
   `v9.4.0.129`, e o `HEAD` de cada um é comparado com o SHA da tag no upstream. Log esperado:
   `server: HEAD 13142e41dfc9 confere com v9.4.0.129 oficial`.
2. **Guarda de conexões:** confere que o `license.js` da versão não limita conexões
   (`server: license.js sem o limite de 20 conexões`).
3. **Patches:** aplica `patches/web-apps/0001-enable-mobile-edit.patch` e mostra o `diff --stat` (apresentação e
   planilha, 2 linhas). Em seguida, `apply_mobile_ui` confere o stub e copia `mobile-ui/documenteditor/patch.jsx`
   (`web-apps: mobile-ui/documenteditor/patch.jsx aplicado sobre o stub 20e4c14274d8`).
4. **Imagem do build_tools** (`ems-oo-build-tools:v9.4.0.129`): rápida.
5. **Compilação** (`compilando (módulo server). Isso leva horas.`): o `automate.py` do `build_tools` baixa Python,
   Qt, sysroot e CMake e instala os pacotes de sistema no container. Depois clona os demais repositórios oficiais
   (`core`, `sdkjs`, `dictionaries`, `core-fonts`, ...) em `work/` e compila tudo. **É a parte demorada.**
6. **Empacotamento** (`ems-oo-deb-builder`): clona o `document-server-package` oficial (também verificado) e gera o
   `.deb`.

Ao final:

```
==> [..] pacote gerado: .../work/document-server-package/deb/onlyoffice-documentserver_9.4.0-129-ems_amd64.deb
```

Opções úteis:

| Opção | Uso |
|---|---|
| `--binaries-only` | Só compila (etapas 1 a 5) |
| `--deb-only` | Só empacota (etapa 6), reaproveitando os binários de `work/build_tools/out` |
| `--clean` | Apaga o `work/` e recomeça do zero |
| `--product-version=X.Y.Z --build-number=N` | Compila outra versão sem editar o `VERSION` |

### 4.2 Etapa 2: imagem Docker

```bash
./docker/build-image.sh
```

Clona o `Docker-DocumentServer` oficial na mesma tag e roda o `Dockerfile` dele, sem alterações, instalando o nosso
`.deb`, que é servido por um HTTP temporário em `127.0.0.1`. Ao final:

```
==> [..] imagem pronta: ems-documentserver:9.4.0.129-ems.2
```

Para usar outro nome de imagem (por exemplo, já com o registry): `./docker/build-image.sh --image=registry.exemplo/ems-documentserver`.

### 4.3 Etapa 3: smoke test

```bash
./tests/smoke.sh
```

Sobe a imagem em `127.0.0.1:8099`, espera o healthcheck e confere o bundle dos editores mobile. Resultado esperado:

```
Resultados (ems-documentserver:9.4.0.129-ems.2):
  OK    healthcheck responde true
  OK    api.js disponível
        documenteditor: isSupportEditFeature=()=>!0
  OK    edição mobile liberada (documento)
        presentationeditor: isSupportEditFeature=()=>!0
  OK    edição mobile liberada (apresentação)
        spreadsheeteditor: isSupportEditFeature=()=>!0
  OK    edição mobile liberada (planilha)
        documenteditor: interface de edição presente
  OK    interface de edição mobile (documento)
        presentationeditor: falta:getToolbarOptions= falta:getUndoRedo= falta:\.intf= falta:getEditCommentControllers=
  AVISO interface de edição mobile (apresentação) (editor ainda sem mobile-ui/presentationeditor/patch.jsx)
        spreadsheeteditor: falta:toolbarOptions= falta:\.intf=
  AVISO interface de edição mobile (planilha) (editor ainda sem mobile-ui/spreadsheeteditor/patch.jsx)
```

`!0` é o `true` minificado. A imagem oficial mostra `()=>!1` e é reprovada, e isso já foi conferido. A checagem da
interface procura, no bundle, as atribuições que o `mobile-ui/<editor>/patch.jsx` faz. Na imagem oficial e na
`-ems.1`, o documento mostra `stub:getToolbarOptions=\(\)=>null` e é reprovado. Apresentação e planilha só avisam
enquanto não tiverem `mobile-ui/`. Se a porta 8099
estiver ocupada: `./tests/smoke.sh ems-documentserver:9.4.0.129-ems.2 8199`.

## 5. Se o build falhar

**Rodar o mesmo comando de novo é seguro e retoma de onde parou.** O `work/` guarda o que já foi baixado e compilado,
e patches já aplicados são detectados e pulados. O btactic precisou de 8 tentativas na 9.3.1, quase todas por rede ou
disco.

| Sintoma no log | Causa provável | O que fazer |
|---|---|---|
| `Could not resolve host`, `timed out`, `gclient ... failed`, `Subprocess failed` durante o download do v8/chromium | Rede instável | Rodar de novo |
| `No space left on device` | Disco cheio (`work/` ou `/var/lib/docker`) | Liberar espaço (`docker system df`, `docker builder prune`) e rodar de novo |
| `Killed`, `signal 9`, `c++: fatal error: Killed` | Falta de RAM | Fechar programas, criar swap (`sudo fallocate -l 8G /swapfile && sudo chmod 600 /swapfile && sudo mkswap /swapfile && sudo swapon /swapfile`) e rodar de novo |
| `HEAD ... difere da tag oficial` | O `work/<repo>` foi alterado à mão ou está corrompido | `--clean` e rodar de novo |
| `0001-enable-mobile-edit.patch não aplica` | Versão nova mudou o arquivo | Refazer o patch na nova tag (seção 8) |
| `o stub apps/<editor>/mobile/src/lib/patch.jsx mudou` | Versão nova mudou o stub que `mobile-ui/` substitui | Revisar o `mobile-ui/<editor>/patch.jsx` (seção 8) |
| `license.js voltou a limitar conexões` | A versão escolhida é anterior à 9.4.0, ou o upstream voltou a limitar | Usar 9.4.0 ou mais nova, ou criar um patch em `patches/server/` |
| `sem acesso ao Docker` | Usuário fora do grupo `docker` | Passo 2.2 |
| Erro no `apt-get install /tmp/onlyoffice-documentserver_...deb` durante a etapa 2 | Dependência do `.deb` (gerado em Debian 13) ausente no Ubuntu 24.04 da imagem | Anotar o pacote que falta e reportar; a correção é trocar a base de `deb_build/Dockerfile-manual-debian-13` para `ubuntu:24.04` |

Os arquivos em `work/` são criados pelos containers como **root**. Para apagar à mão, use `--clean` ou
`docker run --rm -v "$PWD/work:/w" ubuntu:24.04 find /w -mindepth 1 -delete`. Um `rm -rf work` sem `sudo` falha.

## 6. Levar a imagem para outra máquina

**Por arquivo** (sem registry):

```bash
docker save ems-documentserver:9.4.0.129-ems.2 | gzip > ems-documentserver_9.4.0.129-ems.2.tar.gz
scp ems-documentserver_9.4.0.129-ems.2.tar.gz usuario@destino:
# no destino:
gunzip -c ems-documentserver_9.4.0.129-ems.2.tar.gz | docker load
```

No WSL2, o arquivo gerado em `~/` aparece no Explorer do Windows em `\\wsl$\Ubuntu-24.04\home\<usuário>\`. Outra opção
é salvar direto no Windows com `docker save ... | gzip > /mnt/c/Users/<você>/Downloads/ems-documentserver_....tar.gz`
(gravar em `/mnt/c` é lento, mas só acontece uma vez).

**Por registry:**

```bash
docker tag ems-documentserver:9.4.0.129-ems.2 <registry>/ems-documentserver:9.4.0.129-ems.2
docker push <registry>/ems-documentserver:9.4.0.129-ems.2
```

Guarde também o `.deb` (`work/document-server-package/deb/*.deb`), porque ele permite gerar a imagem de novo sem
recompilar.

## 7. Validação antes de usar no EMS

O smoke test não substitui os roteiros manuais:

- [`tests/mobile.md`](tests/mobile.md): celular real, `.docx`/`.xlsx`/`.pptx`, callback `status 2` no EMS;
- [`tests/connections.md`](tests/connections.md): 25 ou mais editores simultâneos.

Lembrete: a 9.4 não usa mais RabbitMQ nem banco de dados. Revise as variáveis do Document Server no
`docker-compose` do EMS e teste a migração em homologação antes de produção.

## 8. Compilar uma versão mais nova

1. Descobrir o build number da versão oficial:
   ```bash
   curl -s https://download.onlyoffice.com/repo/debian/dists/squeeze/main/binary-amd64/Packages.gz \
     | gunzip | awk '/^Package: onlyoffice-documentserver$/{p=1} p&&/^Version:/{print; p=0}' | sort -V | tail -3
   ```
   `Version: 9.4.0-129` → `PRODUCT_VERSION=9.4.0`, `BUILD_NUMBER=129`.
2. Atualizar `VERSION` (e voltar `EMS_REVISION=1`). Fazer commit.
3. Rodar o build normalmente. O `work/` da versão anterior é limpo automaticamente.
4. Se o patch mobile não aplicar, refazê-lo na nova tag:
   ```bash
   cd work/web-apps
   git checkout .                # descarta tentativas anteriores
   # editar apps/{presentation,spreadsheet}editor/mobile/src/lib/patch.jsx:
   #   isSupportEditFeature deve retornar true
   git diff > /tmp/novo.diff
   ```
   Substituir o bloco `diff` de `patches/web-apps/0001-enable-mobile-edit.patch` pelo novo (mantendo o cabeçalho de
   texto), commitar e rodar de novo. O editor de documentos não entra no `0001`: o arquivo dele vem de `mobile-ui/`.
5. Se o build parar em `apply_mobile_ui` (o stub mudou), revisar o `mobile-ui/<editor>/patch.jsx`:
   ```bash
   cd work/web-apps
   git show HEAD:apps/documenteditor/mobile/src/lib/patch.jsx   # stub novo
   grep -rn "EditorUIController\.\|\.intf\b" apps/documenteditor/mobile/src   # ganchos que o código público consome
   ```
   Conferir se algum gancho mudou de nome ou de assinatura, ajustar o `.jsx`, atualizar o blob em
   `mobile-ui/upstream-stubs` (`git rev-parse HEAD:apps/documenteditor/mobile/src/lib/patch.jsx`) e rodar de novo.
   Depois do build, `./tests/smoke.sh` e o roteiro `tests/mobile.md` no celular.

## 9. Limpeza depois do build

Para apagar o `work/` e as imagens intermediárias (o `--clean` do builder também apaga, mas depois recompila):

```bash
docker run --rm -v "$PWD/work:/w" ubuntu:24.04 find /w -mindepth 1 -delete
docker rmi ems-oo-build-tools:v9.4.0.129 ems-oo-deb-builder
docker builder prune -f
```

Guarde antes o `.deb` e a imagem final, se ainda precisar deles.
