import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import psycopg2
import pandas as pd

st.set_page_config(
    page_title="Healthcare Revenue Cycle Dashboard",
    page_icon="🏥",
    layout="wide"
)

@st.cache_data
def load_data():
    conn = psycopg2.connect(host="127.0.0.1", port=5432, dbname="dbt", user="dbt", password="dbt")

    revenue = pd.read_sql("""
        SELECT
            TO_CHAR(revenue_month, 'YYYY-MM') AS month,
            SUM(gross_charges)::float         AS gross_charges,
            SUM(net_collections)::float        AS net_collections,
            ROUND(AVG(gross_collection_rate)::numeric, 1)::float AS collection_rate,
            ROUND(AVG(denial_rate)::numeric, 1)::float           AS denial_rate,
            ROUND(AVG(avg_days_in_ar)::numeric, 1)::float        AS avg_days_in_ar,
            ROUND(AVG(revenue_health_score)::numeric, 1)::float  AS health_score
        FROM public_marts.mart_revenue_kpis
        GROUP BY 1 ORDER BY 1
    """, conn)

    payers = pd.read_sql("""
        SELECT
            payer_name,
            plan_type,
            payer_category,
            ROUND(AVG(payer_performance_score)::numeric, 1)::float AS performance_score,
            ROUND(AVG(denial_rate_pct)::numeric, 1)::float         AS denial_rate,
            ROUND(AVG(collection_rate_pct)::numeric, 1)::float     AS collection_rate,
            ROUND(AVG(avg_days_to_payment)::numeric, 1)::float     AS avg_days_to_payment,
            SUM(total_billed)::float   AS total_billed,
            SUM(total_paid)::float     AS total_paid,
            SUM(total_denied)::float   AS total_denied
        FROM public_marts.mart_payer_performance
        GROUP BY 1,2,3 ORDER BY 4 DESC
    """, conn)

    denials = pd.read_sql("""
        SELECT
            denial_category,
            TO_CHAR(denial_month, 'YYYY-MM')              AS month,
            SUM(total_denials)                             AS total_denials,
            ROUND(SUM(total_denied_amount)::numeric, 2)::float AS denied_amount,
            ROUND(AVG(appeal_overturn_rate_pct)::numeric, 1)::float AS overturn_rate,
            SUM(appeals_submitted)                         AS appeals_submitted,
            SUM(appeals_overturned)                        AS appeals_overturned
        FROM public_marts.mart_denial_summary
        GROUP BY 1,2 ORDER BY 1,2
    """, conn)

    aging = pd.read_sql("""
        SELECT aging_bucket, aging_bucket_sort,
            COUNT(*)::int                                AS claim_count,
            ROUND(SUM(outstanding_balance)::numeric, 2)::float AS balance
        FROM public_facts.fct_aging
        GROUP BY 1,2 ORDER BY 2
    """, conn)

    providers = pd.read_sql("""
        SELECT
            provider_name, specialty, specialty_category,
            ROUND(AVG(gross_collection_rate)::numeric, 1)::float AS collection_rate,
            ROUND(AVG(denial_rate)::numeric, 1)::float           AS denial_rate,
            SUM(claim_volume)::int                               AS claim_volume,
            ROUND(SUM(gross_charges)::numeric, 2)::float         AS gross_charges,
            ROUND(SUM(net_collections)::numeric, 2)::float       AS net_collections,
            ROUND(AVG(revenue_health_score)::numeric, 1)::float  AS health_score
        FROM public_marts.mart_revenue_kpis
        GROUP BY 1,2,3 ORDER BY 7 DESC
    """, conn)

    conn.close()
    return revenue, payers, denials, aging, providers

revenue, payers, denials, aging, providers = load_data()

# ── Header ───────────────────────────────────────────────────────────────────
st.title("🏥 Healthcare Revenue Cycle Dashboard")
st.caption("Powered by dbt · PostgreSQL · Streamlit")

# ── KPI Cards ────────────────────────────────────────────────────────────────
total_charges    = revenue["gross_charges"].sum()
total_collected  = revenue["net_collections"].sum()
avg_health       = revenue["health_score"].mean()
avg_collection   = revenue["collection_rate"].mean()
avg_denial       = revenue["denial_rate"].mean()
total_ar         = aging["balance"].sum()

k1, k2, k3, k4, k5, k6 = st.columns(6)
k1.metric("Total Charges",     f"${total_charges:,.0f}")
k2.metric("Total Collected",   f"${total_collected:,.0f}")
k3.metric("Avg Collection Rate", f"{avg_collection:.1f}%")
k4.metric("Avg Denial Rate",   f"{avg_denial:.1f}%")
k5.metric("Total AR Balance",  f"${total_ar:,.0f}")
k6.metric("Avg Health Score",  f"{avg_health:.1f} / 100")

st.divider()

# ── Row 1: Revenue Trend + AR Aging ──────────────────────────────────────────
col1, col2 = st.columns([2, 1])

with col1:
    st.subheader("Revenue Trend")
    fig = make_subplots(specs=[[{"secondary_y": True}]])
    fig.add_trace(go.Bar(x=revenue["month"], y=revenue["gross_charges"],
                         name="Gross Charges", marker_color="#4C9BE8", opacity=0.7))
    fig.add_trace(go.Bar(x=revenue["month"], y=revenue["net_collections"],
                         name="Net Collections", marker_color="#2ECC71", opacity=0.7))
    fig.add_trace(go.Scatter(x=revenue["month"], y=revenue["collection_rate"],
                             name="Collection Rate %", mode="lines+markers",
                             line=dict(color="#E74C3C", width=2)),
                  secondary_y=True)
    fig.update_layout(barmode="overlay", height=350, margin=dict(t=10, b=10),
                      legend=dict(orientation="h", y=1.1))
    fig.update_yaxes(title_text="Amount ($)", secondary_y=False)
    fig.update_yaxes(title_text="Rate (%)", secondary_y=True)
    st.plotly_chart(fig, use_container_width=True)

with col2:
    st.subheader("AR Aging Buckets")
    colors = ["#2ECC71", "#F39C12", "#E67E22", "#E74C3C", "#8E44AD"]
    fig = go.Figure(go.Pie(
        labels=aging["aging_bucket"],
        values=aging["balance"],
        marker_colors=colors,
        hole=0.45,
        textinfo="label+percent"
    ))
    fig.update_layout(height=350, margin=dict(t=10, b=10),
                      annotations=[dict(text=f"${total_ar/1e6:.1f}M", font_size=16, showarrow=False)])
    st.plotly_chart(fig, use_container_width=True)

# ── Row 2: Denial Analysis ────────────────────────────────────────────────────
st.subheader("Denial Analysis")
col3, col4 = st.columns(2)

with col3:
    denial_by_cat = denials.groupby("denial_category").agg(
        total_denials=("total_denials", "sum"),
        denied_amount=("denied_amount", "sum"),
        overturn_rate=("overturn_rate", "mean")
    ).reset_index().sort_values("denied_amount", ascending=True)

    fig = px.bar(denial_by_cat, x="denied_amount", y="denial_category",
                 orientation="h", color="overturn_rate",
                 color_continuous_scale="RdYlGn",
                 labels={"denied_amount": "Total Denied ($)", "denial_category": "",
                         "overturn_rate": "Overturn Rate %"},
                 title="Denied Amount by Category (color = appeal overturn rate)")
    fig.update_layout(height=380, margin=dict(t=40, b=10))
    st.plotly_chart(fig, use_container_width=True)

with col4:
    denial_trend = denials.groupby("month").agg(
        total_denials=("total_denials", "sum"),
        denied_amount=("denied_amount", "sum")
    ).reset_index()

    fig = px.area(denial_trend, x="month", y="denied_amount",
                  title="Denial Amount Over Time",
                  labels={"month": "", "denied_amount": "Denied Amount ($)"},
                  color_discrete_sequence=["#E74C3C"])
    fig.update_layout(height=380, margin=dict(t=40, b=10))
    st.plotly_chart(fig, use_container_width=True)

# ── Row 3: Payer Performance ──────────────────────────────────────────────────
st.subheader("Payer Performance")
col5, col6 = st.columns(2)

with col5:
    fig = px.scatter(payers,
                     x="denial_rate", y="collection_rate",
                     size="total_billed", color="payer_category",
                     hover_name="payer_name",
                     text="payer_name",
                     labels={"denial_rate": "Denial Rate (%)",
                             "collection_rate": "Collection Rate (%)",
                             "payer_category": "Category"},
                     title="Denial Rate vs Collection Rate by Payer")
    fig.update_traces(textposition="top center", textfont_size=9)
    fig.update_layout(height=400, margin=dict(t=40, b=10))
    st.plotly_chart(fig, use_container_width=True)

with col6:
    fig = px.bar(payers.sort_values("performance_score"),
                 x="performance_score", y="payer_name",
                 orientation="h",
                 color="performance_score",
                 color_continuous_scale="RdYlGn",
                 range_color=[0, 100],
                 labels={"performance_score": "Performance Score (0-100)", "payer_name": ""},
                 title="Payer Performance Score")
    fig.update_layout(height=400, margin=dict(t=40, b=10), coloraxis_showscale=False)
    st.plotly_chart(fig, use_container_width=True)

# ── Row 4: Provider Leaderboard ───────────────────────────────────────────────
st.subheader("Provider Leaderboard")
display_cols = ["provider_name", "specialty", "claim_volume",
                "gross_charges", "net_collections", "collection_rate",
                "denial_rate", "health_score"]

def color_score(val):
    if isinstance(val, float) and 0 <= val <= 100:
        r = int(255 * (1 - val/100))
        g = int(255 * (val/100))
        return f"background-color: rgba({r},{g},80,0.3)"
    return ""

styled = (providers[display_cols]
          .rename(columns={
              "provider_name": "Provider", "specialty": "Specialty",
              "claim_volume": "Claims", "gross_charges": "Gross Charges ($)",
              "net_collections": "Collected ($)", "collection_rate": "Collection %",
              "denial_rate": "Denial %", "health_score": "Health Score"
          })
          .style
          .format({"Gross Charges ($)": "${:,.0f}", "Collected ($)": "${:,.0f}",
                   "Collection %": "{:.1f}%", "Denial %": "{:.1f}%",
                   "Health Score": "{:.1f}"})
          .applymap(color_score, subset=["Health Score"]))

st.dataframe(styled, use_container_width=True, height=350)
