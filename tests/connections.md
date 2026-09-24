# Roteiro manual: mais de 20 editores simultâneos

A partir da 9.4.0 o próprio upstream removeu o limite de 20 conexões do Community (o `onlyoffice-package-builder.sh`
barra o build se ele voltar, em `check_no_connection_limit`). Este roteiro confirma o comportamento na imagem gerada.

## Execução
1. Subir a imagem e apontar o EMS para ela (igual ao `mobile.md`).
2. Abrir **25 ou mais** sessões de edição ao mesmo tempo, em documentos diferentes ou no mesmo documento. Para
   isso, usar abas de navegadores/perfis distintos ou uma janela anônima por sessão.
3. Esperado:
   - nenhuma sessão abre em modo de visualização;
   - não aparece o aviso de limite de conexões ("the number of connections exceeds the limit…");
   - no log (`docker logs <container>`) não há mensagens de licença com limite atingido.
4. Fechar as sessões e confirmar que os salvamentos chegaram ao EMS.
