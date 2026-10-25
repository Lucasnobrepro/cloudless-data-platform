# Plataforma local de dados financeiros

Projeto de estudo em duas fases para aprender Kubernetes local, orquestração de
pipelines, GitOps, monitoramento e visualização de dados financeiros.

## Sugestões de nome para o repositório

O nome atual, `cloudless-data-platform`, funciona bem e já está configurado como
repositório Git. Outras opções, se quiser renomeá-lo antes de compartilhar, são:

- `local-finance-data-platform`
- `finance-data-pipeline-lab`
- `market-data-observatory`
- `k8s-finance-lab`

## Arquitetura e fases

### Fase 1 — infraestrutura local

- Minikube com o driver Docker.
- Airflow instalado por Helm e um DAG manual que imprime uma mensagem.
- Argo CD instalado no namespace `argocd`.
- Prometheus e Grafana instalados pelo chart `kube-prometheus-stack`.
- Scripts para iniciar e excluir o cluster.

O Airflow e o stack de monitoramento são instalados diretamente por Helm nesta
primeira etapa. O Argo CD fica disponível para validar a instalação e servir de
base para mover a gestão dos aplicativos para GitOps.

### Fase 2 — dados financeiros e aplicação

Sugestão de fluxo:

1. Uma DAG busca cotações de uma API e grava a resposta original (camada *raw*).
2. Uma etapa valida e normaliza os registros (camada *curated*).
3. Um PostgreSQL separado da base de metadados do Airflow armazena os dados
   processados para consultas.
4. Streamlit apresenta preços, variações e gráficos.
5. FastAPI é opcional: vale adicioná-lo se outros clientes precisarem de uma API
   estável; para um dashboard único, Streamlit pode consultar o banco diretamente.
6. Argo CD passa a sincronizar os manifests do projeto a partir do Git.
7. Prometheus coleta métricas do cluster e, posteriormente, da aplicação.

Opções de fonte para a fase financeira:

- **B3 brasileira:** avalie a [brapi](https://brapi.dev/) e confirme limites,
  cobertura e condições do plano antes de automatizar consultas.
- **Mercado internacional:** [Alpha Vantage](https://www.alphavantage.co/) oferece
  API com chave; observe os limites do plano gratuito.
- **Protótipo rápido:** `yfinance` é conveniente, mas depende de uma interface
  não oficial e não deve ser tratado como fonte contratual ou garantida.

Comece com um conjunto pequeno de ativos, grave a resposta bruta e respeite os
limites e termos do provedor escolhido. Não coloque chaves de API no DAG ou no
Git; use Secrets do Kubernetes ou conexões/variáveis do Airflow.

## Versões de referência

Versões consultadas em **25/10/2026**. Os charts são fixados nos scripts para
que a instalação seja reproduzível; atualize esses pins deliberadamente após
validar a compatibilidade.

| Componente | Versão usada |
|---|---:|
| Minikube | 1.39.0 |
| Kubernetes local | 1.37.1 |
| `kubectl` | 1.37.1 recomendado; 1.36 ou mais novo para compatibilidade |
| Helm | 4.3.1 mais recente; charts exigem pelo menos 3.19.0 |
| Airflow Helm chart | 1.22.0 (Airflow 3.2.2) |
| Argo CD | 3.5.6 |
| `kube-prometheus-stack` | 92.13.1 |

O chart mais recente do Airflow fixa a imagem padrão em Airflow 3.2.2; a versão
do chart é preferida aqui à versão mais nova do aplicativo para manter a
instalação alinhada com o chart publicado.

Referências oficiais:

- [Releases do Minikube](https://github.com/kubernetes/minikube/releases)
- [Releases do Kubernetes](https://kubernetes.io/releases/)
- [Releases do Helm](https://github.com/helm/helm/releases)
- [Chart oficial do Airflow](https://airflow.apache.org/docs/helm-chart/stable/)
- [Releases do Argo CD](https://github.com/argoproj/argo-cd/releases)
- [Chart kube-prometheus-stack](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack)

## Pré-requisitos

- Linux, Docker Engine em execução, Minikube, `kubectl`, Helm, Git e `curl`.
- Para esta configuração: aproximadamente 6 CPUs e 12 GiB de RAM livres para o
  Minikube. Ajuste `MINIKUBE_CPUS` e `MINIKUBE_MEMORY` no `.env` se necessário.
- `kubectl` dentro de uma versão de diferença menor do Kubernetes do cluster.

Confira as ferramentas instaladas:

```bash
docker version
minikube version
kubectl version --client
helm version
```

As versões encontradas durante a preparação deste projeto foram Docker 29.1.3,
Minikube 1.36.0, `kubectl` 1.33.3 e Helm 3.18.4. Minikube, `kubectl` e Helm
precisam ser atualizados para os requisitos acima antes de executar
`scripts/start.sh`. Os scripts não atualizam ferramentas do sistema
automaticamente.

Use os guias oficiais para atualizar as ferramentas:

- [Instalar Minikube](https://minikube.sigs.k8s.io/docs/start/)
- [Instalar `kubectl`](https://kubernetes.io/docs/tasks/tools/)
- [Instalar Helm](https://helm.sh/docs/intro/install/)

## Configuração e execução da Fase 1

1. Crie sua configuração local:

   ```bash
   cp .env.example .env
   chmod 600 .env
   ```

2. Edite `.env`. Defina senhas locais e o branch remoto que contém
   `airflow/dags/hello_world.py`. O arquivo `.env` é ignorado pelo Git.

3. O Airflow usa Git Sync para obter os DAGs. Publique o branch configurado antes
   de iniciar. Para esta cópia, o branch configurado é `K8s-00`:

   ```bash
   git add README.md .gitignore .env.example airflow monitoring scripts
   git commit -m "Add phase-one Airflow DAG"
   git push -u origin K8s-00
   ```

   Se estiver usando outro branch, ajuste `AIRFLOW_GIT_BRANCH` no `.env`. O
   repositório precisa estar acessível ao cluster por HTTPS. Nesta primeira
   versão, o script configura Git Sync sem credenciais; use um branch público.
   O suporte a Secrets de leitura para repositórios privados fica para uma
   melhoria posterior.

4. Inicie o cluster e os componentes:

   ```bash
   ./scripts/start.sh
   ```

5. Abra os serviços em terminais separados:

   ```bash
   kubectl -n airflow port-forward svc/airflow-api-server 8080:8080
   kubectl -n argocd port-forward svc/argocd-server 8443:443
   kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
   kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
   ```

   Acesse Airflow em <http://localhost:8080>, Argo CD em
   <https://localhost:8443>, Grafana em <http://localhost:3000> e Prometheus em
   <http://localhost:9090>. O certificado local do Argo CD é autoassinado.

6. Entre no Airflow e no Grafana com `admin` e a senha local configurada no
   `.env`. O script configura a mesma senha para o administrador do Argo CD. A
   interface do Prometheus não tem autenticação própria nesta configuração;
   acesse-a somente pelo `port-forward` local.

7. No Airflow, habilite e execute o DAG `hello_world`. Confira o log da tarefa
   para ver a mensagem impressa.

## Desligar

O script de parada **exclui o perfil Minikube e os dados que estão dentro dele**,
conforme escolhido para este projeto. A configuração `.env` e os arquivos do
repositório permanecem.

```bash
./scripts/stop.sh
```

O script pede confirmação digitando `DELETE cloudless-data-platform`. Para
automação ou confirmação explícita:

```bash
./scripts/stop.sh --yes
```

## Estrutura

```text
airflow/
  dags/hello_world.py
  values.yaml
monitoring/
  values.yaml
scripts/
  start.sh
  stop.sh
```

## Segurança

As credenciais solicitadas são convenientes para estudo local, mas são
compartilhadas e fracas para qualquer ambiente exposto. Não publique o cluster,
não encaminhe essas portas para interfaces públicas, não reutilize a senha em
outros serviços e não versione `.env`. Troque as senhas antes de qualquer uso
fora da máquina local. O Helm também mantém os valores de instalação em Secrets
do próprio cluster.
