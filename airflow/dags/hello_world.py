from datetime import datetime, timezone

from airflow.sdk import dag, task


@dag(
    dag_id="hello_world",
    description="DAG inicial da plataforma local.",
    schedule=None,
    start_date=datetime(2025, 1, 1, tzinfo=timezone.utc),
    catchup=False,
    tags=["fase-1", "exemplo"],
)
def hello_world():
    @task
    def print_message():
        print("Ola! O Airflow esta executando localmente no Minikube.")

    print_message()


hello_world()
