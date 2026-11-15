# Regras Gerais para Agentes

Estas regras se aplicam a todo o repositório e complementam as instrucoes dos agentes especializados.

## Contexto do projeto

- Este e um ambiente local de estudo baseado em Minikube, Kubernetes, Argo CD, Airflow e kube-prometheus-stack.
- Trate a Fase 1 como a infraestrutura existente. A coleta de dados financeiros e a aplicacao da Fase 2 sao planos ate que estejam implementadas no repositorio.
- Antes de propor versoes, recursos ou caminhos, confira os arquivos atuais. Nao presuma que configuracoes sugeridas no README ja estejam implantadas.

## Mudancas e validacao

- Leia as instrucoes e os arquivos proximos da area afetada antes de editar.
- Prefira mudancas pequenas, declarativas e consistentes com os padroes existentes. Nao altere arquivos fora do escopo.
- Preserve mudancas preexistentes do usuario; nunca reverta trabalho alheio.
- Valide a alteracao com o teste, lint, parser ou verificacao mais especifica disponivel. Informe verificacoes que nao puder executar.
- Nao faca commit, push, merge ou crie branches sem solicitacao explicita.

## Branches

- O identificador de trabalho adotado e `K8s-01`.
- Nomes de branch nao podem conter espacos no Git. Use o formato `K8s-01-<descricao-em-kebab-case>`, por exemplo `K8s-01-adicionar-monitoramento`.
- Use nomes curtos e descritivos, em minusculas apos o identificador, separando palavras com hifens.

## GitHub e GitHub MCP

- Antes de operar no GitHub, confira o estado da branch, do worktree, do remoto e as diferencas em relacao a branch base.
- Quando a tarefa envolver GitHub, verifique quais ferramentas estao disponiveis na sessao e prefira as ferramentas oficiais do GitHub MCP para consultar repositorios, issues e pull requests ou para criar/atualizar pull requests.
- Use somente ferramentas GitHub MCP realmente disponibilizadas pela sessao; nao presuma nomes, capacidades ou autenticacao. Para enviar commits, use uma operacao do MCP se ela estiver disponivel; caso contrario, use `git push` para o remoto configurado.
- Antes de criar um pull request, confira a branch base padrao do remoto, as diferencas que serao propostas e se ja existe um pull request para a branch. Nao crie pull requests vazios ou duplicados.
- Crie ou altere recursos remotos somente quando solicitado. Ao criar um pull request, use um titulo e uma descricao baseados nas mudancas reais e retorne o link.
- Nunca obtenha, leia, imprima ou transmita tokens e credenciais manualmente. A autenticacao deve ser tratada pela integracao GitHub MCP ou pelo mecanismo local configurado.
- Se as ferramentas GitHub MCP ou a autenticacao necessaria nao estiverem disponiveis, informe o bloqueio; nao afirme que uma operacao remota foi concluida.

## Seguranca e operacao

- Nunca inclua senhas, tokens, chaves ou outros segredos no codigo, manifests, documentacao de exemplo ou logs. Use `.env` local e Secrets conforme o projeto.
- Diferencie comandos somente de leitura de comandos que alteram o cluster. Nao execute operacoes destrutivas ou mutacoes de cluster sem autorizacao explicita.
- Mantenha servicos locais expostos apenas conforme a configuracao documentada; nao sugira publicar portas ou credenciais.