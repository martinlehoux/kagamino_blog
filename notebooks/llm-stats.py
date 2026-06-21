import marimo

__generated_with = "0.23.10"
app = marimo.App(width="full")


@app.cell
def _():
    import marimo as mo
    import pandas as pd
    import altair as alt

    return alt, mo, pd

# https://artificialanalysis.ai/leaderboards/models
@app.cell
def _(pd):
    COLUMNS = ["name", "aai_score", "price", "tok_per_sec"]
    ROWS = [
        ["DeepSeek V4 Flash", 37, 0.08, 101],
        ["DeepSeek V4 Pro", 44, 0.18, 85],
        ["Claude Opus 4.7", 54, 3.85, 51],
        ["Claude Opus 4.8", 56, 3.85, 58],
        ["Claude Sonnet 4.6", 47, 2.31, 50],
        ["Claude Haiku 4.5", 30, 0.77, 93],
        ["Gemini 3.5 Flash", 50, 1.31, 161],
        ["MiMo 2.5", 40, 0.06, 79],
        ["Nemotron 3 Ultra", 38, 0.58, 164],
        ["Gemma 4 E2B (local)", 9, 0.0, 60],
        ["GLM 5.2", 51, 0.90, 82],
        ["MiniMax M3", 44, 0.22, 68],
    ]
    df = pd.DataFrame(ROWS, columns=COLUMNS)
    return df


@app.cell
def _(df, mo):
    mo.md(f"""
    # 🤖 LLM Stats Tracker

    **{len(df)} models tracked**
    """)
    return


@app.cell
def _(alt, df):
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
