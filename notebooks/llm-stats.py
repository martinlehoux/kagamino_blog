import marimo

__generated_with = "0.23.10"
app = marimo.App(width="full")


@app.cell
def _():
    import marimo as mo
    import pandas as pd
    import altair as alt

    return alt, mo, pd


@app.cell
def _(pd):
    # Data — add new models here.
    #   price: blended $/1M tokens
    # https://artificialanalysis.ai/leaderboards/models
    MODELS = [
        {
            "name": "DeepSeek V4 Flash",
            "aai_score": 37,
            "price": 0.08,
            "tok_per_sec": 101,
        },
        {
            "name": "DeepSeek V4 Pro",
            "aai_score": 44,
            "price": 0.18,
            "tok_per_sec": 85,
        },
        {
            "name": "Claude Opus 4.7",
            "aai_score": 54,
            "price": 3.85,
            "tok_per_sec": 51,
        },
        {
            "name": "Claude Opus 4.8",
            "aai_score": 56,
            "price": 3.85,
            "tok_per_sec": 58,
        },
        {
            "name": "Claude Sonnet 4.6",
            "aai_score": 47,
            "price": 2.31,
            "tok_per_sec": 50,
        },
        {
            "name": "Claude Haiku 4.5",
            "aai_score": 30,
            "price": 0.77,
            "tok_per_sec": 93,
        },
        {
            "name": "Gemini 3.5 Flash",
            "aai_score": 50,
            "price": 1.31,
            "tok_per_sec": 161,
        },
        {
            "name": "MiMo 2.5",
            "aai_score": 40,
            "price": 0.06,
            "tok_per_sec": 79,
        },
        {
            "name": "Nemotron 3 Ultra",
            "aai_score": 38,
            "price": 0.58,
            "tok_per_sec": 164,
        },
        {
            "name": "Gemma 4 E2B (local)",
            "aai_score": 9,
            "price": 0.0,
            "tok_per_sec": 60,
        },
        {
            "name": "GLM 5.2",
            "aai_score": 51,
            "price": 0.90,
            "tok_per_sec": 82
        }
    ]

    df = pd.DataFrame(MODELS)
    return MODELS, df


@app.cell
def _(MODELS, mo):
    mo.md(f"""
    # 🤖 LLM Stats Tracker

    **{len(MODELS)} models tracked** — edit the `MODELS` list above to add more.
    """)
    return


@app.cell
def _(alt, df):
    # Price vs Quality (colour = tok/sec)
    scatter = (
        alt.Chart(df)
        .mark_circle(size=200)
        .encode(
            x=alt.X("price", title="Blended Price $/1M"),
            y=alt.Y("aai_score", title="AAI Score"),
            color=alt.Color("tok_per_sec:Q", title="tok/sec", scale=alt.Scale(scheme="viridis")),
            tooltip=["name", "aai_score", "price", "tok_per_sec"],
        )
    )
    labels = (
        alt.Chart(df)
        .mark_text(dy=-12, fontSize=10)
        .encode(
            x="price",
            y="aai_score",
            text="name",
        )
    )
    chart_price_quality = (scatter + labels).properties(width="container")
    chart_price_quality
    return


@app.cell
def _(alt, df):
    # Speed vs Quality (colour = price)
    bubble = (
        alt.Chart(df)
        .mark_circle(size=120, opacity=0.7)
        .encode(
            x=alt.X("tok_per_sec:Q", title="Tokens/sec"),
            y=alt.Y("aai_score:Q", title="AAI Score"),
            color=alt.Color("price:Q", title="Price $/1M", scale=alt.Scale(scheme="viridis")),
            tooltip=["name", "aai_score", "price", "tok_per_sec"],
        )
    )
    bubble_labels = (
        alt.Chart(df)
        .mark_text(dy=-14, fontSize=10, fontWeight="bold")
        .encode(
            x="tok_per_sec:Q",
            y="aai_score:Q",
            text="name:N",
        )
    )
    chart_speed_quality = (bubble + bubble_labels).properties(width="container")
    chart_speed_quality
    return


if __name__ == "__main__":
    app.run()
