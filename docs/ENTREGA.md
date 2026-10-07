# Entrega do incremento — 06/10/2026

O pacote inclui o código-fonte, uma cópia portátil do commit (`leviticus.bundle`) e a demonstração Web compilada (`demo-web`).

A demonstração permite cadastrar/editar pessoas, organizar ministérios e enviar/acompanhar pedidos fictícios de oração. Os dados ficam em memória e desaparecem ao atualizar a página. Não há conexão com o Firebase real neste modo.

Para experimentar sem instalar Flutter, extraia o ZIP e, na pasta extraída, execute com Python 3 instalado:

```sh
python -m http.server 8085 --bind 127.0.0.1 --directory demo-web
```

No Windows, pode ser necessário usar `py` no lugar de `python`. Abra `http://127.0.0.1:8085` no navegador. Não abra o index.html diretamente pelo explorador de arquivos.

Para continuar o desenvolvimento, use a pasta `codigo` e consulte `docs/EXECUTAR.md`. Alternativamente, restaure o histórico com `git clone leviticus.bundle Leviticus`, ajuste o remoto para o repositório informado e faça o envio somente após liberar o acesso da integração.

A tentativa inicial de envio ao GitHub foi recusada com 403. A escrita foi liberada e confirmada em 07/10/2026 pelo commit inicial `cae26c97989342b5340ea45f597bc310e2dbf742`. Nenhum deploy foi realizado no projeto `leviticus-app-c5110`. Não há alteração de dados reais.
