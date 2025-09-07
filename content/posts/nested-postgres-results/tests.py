from pathlib import Path
from typing import Generator
import psycopg
from pytest_benchmark.fixture import BenchmarkFixture
import pytest


@pytest.fixture(scope="module")
def connection() -> Generator[psycopg.Connection]:
    with psycopg.connect(
        dbname="postgres", user="postgres", password="", host="127.0.0.1", port="5432"
    ) as connection:
        yield connection


def load(connection: psycopg.Connection, query: bytes, *, binary: bool) -> None:
    with connection.cursor() as cursor:
        cursor.execute(query, binary=binary)
        cursor.fetchall()


@pytest.mark.parametrize("binary", [False, True])
@pytest.mark.parametrize(
    "query", ["json-array-agg.sql", "jsonb-array-agg.sql", "composite-array-agg.sql"]
)
def test_benchmark_load(
    connection: psycopg.Connection,
    benchmark: BenchmarkFixture,
    binary: bool,
    query: str,
):
    benchmark(
        load,
        connection,
        (Path("content/posts/nested-postgres-results") / query).read_bytes(),
        binary=binary,
    )
