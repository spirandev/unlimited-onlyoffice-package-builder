# Roteiro manual: edição mobile

Objetivo: confirmar no celular real que os três editores abrem em modo de edição, com a interface de edição, e que o
salvamento chega ao EMS.

## Preparação
1. Subir a imagem do fork numa porta separada, com o mesmo `JWT_SECRET` do `.env` de desenvolvimento do EMS:
   ```
   docker run -d --name ems-ds-test -p 8092:80 \
     -e JWT_ENABLED=true -e JWT_SECRET=<segredo do .env> \
     ems-documentserver:<versão>-ems.<n>
   ```
2. Apontar o EMS de desenvolvimento para `http://<ip-da-máquina>:8092`.
3. Confirmar que o EMS envia `type: "mobile"` no celular (`internal/onlyoffice/onlyoffice.go:84`). Se o front
   forçar `desktop`, liberar `mobile` antes do teste.
4. A página do EMS precisa mostrar o iframe inteiro. O `api.js` põe o iframe `type: mobile` em `position: fixed`, e o
   botão de lápis (entrar em edição) fica no canto inferior direito: se a base do iframe sair da tela, não há como
   editar.

## Execução (celular real, tela de 360 a 767 px)
No iPhone (Safari) e no Android (Chrome). O documento abre em leitura (`customization.mobile.forceView`).

### Documento (`.docx`): interface completa (`mobile-ui/documenteditor/patch.jsx`)

| # | Passo | Esperado |
|---|---|---|
| 1 | Abrir o documento pelo EMS e tocar no lápis (canto inferior direito) | Cabeçalho com "OK" (iOS) ou ✓ (Android), botões Editar e Inserir, desfazer e refazer |
| 2 | Tocar no texto e digitar | Teclado abre e o texto aparece. Desfazer e refazer funcionam |
| 3 | Com o cursor num parágrafo, abrir Editar | Abas Texto e Parágrafo. Negrito em Texto é aplicado. Fonte e tamanho aparecem preenchidos |
| 4 | Com o cursor numa tabela, abrir Editar | Aba Tabela, com estilos de tabela |
| 5 | Selecionar uma imagem e abrir Editar | Aba Imagem |
| 6 | Inserir → tabela | Tabela inserida |
| 7 | Toque longo no texto | Menu com cortar/copiar/colar (ícones visíveis), Editar e Adicionar comentário. Colar funciona |
| 8 | Menu de toque → Adicionar comentário | Comentário criado |
| 9 | Fechar o editor | EMS recebe o callback com `status 2` e grava uma nova versão |
| 10 | Reabrir o documento | As alterações estão lá |

### Apresentação (`.pptx`) e planilha (`.xlsx`): só a permissão (`0001`)
Ainda sem `mobile-ui/`. Registrar o que acontece, para planejar as próximas fatias:

| # | Passo | Registrar |
|---|---|---|
| 1 | Abrir pelo EMS e tocar no lápis | Aparece "OK"/✓? Aparecem Editar/Inserir e desfazer/refazer? (esperado: não) |
| 2 | Tocar no texto do slide ou numa célula e digitar | O teclado abre? A alteração aparece? |
| 3 | Toque longo | Qual menu aparece (esperado: o de leitura) |
| 4 | Se algo foi alterado, fechar o editor | Callback com `status 2`? |

## Regressão rápida
- Desktop: abrir e salvar `.docx`, `.xlsx` e `.pptx`.
- Documento no celular aberto só para leitura (`mode: "view"` ou sem permissão de edição): sem lápis e sem Editar/Inserir.
  Toque longo mostra o menu de leitura.
- PDF continua em `view` (`TestBuildEditorConfigReadOnlyForNonEditable`).
- Token JWT inválido é recusado.
