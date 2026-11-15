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

## Seguranca e operacao

- Nunca inclua senhas, tokens, chaves ou outros segredos no codigo, manifests, documentacao de exemplo ou logs. Use `.env` local e Secrets conforme o projeto.
- Diferencie comandos somente de leitura de comandos que alteram o cluster. Nao execute operacoes destrutivas ou mutacoes de cluster sem autorizacao explicita.
- Mantenha servicos locais expostos apenas conforme a configuracao documentada; nao sugira publicar portas ou credenciais.