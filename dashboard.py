import streamlit as st
import plotly.express as px
import plotly.graph_objects as go
from plotly.subplots import make_subplots
import psycopg2
import pandas as pd

# ── Page config ───────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Revenue Cycle Analytics",
    page_icon="📊",
    layout="wide",
    initial_sidebar_state="collapsed"
)

# ── Global CSS ────────────────────────────────────────────────────────────────
st.markdown("""
<style>
@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap');

/* ── Base ── */
html, body, [class*="css"] { font-family: 'Inter', -apple-system, sans-serif; }
#MainMenu, footer, header { visibility: hidden; }
.stApp { background: #F8FAFC; }
[data-testid="stAppViewContainer"] { padding-top: 0; }
section[data-testid="stSidebar"] { background: #FFFFFF; border-right: 1px solid #E2E8F0; }

/* ── Page header ── */
.page-header {
    padding: 28px 0 20px 0;
    border-bottom: 1px solid #E2E8F0;
    margin-bottom: 28px;
}
.page-title {
    font-size: 22px;
    font-weight: 700;
    color: #0F172A;
    letter-spacing: -0.02em;
}
.page-meta {
    font-size: 13px;
    color: #94A3B8;
    margin-top: 4px;
    font-weight: 400;
}

/* ── KPI cards ── */
.kpi-grid {
    display: grid;
    grid-template-columns: repeat(6, 1fr);
    gap: 16px;
    margin-bottom: 32px;
}
.kpi-card {
    background: white;
    border-radius: 12px;
    padding: 20px 20px 16px 20px;
    border: 1px solid #E2E8F0;
    box-shadow: 0 1px 3px rgba(15,23,42,0.05);
    position: relative;
    overflow: hidden;
}
.kpi-card::after {
    content: '';
    position: absolute;
    bottom: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: var(--accent);
    border-radius: 0 0 2px 2px;
}
.kpi-label {
    font-size: 11px;
    font-weight: 600;
    color: #94A3B8;
    text-transform: uppercase;
    letter-spacing: 0.06em;
    margin-bottom: 10px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
}
.kpi-value {
    font-size: 26px;
    font-weight: 700;
    color: #0F172A;
    letter-spacing: -0.02em;
    line-height: 1;
    margin-bottom: 6px;
}
.kpi-sub {
    font-size: 11px;
    color: #CBD5E1;
    font-weight: 500;
}

/* ── Section headers ── */
.section-title {
    font-size: 15px;
    font-weight: 600;
    color: #1E293B;
    margin: 0 0 4px 0;
    letter-spacing: -0.01em;
}
.section-desc {
    font-size: 12px;
    color: #94A3B8;
    margin: 0 0 16px 0;
    font-weight: 400;
}
.section-wrap {
    background: white;
    border-radius: 12px;
    padding: 20px 20px 12px 20px;
    border: 1px solid #E2E8F0;
    box-shadow: 0 1px 3px rgba(15,23,42,0.05);
    margin-bottom: 20px;
}

/* ── Provider table ── */
.styled-table thead tr th {
    background: #F8FAFC !important;
    font-size: 11px !important;
    font-weight: 600 !important;
    color: #64748B !important;
    text-transform: uppercase;
    letter-spacing: 0.05em;
    border-bottom: 1px solid #E2E8F0 !important;
}
</style>
""", unsafe_allow_html=True)

# ── Plotly base theme ─────────────────────────────────────────────────────────
CHART = dict(
    paper_bgcolor="white",
    plot_bgcolor="white",
    font=dict(family="Inter, -apple-system, sans-serif", color="#475569", size=12),
    margin=dict(t=8, b=8, l=8, r=8),
    xaxis=dict(
        showgrid=False, showline=False, zeroline=False,
        tickfont=dict(size=11, color="#94A3B8"),
        tickcolor="#E2E8F0"
    ),
    yaxis=dict(
        showgrid=True, gridcolor="#F1F5F9", gridwidth=1,
        showline=False, zeroline=False,
        tickfont=dict(size=11, color="#94A3B8"),
    ),
    legend=dict(
        orientation="h", y=1.08, x=0,
        bgcolor="rgba(0,0,0,0)",
        font=dict(size=11, color="#64748B"),
        borderwidth=0
    ),
    hoverlabel=dict(
        bgcolor="white", bordercolor="#E2E8F0",
        font=dict(size=12, color="#0F172A", family="Inter")
    ),
)

# Palette
BLUE   = "#2563EB"
TEAL   = "#0891B2"
GREEN  = "#059669"
AMBER  = "#D97706"
RED    = "#DC2626"
PURPLE = "#7C3AED"
SLATE  = "#64748B"
L_BLUE = "#DBEAFE"
SEQ    = ["#2563EB", "#0891B2", "#059669", "#7C3AED", "#D97706", "#DC2626"]

# ── Data loading ──────────────────────────────────────────────────────────────
@st.cache_data
def load_data():
    conn = psycopg2.connect(
        host="127.0.0.1", port=5432, dbname="dbt", user="dbt", password="dbt"
    )

    revenue = pd.read_sql("""
        SELECT
            TO_CHAR(revenue_month, 'YYYY-MM') AS month,
            SUM(gross_charges)::float         AS gross_charges,
            SUM(net_collections)::float        AS net_collections,
            ROUND(AVG(gross_collection_rate)::numeric,1)::float AS collection_rate,
            ROUND(AVG(denial_rate)::numeric,1)::float           AS denial_rate,
            ROUND(AVG(avg_days_in_ar)::numeric,1)::float        AS avg_days_in_ar,
            ROUND(AVG(revenue_health_score)::numeric,1)::float  AS health_score
        FROM public_marts.mart_revenue_kpis
        GROUP BY 1 ORDER BY 1
    """, conn)

    payers = pd.read_sql("""
        SELECT
            payer_name, plan_type, payer_category,
            ROUND(AVG(payer_performance_score)::numeric,1)::float AS performance_score,
            ROUND(AVG(denial_rate_pct)::numeric,1)::float         AS denial_rate,
            ROUND(AVG(collection_rate_pct)::numeric,1)::float     AS collection_rate,
            ROUND(AVG(avg_days_to_payment)::numeric,1)::float     AS avg_days_to_payment,
            SUM(total_billed)::float  AS total_billed,
            SUM(total_paid)::float    AS total_paid,
            SUM(total_denied)::float  AS total_denied
        FROM public_marts.mart_payer_performance
        GROUP BY 1,2,3 ORDER BY 4 DESC
    """, conn)

    denials = pd.read_sql("""
        SELECT
            denial_category,
            TO_CHAR(denial_month, 'YYYY-MM')                      AS month,
            SUM(total_denials)                                     AS total_denials,
            ROUND(SUM(total_denied_amount)::numeric,2)::float      AS denied_amount,
            ROUND(AVG(appeal_overturn_rate_pct)::numeric,1)::float AS overturn_rate,
            SUM(appeals_submitted)                                 AS appeals_submitted,
            SUM(appeals_overturned)                                AS appeals_overturned
        FROM public_marts.mart_denial_summary
        GROUP BY 1,2 ORDER BY 1,2
    """, conn)

    aging = pd.read_sql("""
        SELECT aging_bucket, aging_bucket_sort,
            COUNT(*)::int                                AS claim_count,
            ROUND(SUM(outstanding_balance)::numeric,2)::float AS balance
        FROM public_facts.fct_aging
        GROUP BY 1,2 ORDER BY 2
    """, conn)

    providers = pd.read_sql("""
        SELECT
            provider_name, specialty, specialty_category,
            ROUND(AVG(gross_collection_rate)::numeric,1)::float AS collection_rate,
            ROUND(AVG(denial_rate)::numeric,1)::float           AS denial_rate,
            SUM(claim_volume)::int                              AS claim_volume,
            ROUND(SUM(gross_charges)::numeric,2)::float         AS gross_charges,
            ROUND(SUM(net_collections)::numeric,2)::float       AS net_collections,
            ROUND(AVG(revenue_health_score)::numeric,1)::float  AS health_score
        FROM public_marts.mart_revenue_kpis
        GROUP BY 1,2,3 ORDER BY 7 DESC
    """, conn)

    conn.close()
    return revenue, payers, denials, aging, providers

revenue, payers, denials, aging, providers = load_data()

# ── KPI values ────────────────────────────────────────────────────────────────
total_charges   = revenue["gross_charges"].sum()
total_collected = revenue["net_collections"].sum()
avg_collection  = revenue["collection_rate"].mean()
avg_denial      = revenue["denial_rate"].mean()
total_ar        = aging["balance"].sum()
avg_health      = revenue["health_score"].mean()

# ── Sidebar ───────────────────────────────────────────────────────────────────
with st.sidebar:
    st.markdown("### 📊 Revenue Cycle")
    st.markdown("---")
    st.markdown("**Filters**")
    selected_specialty = st.multiselect(
        "Specialty",
        options=sorted(providers["specialty_category"].dropna().unique()),
        default=[],
        placeholder="All specialties"
    )
    selected_payer_cat = st.multiselect(
        "Payer Category",
        options=sorted(payers["payer_category"].dropna().unique()),
        default=[],
        placeholder="All payer types"
    )
    st.markdown("---")
    st.markdown(
        "<span style='font-size:11px;color:#94A3B8'>Built with dbt · PostgreSQL · Streamlit</span>",
        unsafe_allow_html=True
    )

# Apply sidebar filters
payers_f   = payers[payers["payer_category"].isin(selected_payer_cat)]   if selected_payer_cat   else payers
providers_f = providers[providers["specialty_category"].isin(selected_specialty)] if selected_specialty else providers

# ── Page header ───────────────────────────────────────────────────────────────
st.markdown("""
<div class="page-header">
    <div class="page-title">Healthcare Revenue Cycle</div>
    <div class="page-meta">Claims · Denials · AR Aging · Payer Performance · Provider KPIs</div>
</div>
""", unsafe_allow_html=True)

# ── KPI Cards ─────────────────────────────────────────────────────────────────
kpis = [
    dict(label="Total Charges",      value=f"${total_charges/1e6:.2f}M",  sub="Gross billed",           accent=BLUE),
    dict(label="Net Collected",       value=f"${total_collected/1e6:.2f}M", sub="Payments received",      accent=GREEN),
    dict(label="Collection Rate",     value=f"{avg_collection:.1f}%",       sub="Avg gross rate",         accent=TEAL),
    dict(label="Denial Rate",         value=f"{avg_denial:.1f}%",           sub="Avg across payers",      accent=AMBER),
    dict(label="Total AR Balance",    value=f"${total_ar/1e6:.2f}M",       sub="Outstanding receivables", accent=RED),
    dict(label="Avg Health Score",    value=f"{avg_health:.0f}/100",        sub="Revenue health index",   accent=PURPLE),
]

cols = st.columns(6)
for col, k in zip(cols, kpis):
    col.markdown(f"""
    <div class="kpi-card" style="--accent:{k['accent']}">
        <div class="kpi-label">{k['label']}</div>
        <div class="kpi-value">{k['value']}</div>
        <div class="kpi-sub">{k['sub']}</div>
    </div>
    """, unsafe_allow_html=True)

st.markdown("<div style='margin-bottom:8px'></div>", unsafe_allow_html=True)

# ── Row 1: Revenue Trend + AR Aging ──────────────────────────────────────────
col1, col2 = st.columns([3, 2], gap="medium")

with col1:
    st.markdown("""
    <div class="section-title">Revenue Trend</div>
    <div class="section-desc">Monthly gross charges vs. net collections with collection rate overlay</div>
    """, unsafe_allow_html=True)

    fig = make_subplots(specs=[[{"secondary_y": True}]])

    fig.add_trace(go.Bar(
        x=revenue["month"], y=revenue["gross_charges"],
        name="Gross Charges",
        marker=dict(color="#DBEAFE", line=dict(width=0)),
        hovertemplate="<b>%{x}</b><br>Gross: $%{y:,.0f}<extra></extra>"
    ))
    fig.add_trace(go.Bar(
        x=revenue["month"], y=revenue["net_collections"],
        name="Net Collections",
        marker=dict(color=BLUE, line=dict(width=0)),
        hovertemplate="<b>%{x}</b><br>Collected: $%{y:,.0f}<extra></extra>"
    ))
    fig.add_trace(go.Scatter(
        x=revenue["month"], y=revenue["collection_rate"],
        name="Collection Rate %",
        mode="lines+markers",
        line=dict(color=AMBER, width=2, dash="dot"),
        marker=dict(size=4, color=AMBER),
        hovertemplate="<b>%{x}</b><br>Rate: %{y:.1f}%<extra></extra>"
    ), secondary_y=True)

    fig.update_layout(
        **CHART,
        height=300,
        barmode="overlay",
        margin=dict(t=4, b=4, l=4, r=4),
    )
    fig.update_yaxes(
        title_text="Amount ($)", secondary_y=False,
        tickfont=dict(size=11, color="#94A3B8"),
        showgrid=True, gridcolor="#F1F5F9"
    )
    fig.update_yaxes(
        title_text="Rate (%)", secondary_y=True,
        tickfont=dict(size=11, color="#94A3B8"),
        showgrid=False
    )
    with st.container():
        st.markdown('<div class="section-wrap" style="padding-bottom:4px">', unsafe_allow_html=True)
        st.plotly_chart(fig, use_container_width=True, config={"displayModeBar": False})
        st.markdown('</div>', unsafe_allow_html=True)

with col2:
    st.markdown("""
    <div class="section-title">AR Aging</div>
    <div class="section-desc">Outstanding balance by age bucket</div>
    """, unsafe_allow_html=True)

    aging_colors = [GREEN, TEAL, AMBER, "#F97316", RED]
    fig2 = go.Figure(go.Bar(
        x=aging["balance"],
        y=aging["aging_bucket"],
        orientation="h",
        marker=dict(
            color=aging_colors[:len(aging)],
            line=dict(width=0)
        ),
        hovertemplate="<b>%{y}</b><br>$%{x:,.0f}<extra></extra>",
        text=[f"${v/1e3:.0f}K" for v in aging["balance"]],
        textposition="outside",
        textfont=dict(size=11, color="#64748B")
    ))
    fig2.update_layout(
        **CHART,
        height=300,
        margin=dict(t=4, b=4, l=4, r=60),
        xaxis=dict(showgrid=False, showticklabels=False, showline=False),
        yaxis=dict(showgrid=False, tickfont=dict(size=11, color="#475569")),
    )
    with st.container():
        st.markdown('<div class="section-wrap" style="padding-bottom:4px">', unsafe_allow_html=True)
        st.plotly_chart(fig2, use_container_width=True, config={"displayModeBar": False})
        st.markdown('</div>', unsafe_allow_html=True)

# ── Row 2: Denial Analysis ────────────────────────────────────────────────────
st.markdown("""
<div class="section-title" style="margin-top:8px">Denial Analysis</div>
<div class="section-desc">Denial volume by category and trend over time — color indicates appeal overturn rate</div>
""", unsafe_allow_html=True)

col3, col4 = st.columns(2, gap="medium")

with col3:
    denial_by_cat = (
        denials.groupby("denial_category")
        .agg(total_denials=("total_denials","sum"),
             denied_amount=("denied_amount","sum"),
             overturn_rate=("overturn_rate","mean"))
        .reset_index()
        .sort_values("denied_amount", ascending=True)
    )

    fig3 = px.bar(
        denial_by_cat, x="denied_amount", y="denial_category",
        orientation="h",
        color="overturn_rate",
        color_continuous_scale=[[0,"#EF4444"],[0.5,"#F59E0B"],[1,"#10B981"]],
        range_color=[0, 100],
        labels={"denied_amount":"Denied ($)","denial_category":"","overturn_rate":"Overturn %"},
        custom_data=["total_denials","overturn_rate"]
    )
    fig3.update_traces(
        hovertemplate="<b>%{y}</b><br>Denied: $%{x:,.0f}<br>Claims: %{customdata[0]:,}<br>Overturn rate: %{customdata[1]:.1f}%<extra></extra>",
        marker_line_width=0
    )
    fig3.update_layout(
        **CHART,
        height=320,
        margin=dict(t=4, b=4, l=4, r=4),
        coloraxis_colorbar=dict(
            title="Overturn %", thickness=10, len=0.7,
            tickfont=dict(size=10, color="#94A3B8"),
            titlefont=dict(size=10, color="#94A3B8")
        ),
        yaxis=dict(showgrid=False, tickfont=dict(size=11)),
        xaxis=dict(showgrid=True, gridcolor="#F1F5F9", tickfont=dict(size=11, color="#94A3B8")),
    )
    with st.container():
        st.markdown('<div class="section-wrap" style="padding-bottom:4px">', unsafe_allow_html=True)
        st.plotly_chart(fig3, use_container_width=True, config={"displayModeBar": False})
        st.markdown('</div>', unsafe_allow_html=True)

with col4:
    denial_trend = (
        denials.groupby("month")
        .agg(total_denials=("total_denials","sum"),
             denied_amount=("denied_amount","sum"))
        .reset_index()
    )

    fig4 = go.Figure()
    fig4.add_trace(go.Scatter(
        x=denial_trend["month"], y=denial_trend["denied_amount"],
        fill="tozeroy",
        fillcolor="rgba(220,38,38,0.06)",
        line=dict(color=RED, width=2),
        mode="lines",
        hovertemplate="<b>%{x}</b><br>Denied: $%{y:,.0f}<extra></extra>"
    ))
    fig4.update_layout(
        **CHART,
        height=320,
        margin=dict(t=4, b=4, l=4, r=4),
        xaxis=dict(showgrid=False, tickangle=-30, tickfont=dict(size=10, color="#94A3B8")),
        yaxis=dict(showgrid=True, gridcolor="#F1F5F9", tickfont=dict(size=11, color="#94A3B8")),
    )
    with st.container():
        st.markdown('<div class="section-wrap" style="padding-bottom:4px">', unsafe_allow_html=True)
        st.markdown("""
        <div style="font-size:12px;font-weight:600;color:#94A3B8;margin-bottom:4px">
            DENIED AMOUNT OVER TIME
        </div>""", unsafe_allow_html=True)
        st.plotly_chart(fig4, use_container_width=True, config={"displayModeBar": False})
        st.markdown('</div>', unsafe_allow_html=True)

# ── Row 3: Payer Performance ──────────────────────────────────────────────────
st.markdown("""
<div class="section-title" style="margin-top:8px">Payer Performance</div>
<div class="section-desc">How each payer compares on collection rate, denial rate, and composite score</div>
""", unsafe_allow_html=True)

col5, col6 = st.columns(2, gap="medium")

with col5:
    cat_colors = {c: SEQ[i % len(SEQ)] for i, c in enumerate(sorted(payers_f["payer_category"].unique()))}

    fig5 = px.scatter(
        payers_f,
        x="denial_rate", y="collection_rate",
        size="total_billed",
        color="payer_category",
        hover_name="payer_name",
        size_max=40,
        color_discrete_map=cat_colors,
        labels={
            "denial_rate": "Denial Rate (%)",
            "collection_rate": "Collection Rate (%)",
            "payer_category": ""
        },
        custom_data=["payer_name","avg_days_to_payment","performance_score"]
    )
    fig5.update_traces(
        hovertemplate="<b>%{customdata[0]}</b><br>Denial: %{x:.1f}%<br>Collection: %{y:.1f}%<br>Avg days to pay: %{customdata[1]:.0f}<br>Score: %{customdata[2]:.0f}/100<extra></extra>",
        marker=dict(line=dict(width=1.5, color="white"), opacity=0.85)
    )
    # Quadrant lines
    xmid = payers_f["denial_rate"].median()
    ymid = payers_f["collection_rate"].median()
    fig5.add_hline(y=ymid, line=dict(color="#E2E8F0", width=1, dash="dot"))
    fig5.add_vline(x=xmid, line=dict(color="#E2E8F0", width=1, dash="dot"))

    fig5.update_layout(
        **CHART,
        height=340,
        margin=dict(t=4, b=4, l=4, r=4),
        xaxis=dict(showgrid=True, gridcolor="#F1F5F9"),
        yaxis=dict(showgrid=True, gridcolor="#F1F5F9"),
        legend=dict(orientation="h", y=-0.15, x=0, font=dict(size=11)),
    )
    with st.container():
        st.markdown('<div class="section-wrap" style="padding-bottom:4px">', unsafe_allow_html=True)
        st.markdown("""
        <div style="font-size:12px;font-weight:600;color:#94A3B8;margin-bottom:4px">
            DENIAL RATE vs COLLECTION RATE &nbsp;·&nbsp; bubble size = total billed
        </div>""", unsafe_allow_html=True)
        st.plotly_chart(fig5, use_container_width=True, config={"displayModeBar": False})
        st.markdown('</div>', unsafe_allow_html=True)

with col6:
    payers_sorted = payers_f.sort_values("performance_score", ascending=True)
    score_colors  = [
        RED if s < 40 else AMBER if s < 65 else GREEN
        for s in payers_sorted["performance_score"]
    ]

    fig6 = go.Figure(go.Bar(
        x=payers_sorted["performance_score"],
        y=payers_sorted["payer_name"],
        orientation="h",
        marker=dict(color=score_colors, line=dict(width=0)),
        hovertemplate="<b>%{y}</b><br>Score: %{x:.0f}/100<extra></extra>",
        text=[f"{v:.0f}" for v in payers_sorted["performance_score"]],
        textposition="outside",
        textfont=dict(size=11, color="#64748B")
    ))
    fig6.update_layout(
        **CHART,
        height=340,
        margin=dict(t=4, b=4, l=4, r=40),
        xaxis=dict(showgrid=False, showticklabels=False, range=[0, 115]),
        yaxis=dict(showgrid=False, tickfont=dict(size=11, color="#475569")),
    )
    with st.container():
        st.markdown('<div class="section-wrap" style="padding-bottom:4px">', unsafe_allow_html=True)
        st.markdown("""
        <div style="font-size:12px;font-weight:600;color:#94A3B8;margin-bottom:4px">
            PAYER PERFORMANCE SCORE &nbsp;·&nbsp;
            <span style="color:#DC2626">■</span> &lt;40 &nbsp;
            <span style="color:#D97706">■</span> 40–65 &nbsp;
            <span style="color:#059669">■</span> 65+
        </div>""", unsafe_allow_html=True)
        st.plotly_chart(fig6, use_container_width=True, config={"displayModeBar": False})
        st.markdown('</div>', unsafe_allow_html=True)

# ── Row 4: Provider Leaderboard ───────────────────────────────────────────────
st.markdown("""
<div class="section-title" style="margin-top:8px">Provider Leaderboard</div>
<div class="section-desc">Provider-level revenue KPIs — click a column header to sort</div>
""", unsafe_allow_html=True)

display_cols = ["provider_name","specialty","claim_volume",
                "gross_charges","net_collections","collection_rate","denial_rate","health_score"]

def score_color(val):
    if not isinstance(val, float): return ""
    if   val >= 70: bg = "rgba(5,150,105,0.10)";  fg = "#065F46"
    elif val >= 50: bg = "rgba(217,119,6,0.10)";   fg = "#92400E"
    else:           bg = "rgba(220,38,38,0.10)";   fg = "#7F1D1D"
    return f"background-color:{bg};color:{fg};font-weight:600"

styled = (
    providers_f[display_cols]
    .rename(columns={
        "provider_name":   "Provider",
        "specialty":       "Specialty",
        "claim_volume":    "Claims",
        "gross_charges":   "Charges ($)",
        "net_collections": "Collected ($)",
        "collection_rate": "Coll. %",
        "denial_rate":     "Denial %",
        "health_score":    "Score"
    })
    .style
    .format({
        "Charges ($)":   "${:,.0f}",
        "Collected ($)": "${:,.0f}",
        "Coll. %":       "{:.1f}%",
        "Denial %":      "{:.1f}%",
        "Score":         "{:.0f}"
    })
    .applymap(score_color, subset=["Score"])
    .set_table_styles([
        {"selector": "thead tr th",
         "props": [("background","#F8FAFC"),("font-size","11px"),("font-weight","600"),
                   ("color","#64748B"),("text-transform","uppercase"),
                   ("letter-spacing","0.05em"),("border-bottom","1px solid #E2E8F0")]},
        {"selector": "tbody tr:hover",
         "props": [("background","#F8FAFC")]},
        {"selector": "td",
         "props": [("font-size","13px"),("color","#1E293B"),("border-bottom","1px solid #F1F5F9")]},
    ])
)

st.dataframe(styled, use_container_width=True, height=340)

# ── Footer ────────────────────────────────────────────────────────────────────
st.markdown("""
<div style="text-align:center;padding:32px 0 16px 0;color:#CBD5E1;font-size:11px;font-weight:500">
    Built with &nbsp;
    <span style="background:#EFF6FF;color:#2563EB;padding:2px 8px;border-radius:4px;font-weight:600">dbt</span>
    &nbsp;·&nbsp;
    <span style="background:#F0FDF4;color:#059669;padding:2px 8px;border-radius:4px;font-weight:600">PostgreSQL</span>
    &nbsp;·&nbsp;
    <span style="background:#FFF7ED;color:#EA580C;padding:2px 8px;border-radius:4px;font-weight:600">Streamlit</span>
    &nbsp;·&nbsp;
    <span style="background:#FAF5FF;color:#7C3AED;padding:2px 8px;border-radius:4px;font-weight:600">Plotly</span>
</div>
""", unsafe_allow_html=True)
