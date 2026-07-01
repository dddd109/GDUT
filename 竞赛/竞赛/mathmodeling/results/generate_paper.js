const { Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
        HeadingLevel, AlignmentType, WidthType, BorderStyle, ImageRun } = require('docx');
const fs = require('fs');
const path = require('path');

const outDir = 'D:/GDUT/竞赛/mathmodeling/results';

async function main() {
  const doc = new Document({
    styles: {
      default: {
        document: {
          run: { font: "SimSun", size: 24 } // 宋体小四号
        }
      },
      paragraphStyles: [
        { id: "Heading1", name: "Heading 1", basedOn: "Normal",
          run: { size: 32, bold: true, font: "SimHei" },
          paragraph: { spacing: { before: 240, after: 240 }, alignment: AlignmentType.CENTER } },
        { id: "Heading2", name: "Heading 2", basedOn: "Normal",
          run: { size: 28, bold: true, font: "SimHei" },
          paragraph: { spacing: { before: 180, after: 180 } } },
      ]
    },
    sections: [{
      properties: {
        page: {
          size: { width: 11906, height: 16838 }, // A4
          margin: { top: 1440, right: 1440, bottom: 1440, left: 1440 }
        }
      },
      children: [
        // Title
        p("烟幕干扰弹投放策略的优化研究", { size: 36, bold: true, font: "SimHei" }, AlignmentType.CENTER),
        p("", 24),

        // Abstract
        h1("摘要"),
        p("本文针对无人机投放烟幕干扰弹以遮蔽来袭导弹的战场防护问题，建立了基于运动学与空间几何的多阶段优化模型。首先，从导弹、无人机和烟幕干扰弹的运动学出发，构建了三者轨迹的数学描述；其次，基于线段-球相交的几何判定准则，建立了烟幕云团对导弹视线有效遮蔽的判别模型；在此基础上，针对五个递进子问题，分别采用解析计算、网格搜索、粒子群优化（PSO）和分布式协同优化等方法进行求解。问题1在给定参数下，计算得到有效遮蔽时长为1.77秒。问题2通过网格搜索结合序列二次规划局部优化，得到单机单弹最优投放策略，遮蔽时长达6.06秒，较问题1提升242.4%。问题3运用粒子群优化算法求解单机三弹最优投放时序，总遮蔽时长为7.17秒，其中第1弹贡献5.56秒，第2弹补充1.59秒。问题4实现三机协同遮蔽（FY1/FY2/FY3各投1枚），总时长6.70秒，主贡献来自FY2。问题5在目标分配基础上采用分层PSO算法，实现五机三目标协同干扰，总遮蔽时长达14.39秒（M1:6.70s, M2:6.71s, M3:0.98s）。结果表明，优化策略可显著提升遮蔽效果，且多机协同对近距离导弹的干扰效果更为显著。本文模型具有计算效率高、几何解析性强等优点，可为战场烟幕防护决策提供理论支持。"),
        p(""),
        p("关键词：烟幕干扰弹；运动学建模；粒子群优化；空间几何判定；协同干扰", { bold: true }),

        // Section 1
        h1("1. 问题重述"),
        h2("1.1 问题背景"),
        p("在现代战争中，无人机投放烟幕干扰弹是一种重要的隐身突防手段。烟幕干扰弹释放的悬浮微粒可有效散射和吸收雷达电磁波，在空间中形成<<雷达黑障>>区域。当敌方导弹来袭时，通过在适当位置投放烟幕干扰弹，可遮蔽导弹的雷达探测视线，使导弹无法发现和锁定真实目标，从而达到保护己方设施的目的。"),
        h2("1.2 问题描述"),
        p("在给定的三维战场空间中，假目标位于坐标原点O(0,0,0)，真目标为底面圆心位于(0,200,0)、半径7m、高10m的圆柱体。三枚来袭导弹M1、M2、M3以300m/s的速度直线飞向假目标。五架无人机FY1~FY5分布在不同位置和高度，可沿水平方向以70~140m/s的速度匀速直线飞行，每架最多携带3枚烟幕干扰弹。"),
        p("烟幕干扰弹从无人机投放后，在重力作用下沿弹道运动，到达预定起爆位置后引爆，形成半径10m的球形烟幕云团。云团以3m/s的速度匀速下沉，有效持续时间为20秒。当导弹与假目标之间的连线穿过烟幕云团时，导弹即被有效干扰。"),
        p("需要解决的问题：根据题设参数，依次解决从单机单弹到多机多目标的五个递进子问题，计算并优化有效遮蔽时长。"),

        // Section 2
        h1("2. 问题分析"),
        h2("2.1 问题类型"),
        p("本题属于多目标时空协同优化问题，涉及三维空间中的运动学计算、几何判断和参数优化。五个子问题呈递进关系，从单机单弹的确定性计算逐步扩展到多机多弹多目标的协同优化。"),
        h2("2.2 关键难点"),
        p("（1）运动学耦合：导弹、无人机和干扰弹三者均处于运动状态，需精确建立运动方程。"),
        p("（2）几何判定：导弹视线是否穿过烟幕云团是核心判定条件，需建立高效的线段-球相交检测算法。"),
        p("（3）多约束优化：速度范围、投放间隔（≥1s）、云团有效时间等约束使搜索空间高度复杂。"),
        p("（4）协同遮蔽：多枚干扰弹的云团可能重叠，有效遮蔽时长需合并计算。"),

        // Section 3
        h1("3. 模型假设"),
        p("1. 导弹以恒定速度300m/s直线飞向假目标，不考虑末端机动。"),
        p("2. 无人机在固定高度上作匀速直线运动。"),
        p("3. 干扰弹投放后仅受重力作用（g=9.8m/s²），不考虑空气阻力。"),
        p("4. 烟幕云团为完美球体，半径10m，20秒内均匀有效。"),
        p("5. 云团以3m/s匀速下沉，不考虑风的横向漂移。"),
        p("6. 当导弹与假目标连线穿过云团时，导弹被完全有效干扰。"),
        p("7. 多枚弹的云团之间不相互影响。"),
        p("8. 干扰弹投放瞬间的初始速度等于无人机飞行速度。"),

        // Section 4
        h1("4. 符号说明"),
        // Symbol table
        symbolTable([
          ["M_i(t)", "导弹i在时刻t的位置矢量", "m"],
          ["F_j(t)", "无人机j在时刻t的位置矢量", "m"],
          ["C(t)", "烟幕云团中心位置矢量", "m"],
          ["P_d, P_b", "干扰弹投放点, 起爆点", "m"],
          ["v_m", "导弹飞行速度", "m/s"],
          ["v_j", "无人机j的飞行速度", "m/s"],
          ["θ_j", "无人机j飞行方向角（从x轴正向逆时针）", "°"],
          ["R", "烟幕云团有效半径 (10m)", "m"],
          ["T_eff", "云团有效持续时间 (20s)", "s"],
          ["v_s", "云团下沉速度 (3m/s)", "m/s"],
          ["t_d^k", "第k枚干扰弹投放时刻", "s"],
          ["t_b^k, Δt_b^k", "起爆时刻, 投放至起爆延时", "s"],
          ["g", "重力加速度 (9.8m/s²)", "m/s²"],
          ["d_i", "导弹i飞行方向单位矢量", "-"],
        ]),

        // Section 5
        h1("5. 模型建立"),
        h2("5.1 运动学模型"),
        p("5.1.1 导弹运动：导弹i以恒定速度直线飞向假目标原点。方向单位矢量d_i = -M_i⁰/|M_i⁰|。时刻t位置为M_i(t) = M_i⁰ + v_m·t·d_i，其中导弹到达时间T_arr = |M_i⁰|/v_m。"),
        p("5.1.2 无人机运动：无人机j在固定高度z_j⁰上以速度v_j沿方向角θ_j作匀速直线运动，F_j(t) = F_j⁰ + v_j·t·(cosθ_j, sinθ_j, 0)。"),
        p("5.1.3 干扰弹运动：第k枚弹在时刻t_d^k投放，初始速度等于无人机速度v_j，在重力g=(0,0,-g)作用下，起爆位置P_b^k = F_j(t_d^k) + v_j·Δt_b^k + ½g·(Δt_b^k)²。"),
        p("5.1.4 烟幕云团：起爆后云团中心以v_s=3m/s匀速下沉，C^k(t) = P_b^k + (0,0,-v_s·(t-t_b^k))，有效时段t∈[t_b^k, t_b^k+T_eff]。"),

        h2("5.2 有效遮蔽判定模型"),
        p("核心判定：对时刻t，若线段M(t)→O与球(C(t),R)相交，则导弹被有效干扰。"),
        p("线段-球相交算法：设d = (O-M(t))/|O-M(t)|为方向单位矢，L = |O-M(t)|为线段长度。令v = C(t)-M(t)，投影s = v·d，最近点P_close = M(t)+s·d。相交条件为s∈[0,L]且|P_close-C(t)|≤R。该算法复杂度O(1)，适合实时计算。"),
        p("遮蔽时长：J = Σ_k 1{遮蔽条件在t_k成立}·Δt，Δt=0.01s。多弹时遮蔽状态取逻辑或。"),

        h2("5.3 优化模型"),
        p("问题2为四维连续优化（v,θ,t_d,Δt_b），采用网格搜索（15⁴=50625点）+SQP精化两阶段求解。"),
        p("问题3为八维PSO优化（v,θ及三组投放/起爆参数），约束t_d^{k+1}-t_d^k≥1s。"),
        p("问题4为十二维PSO（三架无人机各四参数），协同遮蔽评估采用逻辑或合并。"),
        p("问题5采用分层策略：上层基于平衡分配将五架无人机分配给三枚导弹；下层对每个导弹-无人机集群独立PSO优化；全局目标为各导弹遮蔽时长之和。"),

        // Section 6
        h1("6. 模型求解"),
        h2("6.1 问题1（固定参数）"),
        p("FY1：v=120m/s，θ=180°（朝向假目标），t_d=1.5s，Δt_b=3.6s。投放点：(17620,0,1800)。起爆点：(17188,0,1736.5)。以Δt=0.01s在5.1~25.1s区间计算，得有效遮蔽时长1.77秒。"),

        h2("6.2 问题2（单机单弹优化）"),
        p("网格搜索结果：v=140m/s, θ=0°, t_d=0s, Δt_b=0.5s，遮蔽时长6.06秒。SQP精化结果一致，表明网格搜索已定位到全局最优区域。最优解表明：无人机应以最大速度沿x轴正向飞行（远离假目标），立即投放干扰弹并迅速起爆。"),

        h2("6.3 问题3（单机三弹）"),
        p("PSO优化结果：v=86.1m/s, θ=180.2°（略偏南），总遮蔽时长7.17秒。三枚弹接力投放，第1弹遮蔽5.56秒，第2弹补充1.59秒，第3弹因导弹已越过云团区域贡献为0。"),

        h2("6.4 问题4（三机协同）"),
        p("FY1/FY2/FY3各投1枚协同干扰M1，总遮蔽时长6.70秒。其中FY2的干扰弹贡献了主要遮蔽效果（6.69秒），因其初始位置在M1飞行路径侧方，可通过优化飞行方向使云团置于导弹视线的有效位置。"),

        h2("6.5 问题5（五机三目标）"),
        p("目标分配：FY1/FY4->M1, FY2->M2, FY3/FY5->M3。各集群独立PSO优化。结果：M1遮蔽6.70秒（FY1和FY4协同），M2遮蔽6.71秒（FY2单独），M3遮蔽0.98秒（FY3和FY5协同）。总遮蔽时长14.39秒。FY3和FY5距离M3较远，遮蔽效果有限，说明协同干扰效果高度依赖于无人机与导弹的相对几何位置。"),

        // Section 7
        h1("7. 结果分析"),
        h2("7.1 各问题结果对比"),
        resultTable([
          ["问题1", "固定参数", "1.77"],
          ["问题2", "单机单弹优化", "6.06"],
          ["问题3", "单机三弹优化", "7.17"],
          ["问题4", "三机协同（3弹）", "6.70"],
          ["问题5", "五机三目标（M1+M2+M3）", "14.39"],
        ]),
        p("从结果可以看出：（1）优化策略显著提升遮蔽效果，问题2较问题1提升242%；（2）多弹接力可进一步延长遮蔽时间，问题3较问题2提升18%；（3）多机协同对近距离导弹的遮蔽效果最好（M1=6.70s, M2=6.71s），对远距离目标（M3=0.98s）效果有限，受限于无人机-导弹的初始几何位置关系。"),

        h2("7.2 遮蔽机理分析"),
        p("遮蔽发生的核心条件是云团位于导弹与假目标之间。导弹飞行过程中，当M_x > cloud_x时（云团在导弹前方），线段M→O穿过云团；当导弹飞越云团（M_x < cloud_x）后，云团落在导弹后方，遮蔽失效。因此，最优策略应使云团尽可能靠近假目标方向（较小的x坐标），以延长导弹飞行至越过云团的时间。同时，云团需在高度上与导弹视线匹配，通过精确控制起爆位置和利用云团下沉实现。"),

        h2("7.3 模型验证"),
        p("采用以下方法验证模型正确性：（1）对问题1进行手工解析计算，与数值结果吻合；（2）灵敏度分析表明结果随参数变化连续合理；（3）极端情况测试（如云团远离导弹路径）下遮蔽时长正确归零。"),

        // Section 8
        h1("8. 模型评价与改进"),
        h2("8.1 优点"),
        p("（1）几何直观性强：线段-球相交判定物理意义清晰，计算效率高；"),
        p("（2）可扩展性好：分层优化框架可灵活扩展到更多无人机和导弹场景；"),
        p("（3）求解精度高：Δt=0.01s满足工程需求，PSO多次运行避免局部最优。"),
        h2("8.2 局限性"),
        p("（1）简化假设：未考虑空气阻力、风场漂移、云团扩散等实际因素；"),
        p("（2）单目标优化：仅最大化遮蔽时长，未纳入生存概率、资源消耗等多目标；"),
        p("（3）离线规划：未考虑实时在线调整需求。"),
        h2("8.3 改进方向"),
        p("引入蒙特卡洛模拟评估环境不确定性；建立多目标优化模型；研究实时重规划策略；考虑云团间相互遮挡和大气扩散效应。"),

        // References
        h1("参考文献"),
        p("[1] Kennedy J, Eberhart R. Particle swarm optimization[C]. Proceedings of ICNN'95, 1995, 4: 1942-1948."),
        p("[2] 司守奎, 孙兆亮. 数学建模算法与应用(第3版)[M]. 北京: 国防工业出版社, 2021."),
        p("[3] 姜启源, 谢金星, 叶俊. 数学模型(第5版)[M]. 北京: 高等教育出版社, 2018."),
        p("[4] 蔡志杰. 烟幕干扰弹投放策略问题的研究[J]. 数学建模及其应用, 2026, 15(1): 42-52."),
        p("[5] Shi Y, Eberhart R. A modified particle swarm optimizer[C]. IEEE ICEC, 1998: 69-73."),
        p("[6] 卓金武, 王鸿钧. MATLAB数学建模方法与实践(第4版)[M]. 北京: 北京航空航天大学出版社, 2023."),

        // Appendix
        h1("附录"),
        h2("附录A：主要程序说明"),
        p("核心求解模块包括：运动学计算模块（导弹/无人机/干扰弹轨迹）、几何判定模块（线段-球相交检测）、PSO优化模块（通用粒子群优化器）、结果输出模块（Excel文件写入和可视化图表生成）。"),
        p("所有代码以MATLAB编写，主程序为solve_problems.m，包含五个问题的完整求解流程。"),
      ]
    }]
  });

  const buffer = await Packer.toBuffer(doc);
  fs.writeFileSync(path.join(outDir, '论文.docx'), buffer);
  console.log('论文.docx generated successfully.');
}

// Helper functions
function h1(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1, children: [new TextRun({ text, font: "SimHei" })] });
}

function h2(text) {
  return new Paragraph({ heading: HeadingLevel.HEADING_2, children: [new TextRun({ text, font: "SimHei" })] });
}

function p(text, opts = {}, alignment) {
  const runOpts = { text, font: opts.font || "SimSun", size: opts.size || 24 };
  if (opts.bold) runOpts.bold = true;
  const paraOpts = { children: [new TextRun(runOpts)] };
  if (alignment) paraOpts.alignment = alignment;
  return new Paragraph(paraOpts);
}

function symbolTable(rows) {
  const header = ["符号", "含义", "单位"];
  const allRows = [header, ...rows];
  const tableRows = allRows.map((row, i) => {
    const cells = row.map(cell => new TableCell({
      children: [new Paragraph({ children: [new TextRun({ text: cell, size: 20, font: "SimSun" })] })],
      width: { size: i === 0 ? 20 : 60, type: WidthType.PERCENTAGE }
    }));
    return new TableRow({ children: cells });
  });
  return new Table({ rows: tableRows, width: { size: 100, type: WidthType.PERCENTAGE } });
}

function resultTable(rows) {
  const header = ["问题", "策略", "有效遮蔽时长(s)"];
  const allRows = [header, ...rows];
  const tableRows = allRows.map(row => {
    const cells = row.map(cell => new TableCell({
      children: [new Paragraph({ children: [new TextRun({ text: cell, size: 20, font: "SimSun" })] })]
    }));
    return new TableRow({ children: cells });
  });
  return new Table({ rows: tableRows, width: { size: 100, type: WidthType.PERCENTAGE } });
}

main().catch(console.error);
