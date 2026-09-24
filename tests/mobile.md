# Roteiro manual: edição mobile

Objetivo: confirmar no celular real que os três editores abrem em modo de edição e que o salvamento chega ao EMS.

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

## Execução (celular real, tela de 360 a 767 px)
Repetir para `.docx`, `.xlsx` e `.pptx`:

| # | Passo | Esperado |
|---|---|---|
| 1 | Abrir o documento pelo EMS | Editor abre com a barra de edição (não só visualização) e sem aviso de "edição indisponível" |
| 2 | Alterar o conteúdo (digitar texto / mudar uma célula / editar um slide) | Alteração aparece |
| 3 | Fechar o editor | EMS recebe o callback com `status 2` e grava uma nova versão |
| 4 | Reabrir o documento | A alteração está lá |

## Regressão rápida
- Desktop: abrir e salvar `.docx`, `.xlsx` e `.pptx`.
- PDF continua em `view` (`TestBuildEditorConfigReadOnlyForNonEditable`).
- Token JWT inválido é recusado.
