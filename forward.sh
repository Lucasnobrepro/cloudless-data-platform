minikube dashboard --profile cloudless-data-platform --url

ase 1 instalada. Acesse os servicos usando port-forward:
  kubectl -n airflow port-forward svc/airflow-api-server 8080:8080
  kubectl -n argocd port-forward svc/argocd-server 8443:443
  kubectl -n monitoring port-forward svc/monitoring-grafana 3000:80
  kubectl -n monitoring port-forward svc/monitoring-kube-prometheus-prometheus 9090:9090