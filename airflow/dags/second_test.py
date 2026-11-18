from datetime import datetime, timezone

from airflow.sdk import dag, task


@dag(
    dag_id="second_test",
    description="Segunda DAG de teste da plataforma local.",
    schedule=None,
    start_date=datetime(2025, 1, 1, tzinfo=timezone.utc),
    catchup=False,
    tags=["fase-1", "exemplo"],
)
def second_test():
    @task
    def print_message():
        print("A segunda DAG de teste esta funcionando.")

    print_message()


second_test()
