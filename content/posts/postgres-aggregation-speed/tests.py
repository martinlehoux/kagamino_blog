"""
uv run pytest --benchmark-columns=mean,stddev,iqr
"""

from decimal import Decimal
from datetime import date
from typing import Generator
import psycopg
from psycopg import Connection
from psycopg.abc import ConnectionType
from pytest_benchmark.fixture import BenchmarkFixture
import pytest


@pytest.fixture(scope="module")
def conn() -> Generator[Connection]:
    with psycopg.connect(
        dbname="postgres", user="postgres", password="", host="127.0.0.1", port="5432"
    ) as connection:
        yield connection


BASE_QUERY = """SELECT accommodation_id, {} AS daily_configs
    FROM overrides
    WHERE '[2025-07-01,2025-08-01)'::daterange @> date
    GROUP BY overrides.accommodation_id"""
COMPOSITE_QUERY = BASE_QUERY.format("array_agg((date, price))")
JSON_OBJECT_EXPR = "json_agg(json_build_object('date', date, 'price', price::text))"
JSONB_OBJECT_EXPR = "jsonb_agg(jsonb_build_object('date', date, 'price', price::text))"
JSONB_ARRAY_EXPR = "jsonb_agg(jsonb_build_array(date, price::text))"
JSON_ARRAY_EXPR = "json_agg(json_build_array(date, price::text))"

type PythonOut = list[tuple[str, list[tuple[date, Decimal]]]]
type JSONOut = list[tuple[str, list[dict[str, str]]]]


def load_any_json_array_python(
    conn: Connection, query: bytes, *, binary: bool
) -> PythonOut:
    with conn.cursor() as cursor:
        cursor.execute(query, binary=binary)
        rows = cursor.fetchall()

    return [
        (
            row[0],
            [(date.fromisoformat(item[0]), Decimal(item[1])) for item in row[1]],
        )
        for row in rows
    ]


def load_any_json_array_json(
    conn: Connection, query: bytes, *, binary: bool
) -> JSONOut:
    with conn.cursor() as cursor:
        cursor.execute(query, binary=binary)
        rows = cursor.fetchall()

    return [
        (
            row[0],
            [{"date": item[0], "price": item[1]} for item in row[1]],
        )
        for row in rows
    ]


def load_any_json_object_python(
    conn: Connection, query: bytes, *, binary: bool
) -> PythonOut:
    with conn.cursor() as cursor:
        cursor.execute(query, binary=binary)
        rows = cursor.fetchall()

    return [
        (
            row[0],
            [
                (date.fromisoformat(item["date"]), Decimal(item["price"]))
                for item in row[1]
            ],
        )
        for row in rows
    ]


def load_any_json_object_json(
    conn: Connection, query: bytes, *, binary: bool
) -> PythonOut:
    with conn.cursor() as cursor:
        cursor.execute(query, binary=binary)
        return cursor.fetchall()


def load_composite_text_python(conn: Connection) -> PythonOut:
    with conn.cursor() as cursor:
        cursor.execute(COMPOSITE_QUERY, binary=False)
        rows = cursor.fetchall()

    return [
        (
            row[0],
            [(date.fromisoformat(item[0]), Decimal(item[1])) for item in row[1]],
        )
        for row in rows
    ]


def load_composite_text_json(conn: Connection) -> JSONOut:
    with conn.cursor() as cursor:
        cursor.execute(COMPOSITE_QUERY, binary=False)
        rows = cursor.fetchall()

    return [
        (row[0], [{"date": item[0], "price": item[1]} for item in row[1]])
        for row in rows
    ]


def load_composite_binary_python(conn: Connection) -> PythonOut:
    with conn.cursor() as cursor:
        cursor.execute(COMPOSITE_QUERY, binary=True)
        return cursor.fetchall()


def load_composite_binary_json(conn: Connection) -> JSONOut:
    with conn.cursor() as cursor:
        cursor.execute(COMPOSITE_QUERY, binary=True)
        rows = cursor.fetchall()

    return [
        (
            row[0],
            [{"date": item[0].isoformat(), "price": str(item[1])} for item in row[1]],
        )
        for row in rows
    ]


@pytest.mark.benchmark(group="json out")
class TestJSONOut:
    @pytest.mark.parametrize("binary", [False, True])
    @pytest.mark.parametrize(
        "expr",
        [JSON_OBJECT_EXPR, JSONB_OBJECT_EXPR],
        ids=["json object", "jsonb object"],
    )
    def test_json_object(
        self,
        conn: Connection,
        benchmark: BenchmarkFixture,
        binary: bool,
        expr: str,
    ):
        benchmark(
            load_any_json_object_json, conn, BASE_QUERY.format(expr), binary=binary
        )

    def test_composite_binary(self, conn: Connection, benchmark: BenchmarkFixture):
        benchmark(load_composite_binary_json, conn)

    def test_composite_text(self, conn: Connection, benchmark: BenchmarkFixture):
        benchmark(load_composite_text_json, conn)


@pytest.mark.benchmark(group="python out")
class TestPythonOut:
    @pytest.mark.parametrize("binary", [False, True])
    @pytest.mark.parametrize(
        "expr",
        [JSON_ARRAY_EXPR, JSONB_ARRAY_EXPR],
        ids=["json array", "jsonb array"],
    )
    def test_json_array(
        self,
        conn: Connection,
        benchmark: BenchmarkFixture,
        binary: bool,
        expr: str,
    ):
        benchmark(
            load_any_json_array_python, conn, BASE_QUERY.format(expr), binary=binary
        )

    def test_composite_binary(self, conn: Connection, benchmark: BenchmarkFixture):
        benchmark(load_composite_binary_python, conn)

    def test_composite_text(self, conn: Connection, benchmark: BenchmarkFixture):
        benchmark(load_composite_text_python, conn)
