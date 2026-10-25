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
- Argo CD instalado inicialmente por Helm e depois gerenciado por ele próprio
  usando o chart oficial e valores versionados neste repositório.
- Airflow e kube-prometheus-stack gerenciados pelo Argo CD usando charts
  oficiais e valores versionados neste repositório.
- Scripts para iniciar e excluir o cluster.

O `platform-root` acompanha `argocd/apps` e cria as aplicações `argocd`,
`airflow` e `monitoring`. Elas sincronizam automaticamente mudanças publicadas
no branch `main`, fazem autocorreção de alterações manuais no cluster e não
removem recursos automaticamente. As versões dos charts estão fixadas nas
declarações das aplicações; editar um `values.yaml` muda configurações, mas não
atualiza sozinho a versão do chart.

Não é necessário fazer forks do Argo CD, Airflow ou Prometheus. O projeto usa
os charts oficiais e mantém apenas seus valores e declarações de implantação
neste repositório. As senhas ficam no `.env` local e o script as grava em
Secrets do Kubernetes; não as coloque nos `values.yaml` nem no Git.

### Fase 2 — dados financeiros e aplicação

Sugestão de fluxo:

1. Uma DAG busca cotações de uma API e grava a resposta original (camada *raw*).
2. Uma etapa valida e normaliza os registros (camada *curated*).
3. Um PostgreSQL separado da base de metadados do Airflow armazena os dados
   processados para consultas.
4. Streamlit apresenta preços, variações e gráficos.
5. FastAPI é opcional: vale adicioná-lo se outros clientes precisarem de uma API
   estável; para um dashboard único, Streamlit pode consultar o banco diretamente.
6. Argo CD instala e mantém os componentes do cluster conforme as definições no
   Git.
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

Versões consultadas em **25/10/2026**. Os charts são fixados nas declarações das
aplicações em `argocd/apps/` para que a instalação seja reproduzível; o pin do
chart do Argo CD também aparece em `scripts/start.sh` para o bootstrap. Atualize
esses pins deliberadamente após validar a compatibilidade.

| Componente | Versão usada |
|---|---:|
| Minikube | 1.39.0 |
| Kubernetes local | 1.37.1 |
| `kubectl` | 1.37.1 recomendado; 1.36 ou mais novo para compatibilidade |
| Helm | 4.3.1 mais recente; charts exigem pelo menos 3.19.0 |
| Airflow Helm chart | 1.22.0 (Airflow 3.2.2) |
| Argo CD Helm chart | 10.11.1 (Argo CD 3.5.6) |
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

2. Edite `.env` e defina as três senhas locais. O arquivo é ignorado pelo Git.

3. Publique e integre as alterações no branch `main` antes de iniciar. O Argo CD
   lê as aplicações e os valores desse branch. O script verifica que ele está
   acessível. O Airflow também usa Git Sync para ler `airflow/dags` do mesmo
   branch.

4. Inicie o cluster e os componentes:

   ```bash
   ./scripts/start.sh
   ```

   Em um cluster novo, o script instala o Argo CD por Helm apenas para
   inicializar o controlador e então aplica `platform-root`. Essa aplicação
   passa a gerenciar o próprio Argo CD, Airflow e monitoramento. Se o Argo CD já
   estiver instalado, o bootstrap preserva a instalação para o Argo CD adotar
   os recursos declarados.

5. Para mudar configurações, edite `argocd/values.yaml`, `airflow/values.yaml`
   ou `monitoring/values.yaml`, faça commit e publique no `main`. Para atualizar
   um chart, altere `targetRevision` no respectivo arquivo em `argocd/apps/`.
   Ao atualizar o chart do Argo CD, mantenha também `ARGOCD_CHART_VERSION` em
   `scripts/start.sh` alinhado. As versões não acompanham automaticamente novos
   releases upstream.

6. Abra os serviços em terminais separados:

   ```bash
   kubectl -n airflow port-forward svc/airflow-api-server 8080:8080
   kubectl -n argocd port-forward svc/argocd-server 8443:443
   kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
   kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090
   ```

   Acesse Airflow em <http://localhost:8080>, Argo CD em
   <https://localhost:8443>, Grafana em <http://localhost:3000> e Prometheus em
   <http://localhost:9090>. O certificado local do Argo CD é autoassinado.

7. Entre no Airflow e no Grafana com `admin` e a senha local configurada no
   `.env`. Essa senha também é configurada para o administrador do Argo CD. A
   interface do Prometheus não tem autenticação própria nesta configuração;
   acesse-a somente pelo `port-forward` local.

8. No Airflow, habilite e execute o DAG `hello_world`. Confira o log da tarefa
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
argocd/
  apps/
    airflow.yaml
    argocd.yaml
    monitoring.yaml
  root-app.yaml
  values.yaml
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
fora da máquina local. O script cria Secrets do Kubernetes com os valores de
`.env`; eles permanecem no cluster local e não são escritos nos arquivos Git.
Proteja também o acesso ao cluster e à interface do Argo CD.
