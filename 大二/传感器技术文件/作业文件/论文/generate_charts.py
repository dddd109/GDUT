# -*- coding: utf-8 -*-
"""Generate charts for the paper and PPT"""
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.ticker as ticker
import numpy as np
import os

# Set Chinese font
plt.rcParams['font.sans-serif'] = ['SimHei', 'Microsoft YaHei', 'DejaVu Sans']
plt.rcParams['axes.unicode_minus'] = False
plt.rcParams['figure.dpi'] = 200

outdir = r"D:\sensorhomework\论文\figure"
os.makedirs(outdir, exist_ok=True)

# ============================================
# Chart 1: China Autonomous Driving Sensor Market Size
# ============================================
fig, ax1 = plt.subplots(figsize=(8, 5))

years = ['2023', '2024', '2025E', '2026E', '2027E', '2030E']
market_size = [260, 320, 380, 420, 490, 990]
colors_bar = ['#1A569E', '#1A569E', '#3B8ED8', '#3B8ED8', '#E86A17', '#E86A17']

bars = ax1.bar(years, market_size, color=colors_bar, width=0.6, edgecolor='white', linewidth=0.5)
ax1.set_ylabel('Market Size (100M RMB)', fontsize=13, fontweight='bold', color='#0F2448')
ax1.set_title('China Autonomous Driving Sensor Market Size Forecast', fontsize=15, fontweight='bold', color='#0F2448', pad=15)
ax1.set_ylim(0, 1200)

# Add value labels
for bar, val in zip(bars, market_size):
    ax1.text(bar.get_x() + bar.get_width()/2, bar.get_height() + 15,
             f'{val:.0f}B', ha='center', va='bottom', fontsize=11, fontweight='bold', color='#0F2448')

# CAGR annotation
ax1.annotate('CAGR 2025-2030: ~21%', xy=(4.5, 850), fontsize=12, color='#E86A17',
            fontweight='bold', ha='center',
            bbox=dict(boxstyle='round,pad=0.3', facecolor='#FFF3E0', edgecolor='#E86A17', alpha=0.8))

ax1.spines['top'].set_visible(False)
ax1.spines['right'].set_visible(False)
ax1.spines['left'].set_color('#CCCCCC')
ax1.spines['bottom'].set_color('#CCCCCC')
ax1.tick_params(colors='#666666')
ax1.set_facecolor('#FAFBFC')
fig.patch.set_facecolor('white')

plt.tight_layout()
fig.savefig(os.path.join(outdir, 'market_size.png'), bbox_inches='tight', facecolor='white')
plt.close()

# ============================================
# Chart 2: Sensor Market Share Breakdown
# ============================================
fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(10, 5))

# Pie chart - 2025
labels = ['LiDAR\n28%', 'mmWave Radar\n35%', 'Camera\n37%']
sizes_2025 = [28, 35, 37]
colors_pie = ['#E86A17', '#1A569E', '#3B8ED8']
explode = (0.05, 0, 0)

wedges, texts, autotexts = ax1.pie(sizes_2025, explode=explode, colors=colors_pie,
                                     autopct='', startangle=90, pctdistance=0.75,
                                     wedgeprops=dict(width=0.4, edgecolor='white'))
ax1.set_title('2025 Share\n(380B RMB Total)', fontsize=13, fontweight='bold', color='#0F2448', pad=15)

# Legend
ax1.legend(wedges, ['LiDAR', 'mmWave Radar', 'Camera'], title='Sensor Type',
          loc='lower center', bbox_to_anchor=(0.5, -0.15), ncol=3, fontsize=10)

# Pie chart - 2030
sizes_2030 = [45, 25, 30]
wedges2, texts2, autotexts2 = ax2.pie(sizes_2030, explode=(0.05, 0, 0), colors=colors_pie,
                                        autopct='', startangle=90, pctdistance=0.75,
                                        wedgeprops=dict(width=0.4, edgecolor='white'))
ax2.set_title('2030E Share\n(~1000B RMB Total)', fontsize=13, fontweight='bold', color='#0F2448', pad=15)

ax2.legend(wedges2, ['LiDAR 45%', 'mmWave Radar 25%', 'Camera 30%'], title='Sensor Type',
          loc='lower center', bbox_to_anchor=(0.5, -0.15), ncol=3, fontsize=10)

fig.patch.set_facecolor('white')
plt.tight_layout()
fig.savefig(os.path.join(outdir, 'market_share.png'), bbox_inches='tight', facecolor='white')
plt.close()

# ============================================
# Chart 3: LiDAR Cost Reduction Curve
# ============================================
fig, ax = plt.subplots(figsize=(8, 4.5))

years_cost = ['2016', '2020', '2022', '2024', '2025E', '2027E', '2030E']
lidar_cost = [75000, 10000, 3000, 500, 350, 180, 80]
radar_4d_cost = [0, 0, 0, 100, 80, 45, 25]

ax.plot(years_cost, lidar_cost, 'o-', color='#E86A17', linewidth=2.5, markersize=8,
        markerfacecolor='white', markeredgewidth=2, label='LiDAR Module (ADAS Grade)')
ax.fill_between(range(len(years_cost)), lidar_cost, alpha=0.08, color='#E86A17')

ax.plot(years_cost, radar_4d_cost, 's--', color='#1A569E', linewidth=2, markersize=7,
        markerfacecolor='white', markeredgewidth=2, label='4D Imaging Radar')

# Annotations
ax.annotate('$75,000', xy=(0, 75000), fontsize=9, color='#E86A17', fontweight='bold',
            ha='center', va='bottom', xytext=(0, 10), textcoords='offset points')
ax.annotate('$500', xy=(3, 500), fontsize=9, color='#E86A17', fontweight='bold',
            ha='center', va='bottom', xytext=(0, 10), textcoords='offset points')
ax.annotate('< $100', xy=(6, 80), fontsize=10, color='#E86A17', fontweight='bold',
            ha='center', va='bottom', xytext=(0, 10), textcoords='offset points',
            bbox=dict(boxstyle='round,pad=0.3', facecolor='#FFF3E0', edgecolor='#E86A17', alpha=0.9))

ax.set_ylabel('Unit Cost (USD, log scale)', fontsize=13, fontweight='bold', color='#0F2448')
ax.set_title('Sensor Cost Reduction Trajectory (2016-2030)', fontsize=15, fontweight='bold', color='#0F2448', pad=15)
ax.set_yscale('log')
ax.legend(fontsize=11, loc='upper right')
ax.set_ylim(10, 200000)
ax.grid(True, alpha=0.3, linestyle='--')
ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.set_facecolor('#FAFBFC')
fig.patch.set_facecolor('white')

plt.tight_layout()
fig.savefig(os.path.join(outdir, 'cost_curve.png'), bbox_inches='tight', facecolor='white')
plt.close()

# ============================================
# Chart 4: Sensor Performance Radar Chart
# ============================================
fig, ax = plt.subplots(figsize=(7, 7), subplot_kw=dict(projection='polar'))

categories = ['Range\nAccuracy', 'Velocity\nMeasurement', 'Angular\nResolution', 'All-Weather\nCapability',
              'Semantic\nRichness', 'Cost\nEfficiency', 'Night\nPerformance']
N = len(categories)
angles = [n / float(N) * 2 * np.pi for n in range(N)]
angles += angles[:1]

# Normalize to 0-5 scale
camera = [2.5, 1, 4, 1.5, 5, 5, 1] + [2.5]
radar = [3.5, 5, 2, 5, 1, 4.5, 5] + [3.5]
lidar = [5, 2, 5, 2.5, 2, 2, 4.5] + [5]
ultrasonic = [2, 1, 1, 3, 1, 5, 3] + [2]

ax.plot(angles, camera, 'o-', linewidth=2, color='#3B8ED8', markersize=6, label='Camera')
ax.fill(angles, camera, alpha=0.05, color='#3B8ED8')
ax.plot(angles, radar, 's-', linewidth=2, color='#1A569E', markersize=6, label='mmWave Radar')
ax.fill(angles, radar, alpha=0.05, color='#1A569E')
ax.plot(angles, lidar, 'D-', linewidth=2.5, color='#E86A17', markersize=7, label='LiDAR')
ax.fill(angles, lidar, alpha=0.08, color='#E86A17')
ax.plot(angles, ultrasonic, '^--', linewidth=1.5, color='#888888', markersize=5, label='Ultrasonic')

ax.set_xticks(angles[:-1])
ax.set_xticklabels(categories, fontsize=9, color='#0F2448', fontweight='bold')
ax.set_ylim(0, 5.5)
ax.set_yticks([1, 2, 3, 4, 5])
ax.set_yticklabels(['1', '2', '3', '4', '5'], fontsize=8, color='#999999')
ax.set_title('Sensor Performance Multi-Dimensional Comparison', fontsize=15, fontweight='bold',
             color='#0F2448', pad=25)
ax.legend(loc='upper right', bbox_to_anchor=(1.35, 1.1), fontsize=10, framealpha=0.9)
ax.set_facecolor('#FAFBFC')
fig.patch.set_facecolor('white')

plt.tight_layout()
fig.savefig(os.path.join(outdir, 'radar_chart.png'), bbox_inches='tight', facecolor='white')
plt.close()

# ============================================
# Chart 5: LiDAR Market Share by Company
# ============================================
fig, ax = plt.subplots(figsize=(8, 4.5))

companies = ['Hesai\nTech', 'RoboSense', 'Huawei\n(Yinwang)', 'Seyond\n(Tudatong)',
             'Valeo', 'Luminar', 'Innoviz', 'Others']
market_share = [37, 28, 18, 12, 2.5, 1.0, 0.8, 0.7]
colors_comp = ['#E86A17', '#E86A17', '#1A569E', '#1A569E', '#888888', '#888888', '#888888', '#AAAAAA']

bars = ax.barh(companies, market_share, color=colors_comp, height=0.6, edgecolor='white', linewidth=0.5)
ax.set_xlabel('Global Automotive LiDAR Market Share (%)', fontsize=12, fontweight='bold', color='#0F2448')
ax.set_title('2024 Global Automotive LiDAR Market Share by Supplier', fontsize=15, fontweight='bold', color='#0F2448', pad=15)
ax.invert_yaxis()

for bar, val in zip(bars, market_share):
    ax.text(bar.get_width() + 0.3, bar.get_y() + bar.get_height()/2,
            f'{val}%', va='center', fontsize=10, fontweight='bold', color='#0F2448')

ax.annotate('Top 4 Chinese Players\n>95% Global Share', xy=(30, 3.5), fontsize=11, color='#E86A17',
            fontweight='bold', ha='center',
            bbox=dict(boxstyle='round,pad=0.4', facecolor='#FFF3E0', edgecolor='#E86A17', alpha=0.9))

ax.spines['top'].set_visible(False)
ax.spines['right'].set_visible(False)
ax.spines['left'].set_color('#CCCCCC')
ax.spines['bottom'].set_color('#CCCCCC')
ax.set_xlim(0, 45)
ax.set_facecolor('#FAFBFC')
fig.patch.set_facecolor('white')

plt.tight_layout()
fig.savefig(os.path.join(outdir, 'market_players.png'), bbox_inches='tight', facecolor='white')
plt.close()

print("All 5 charts generated successfully in", outdir)
for f in os.listdir(outdir):
    full = os.path.join(outdir, f)
    print(f"  {f} - {os.path.getsize(full)//1024}KB")
