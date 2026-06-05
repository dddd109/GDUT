#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Generate publication-quality PNG charts for LiDAR sensor survey paper.
Output directory: D:\sensorhomework\论文\figure\
"""

import os
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.font_manager as fm
import matplotlib.patches as mpatches
from matplotlib.patches import FancyBboxPatch
import numpy as np

# ── Global settings ──────────────────────────────────────────────────────────
OUT_DIR = r"D:\sensorhomework\论文\figure"
os.makedirs(OUT_DIR, exist_ok=True)

# Color palette (paper theme)
DARK_BLUE   = "#0F2448"
MED_BLUE    = "#1A569E"
LIGHT_BLUE  = "#3B8ED8"
ORANGE      = "#E86A17"
GREEN       = "#27AE60"
RED         = "#C0392B"
YELLOW      = "#F1C40F"
GREY        = "#95A5A6"
WHITE       = "#FFFFFF"
LIGHT_GREY  = "#ECF0F1"

COLORS_4 = [MED_BLUE, LIGHT_BLUE, ORANGE, GREEN]
COLORS_5 = [DARK_BLUE, MED_BLUE, LIGHT_BLUE, ORANGE, GREEN]

# Font setup
FONT_CN = None
for fname in ['Microsoft YaHei', 'SimHei', 'KaiTi']:
    available = [f.name for f in fm.fontManager.ttflist]
    if fname in available:
        FONT_CN = fname
        break
if FONT_CN:
    plt.rcParams['font.sans-serif'] = [FONT_CN, 'DejaVu Sans']
else:
    plt.rcParams['font.sans-serif'] = ['DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams['figure.dpi'] = 150
plt.rcParams['savefig.dpi'] = 150
plt.rcParams['savefig.bbox'] = 'tight'
plt.rcParams['savefig.pad_inches'] = 0.15


def save(name, fig):
    """Save figure as PNG at 150 DPI."""
    path = os.path.join(OUT_DIR, name)
    fig.savefig(path, dpi=150, bbox_inches='tight', pad_inches=0.15,
                facecolor=fig.get_facecolor(), edgecolor='none')
    plt.close(fig)
    print(f"  Saved: {path}")


# ═══════════════════════════════════════════════════════════════════════════════
# Chart 1: detector_chain.png  — Horizontal grouped bar
# ═══════════════════════════════════════════════════════════════════════════════
def chart_detector_chain():
    detectors = ['PIN', 'APD', 'SPAD', 'SiPM']
    # Qualitative mapping to numeric for visualization
    # Gain (log scale friendly): PIN=0, APD=2, SPAD=6, SiPM=7  (log10 of gain)
    gain        = [0,   2,   6,   7  ]   # log10(gain): 1→0, 100→2, 1e6→6, 1e7→7
    cost        = [1,   2,   3,   4  ]   # 1=lowest cost, 4=highest
    complexity  = [1,   2,   3,   4.5]   # 1=simplest, 5=most complex
    pde         = [0,   0,   3.5, 3.5]   # 0=N/A, ~3.5=moderate PDE

    metrics = ['增益\n(Gain)', '成本\n(Cost)', '复杂度\n(Complexity)', '光子探测效率\n(PDE)']
    data = np.array([gain, cost, complexity, pde])

    fig, ax = plt.subplots(figsize=(8, 5.5))
    fig.patch.set_facecolor(WHITE)
    ax.set_facecolor(WHITE)

    x = np.arange(len(detectors))
    width = 0.18
    offsets = np.linspace(-0.27, 0.27, 4)

    bar_colors = [MED_BLUE, LIGHT_BLUE, ORANGE, GREEN]

    for i, (metric_data, color, offset) in enumerate(zip(data, bar_colors, offsets)):
        bars = ax.bar(x + offset, metric_data, width, color=color,
                      edgecolor='white', linewidth=0.5, zorder=3)
        # Add value labels
        for bar, val in zip(bars, metric_data):
            if val > 0:
                display_val = r'$10^{:d}$'.format(int(val)) if i == 0 else (
                    f'{val:.1f}' if isinstance(val, float) else str(val))
                # Show real labels for gain and PDE
                if i == 0:  # Gain
                    gain_labels = {0: '1', 2: '100', 6: r'$10^6$', 7: r'$10^7$'}
                    label = gain_labels.get(int(val), str(val))
                elif i == 3:  # PDE
                    pde_labels = {0: 'N/A', 3.5: '5–30%'}
                    label = pde_labels.get(val, str(val))
                elif i == 1:  # Cost
                    cost_labels = {1: '低 Low', 2: '中 Medium', 3: '高 High', 4: '极高 V.High'}
                    label = cost_labels.get(int(val), str(val))
                elif i == 2:  # Complexity
                    comp_labels = {1: '低 Low', 2: '中 Medium', 3: '高 High', 4.5: '极高 V.High'}
                    label = comp_labels.get(val, str(val))
                else:
                    label = str(val)
                ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.08,
                        label, ha='center', va='bottom', fontsize=6.5, color=DARK_BLUE,
                        fontweight='bold')

    ax.set_xticks(x)
    ax.set_xticklabels(detectors, fontsize=12, fontweight='bold', color=DARK_BLUE)
    ax.set_ylim(0, 8.5)
    ax.set_ylabel('相对评分 / Relative Score', fontsize=10, color=DARK_BLUE, fontweight='bold')
    ax.set_title('探测器链路对比  Detector Chain Comparison', fontsize=14,
                 fontweight='bold', color=DARK_BLUE, pad=15)

    # Legend
    legend_labels = ['增益 Gain', '成本 Cost', '复杂度 Complexity', '光子探测效率 PDE']
    legend_patches = [mpatches.Patch(color=c, label=l) for c, l in zip(bar_colors, legend_labels)]
    ax.legend(handles=legend_patches, loc='upper right', framealpha=0.9,
              fontsize=8, edgecolor=GREY)

    # Grid
    ax.yaxis.grid(True, linestyle='--', alpha=0.3, color=GREY)
    ax.set_axisbelow(True)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.tick_params(colors=DARK_BLUE)

    fig.tight_layout()
    save('detector_chain.png', fig)


# ═══════════════════════════════════════════════════════════════════════════════
# Chart 2: 905_vs_1550.png  — Grouped bar chart for wavelength comparison
# ═══════════════════════════════════════════════════════════════════════════════
def chart_905_vs_1550():
    categories = ['成本\nCost', '人眼安全\nEye Safety', 'Si探测器兼容\nSi Detector',
                  '大气穿透\nAtmosphere', '市场份额\nMarket Share', '峰值功率\nMax Power']

    # Score 1-5 (1=poor/worst, 5=best) — 905 scores
    scores_905  = [4.5, 2, 5, 2.5, 4.5, 2]   # low cost=good, low eye safety=poor, Si compatible=great,
                                                # decent atmos, dominant market, low max power
    scores_1550 = [2,   4, 1, 4,   1.5, 5]   # high cost=poor, good eye safety, no Si compatible,
                                                # better atmos, small market, high max power

    x = np.arange(len(categories))
    width = 0.35

    fig, ax = plt.subplots(figsize=(8, 5))
    fig.patch.set_facecolor(WHITE)
    ax.set_facecolor(WHITE)

    bars1 = ax.bar(x - width/2, scores_905, width, color=MED_BLUE, edgecolor='white',
                   linewidth=0.5, label='905 nm', zorder=3)
    bars2 = ax.bar(x + width/2, scores_1550, width, color=ORANGE, edgecolor='white',
                   linewidth=0.5, label='1550 nm', zorder=3)

    # Value labels
    qualitative_labels_905  = ['低 Low', '受限 Limited', '是 Yes', '好 Good', '~90%', '低 Low']
    qualitative_labels_1550 = ['高 High', '较好 Better', '否 No', '更好 Better', '~10%', '高 High']

    for bars, labels in [(bars1, qualitative_labels_905), (bars2, qualitative_labels_1550)]:
        for bar, label in zip(bars, labels):
            ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 0.05,
                    label, ha='center', va='bottom', fontsize=7, color=DARK_BLUE,
                    fontweight='bold')

    ax.set_xticks(x)
    ax.set_xticklabels(categories, fontsize=9, color=DARK_BLUE)
    ax.set_ylim(0, 6.2)
    ax.set_ylabel('评分 / Score (1–5)', fontsize=10, color=DARK_BLUE, fontweight='bold')
    ax.set_title('905 nm vs 1550 nm 波长方案对比', fontsize=14,
                 fontweight='bold', color=DARK_BLUE, pad=15)

    ax.legend(fontsize=10, loc='upper right', framealpha=0.9, edgecolor=GREY)
    ax.yaxis.grid(True, linestyle='--', alpha=0.3, color=GREY)
    ax.set_axisbelow(True)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.tick_params(colors=DARK_BLUE)

    fig.tight_layout()
    save('905_vs_1550.png', fig)


# ═══════════════════════════════════════════════════════════════════════════════
# Chart 3: cost_breakdown.png  — Pie chart of BOM cost
# ═══════════════════════════════════════════════════════════════════════════════
def chart_cost_breakdown():
    labels = [
        '激光器+驱动\nLaser+Driver\n15%',
        '探测器+ROIC\nDetector+ROIC\n25%',
        '光学+扫描镜\nOptics+Scanner\n20%',
        'PCB+电源\nPCB+Power\n12%',
        '外壳+组装\nHousing+Assembly\n18%',
        '测试+校准\nTest+Calibration\n10%',
    ]
    sizes = [15, 25, 20, 12, 18, 10]
    explode = (0, 0.08, 0, 0, 0, 0)  # Highlight detector as largest
    pie_colors = [MED_BLUE, ORANGE, LIGHT_BLUE, GREEN, DARK_BLUE, GREY]

    fig, ax = plt.subplots(figsize=(8, 6))
    fig.patch.set_facecolor(WHITE)

    wedges, texts = ax.pie(
        sizes, explode=explode, labels=None, colors=pie_colors,
        startangle=140, counterclock=False,
        wedgeprops={'linewidth': 1.5, 'edgecolor': 'white'},
        pctdistance=0.75,
    )

    # Custom legend with percentages
    legend_labels_with_pct = [
        f'激光器+驱动 Laser+Driver        15%',
        f'探测器+ROIC Detector+ROIC       25%',
        f'光学+扫描镜 Optics+Scanner      20%',
        f'PCB+电源 PCB+Power               12%',
        f'外壳+组装 Housing+Assembly      18%',
        f'测试+校准 Test+Calibration       10%',
    ]
    legend_patches = [mpatches.Patch(color=c, label=l)
                      for c, l in zip(pie_colors, legend_labels_with_pct)]
    ax.legend(handles=legend_patches, loc='center left',
              bbox_to_anchor=(1.0, 0.5), fontsize=9,
              framealpha=0.9, edgecolor=GREY, title='BOM 成本构成',
              title_fontsize=11)

    ax.set_title('典型MEMS激光雷达BOM成本分解 (2025)\nTypical MEMS LiDAR BOM Cost Breakdown',
                 fontsize=14, fontweight='bold', color=DARK_BLUE, pad=20)

    fig.tight_layout()
    save('cost_breakdown.png', fig)


# ═══════════════════════════════════════════════════════════════════════════════
# Chart 4: lidar_timeline.png  — Horizontal milestone timeline
# ═══════════════════════════════════════════════════════════════════════════════
def chart_lidar_timeline():
    milestones = [
        (2016, 'Velodyne HDL-64E\n$75,000', '机械旋转式\nMechanical Spinning'),
        (2020, 'MEMS LiDAR\n$1,000–5,000', '微机电系统\nMEMS Mirror'),
        (2023, '大规模量产\n$500–1,000', '转镜/棱镜方案\nRotating Mirror'),
        (2025, '芯片化LiDAR\n$300–500', '多通道集成\nMulti-Channel'),
        (2027, 'FMCW样机\n$200–400', '调频连续波\nCoherent Detection'),
        (2030, 'LiDAR-on-Chip\n<$100', '片上激光雷达\nPhotonic Integration'),
    ]

    years = [m[0] for m in milestones]
    labels_top = [m[1] for m in milestones]
    labels_bottom = [m[2] for m in milestones]

    fig, ax = plt.subplots(figsize=(10, 4.5))
    fig.patch.set_facecolor(WHITE)
    ax.set_facecolor(WHITE)

    # Draw main timeline line
    ax.axhline(y=0, color=DARK_BLUE, linewidth=3, zorder=2)

    # Color gradient from darkest to lightest
    n = len(milestones)
    colors = [DARK_BLUE, MED_BLUE, LIGHT_BLUE, ORANGE, '#E89B5E', GREEN]

    for i, (year, top_label, bottom_label) in enumerate(milestones):
        # Marker
        ax.plot(year, 0, 'o', markersize=14, color=colors[i % len(colors)],
                markeredgecolor='white', markeredgewidth=2, zorder=5)
        ax.plot(year, 0, 'o', markersize=5, color='white', zorder=6)

        # Top label (price)
        ax.text(year, 0.8, top_label, ha='center', va='bottom',
                fontsize=8.5, color=DARK_BLUE, fontweight='bold',
                linespacing=1.3)

        # Bottom label (technology)
        ax.text(year, -0.8, bottom_label, ha='center', va='top',
                fontsize=7.5, color=MED_BLUE, style='italic',
                linespacing=1.3)

        # Vertical connector line
        ax.plot([year, year], [0.1, 0.55], color=colors[i % len(colors)],
                linewidth=1.2, alpha=0.5, zorder=1)
        ax.plot([year, year], [-0.1, -0.55], color=colors[i % len(colors)],
                linewidth=1.2, alpha=0.5, zorder=1)

    # Arrow at the end
    ax.annotate('', xy=(2031.2, 0), xytext=(2030, 0),
                arrowprops=dict(arrowstyle='->', color=DARK_BLUE,
                               lw=2.5, ls='-'),
                zorder=4)

    ax.set_xlim(2014.5, 2031.5)
    ax.set_ylim(-1.8, 1.8)
    ax.set_title('激光雷达成本演进路线图  LiDAR Cost Evolution Roadmap',
                 fontsize=14, fontweight='bold', color=DARK_BLUE, pad=15)

    # Hide axes
    ax.set_yticks([])
    ax.set_xticks(years)
    ax.set_xticklabels([str(y) for y in years], fontsize=10,
                       fontweight='bold', color=DARK_BLUE)
    ax.spines['top'].set_visible(False)
    ax.spines['right'].set_visible(False)
    ax.spines['left'].set_visible(False)
    ax.spines['bottom'].set_visible(False)
    ax.tick_params(axis='x', colors=DARK_BLUE, length=0)

    # Add cost trend arrow annotations
    ax.annotate('成本下降趋势\nCost Reduction →', xy=(2022.5, 1.45),
                fontsize=8, color=RED, fontweight='bold', ha='center',
                style='italic')

    fig.tight_layout()
    save('lidar_timeline.png', fig)


# ═══════════════════════════════════════════════════════════════════════════════
# Chart 5: sensor_comparison_table.png  — Heatmap / colored table
# ═══════════════════════════════════════════════════════════════════════════════
def chart_sensor_comparison_table():
    sensors = ['Camera\n摄像头', 'mmWave\n毫米波雷达', 'Ultrasonic\n超声波', 'LiDAR\n激光雷达', 'IMU\n惯性单元']
    metrics = ['成本\nCost', '测距\nRange', '分辨率\nResolution',
               '天气适应性\nWeather', '尺寸\nSize', '颜色检测\nColor', '速度测量\nSpeed']

    # Score matrix: 1 (poor/red) to 5 (excellent/green)
    #                Cost  Range  Res  Weather  Size  Color  Speed
    scores = np.array([
        [4,    2,    5,   2,       3,    5,     1   ],  # Camera
        [3,    4,    2,   5,       4,    1,     5   ],  # mmWave
        [5,    1,    1,   4,       5,    1,     2   ],  # Ultrasonic
        [2,    5,    4,   3,       3,    2,     5   ],  # LiDAR
        [5,    1,    1,   5,       5,    1,     3   ],  # IMU
    ])

    fig, ax = plt.subplots(figsize=(9, 4.5))
    fig.patch.set_facecolor(WHITE)

    # Custom colormap: red → yellow → green
    from matplotlib.colors import LinearSegmentedColormap
    cmap_colors = ['#C0392B', '#E67E22', '#F1C40F', '#2ECC71', '#27AE60']
    cmap = LinearSegmentedColormap.from_list('custom_rg', cmap_colors, N=256)

    im = ax.imshow(scores, cmap=cmap, aspect='auto', vmin=1, vmax=5)

    # Axis ticks
    ax.set_xticks(range(len(metrics)))
    ax.set_yticks(range(len(sensors)))
    ax.set_xticklabels(metrics, fontsize=9, color=DARK_BLUE, fontweight='bold')
    ax.set_yticklabels(sensors, fontsize=10, color=DARK_BLUE, fontweight='bold')

    # Rotate x labels for readability
    plt.setp(ax.get_xticklabels(), rotation=0, ha='center')

    # Cell text labels with qualitative descriptors
    qualitative = [
        ['低 Low',     '短 Short',   '优秀 Excellent', '差 Poor',    '中 Medium', '是 Yes',     '差 Poor'],
        ['中 Medium',  '远 Long',    '一般 Moderate',  '优秀 Excellent', '小 Small',  '否 No',      '优秀 Excellent'],
        ['低 Low',     '极短 V.Short','差 Poor',       '好 Good',    '小 Small',  '否 No',      '一般 Moderate'],
        ['高 High',    '远 Long',    '好 Good',        '一般 Moderate', '中 Medium','否 No',      '优秀 Excellent'],
        ['低 Low',     '无 N/A',     '无 N/A',         '优秀 Excellent', '小 Small',  '否 No',      '一般 Moderate'],
    ]

    for i in range(len(sensors)):
        for j in range(len(metrics)):
            val = scores[i, j]
            # Cell background is already colored by imshow
            text_color = 'white' if val <= 2 else (DARK_BLUE if val >= 4 else DARK_BLUE)
            ax.text(j, i, f'{qualitative[i][j]}\n({val}/5)', ha='center', va='center',
                    fontsize=7, color=text_color, fontweight='bold', linespacing=1.2)

    # Grid lines
    for i in range(len(sensors) + 1):
        ax.axhline(y=i - 0.5, color='white', linewidth=2)
    for j in range(len(metrics) + 1):
        ax.axvline(x=j - 0.5, color='white', linewidth=2)

    ax.set_title('多传感器融合性能对比  Multi-Sensor Performance Comparison',
                 fontsize=13, fontweight='bold', color=DARK_BLUE, pad=15)

    # Colorbar
    cbar = plt.colorbar(im, ax=ax, shrink=0.85, pad=0.02)
    cbar.set_label('评分 Score (1=差 Poor  →  5=优秀 Excellent)', fontsize=8, color=DARK_BLUE)
    cbar.ax.tick_params(colors=DARK_BLUE, labelsize=7)
    cbar.outline.set_edgecolor(GREY)

    fig.tight_layout()
    save('sensor_comparison_table.png', fig)


# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════
if __name__ == '__main__':
    print("Generating charts...")
    print(f"Output directory: {OUT_DIR}")
    print(f"Using font: {FONT_CN or 'DejaVu Sans (English only)'}")
    print()

    chart_detector_chain()
    chart_905_vs_1550()
    chart_cost_breakdown()
    chart_lidar_timeline()
    chart_sensor_comparison_table()

    print(f"\nDone! All charts saved to {OUT_DIR}")
