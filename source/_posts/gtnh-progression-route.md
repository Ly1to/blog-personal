---
title: GTNH（格雷科技：新视野）基本通关路线
date: 2026-11-11 21:15:00
tags:
  - GTNH
  - 格雷科技
  - Minecraft
  - 整合包攻略
categories:
  - 游戏
---

> 面向 **2.9.x** 稳定版的路线整理：从石器时代到星门（Stargate）的主线骨架、每级的关键机器与卡点。
>
> 版本核对时间：2026-11-11。最新稳定版 **2.9.0**，最新开发版 `2.10.0-nightly-2026-11-10`。
> 结论先说：主线仍是 **蒸汽 → LV → MV → … → UXV / MAX → 星门**，但 2.9 在 UV 之后插入了 LHC、BEC、NAC 等新机器，并新增了 **MAX** 电压层。

---

## 目录

1. [一句话版路线](#1-一句话版路线)
2. [电压等级与阶段总览](#2-电压等级与阶段总览)
3. [各阶段详解](#3-各阶段详解)
4. [2.9 对路线的影响](#4-29-对路线的影响)
5. [通用建议与常见误区](#5-通用建议与常见误区)
6. [参考资料](#6-参考资料)

---

## 1. 一句话版路线

> 每个阶段的套路都是一样的：**出现新材料 → 需要更高温度/更强的机器 → 解锁新机器 → 做出新电路 → 进入下一等级**。
> 真正卡人的从来不是"打不过"，而是**材料链断档**和**电不够用**。

对 2.9 版本，一句话可以写成：

> 焦炭炼钢上蒸汽 → LV 电力化 + EBF → MV 铝与塑料 → HV 不锈钢与 SMD → EV 钛与晶体电路 → IV 钨钢与装配线 → LuV/ZPM/UV 聚变与太空 → UV 起 LHC 束流制造 → UIV 末 BEC + 众神熔炉 → UMV/UXV 终极材料 → MAX 级 Planck 电路 → 星门。

---

## 2. 电压等级与阶段总览

格雷的电压等级（EU/t）：

| 等级 | 电压 | 等级 | 电压 |
|---|---|---|---|
| ULV | 8 | UV | 524,288 |
| LV | 32 | UHV | 2,097,152 |
| MV | 128 | UEV | 8,388,608 |
| HV | 512 | UIV | 33,554,432 |
| EV | 2,048 | UMV | 134,217,728 |
| IV | 8,192 | UXV | 536,870,912 |
| LuV | 32,768 | MAX | 2,147,483,647 |
| ZPM | 131,072 | | |

阶段与卡点：

| 阶段 | 核心目标 | 典型瓶颈 |
|---|---|---|
| 石器 / 蒸汽 | 青铜、蒸汽机器、**钢** | 焦炭与木炭供给、蒸汽压力 |
| LV | 电力机器、矿石处理线、EBF | 电路板、钢与铝 |
| MV | 铝、塑料（PE）、石油化工 | 铝土矿处理链、乙烯 |
| HV | 不锈钢、Cleanroom、SMD | 铬与镍、发电规模 |
| EV | 钛、晶体电路、多方块化 | 钛链（钛铁矿/金红石） |
| IV | 钨钢、铂族金属、装配线 | 铂族副产、钨 |
| LuV | 聚变 MK1、液氦、超导 | 聚变材料与线圈 |
| ZPM | 聚变 MK2、新式 Mega 机器 | 电力规模、太空矿 |
| UV | 聚变 MK3、**LHC 与束流制造** | 粒子产线、能源 |
| UHV → UIV | Trinium、Hypogen、Universium、戴森云 | 巨量电力与材料 |
| UMV → UXV | 终极材料、超导 | 全链路产能 |
| MAX | **Planck-Scale Circuit**、Exo-Foundry | 电路总厂、星门材料 |
| 终局 | **星门（Stargate）** | BEC 产线与新机器部件 |

---

## 3. 各阶段详解

### 3.1 石器 → 蒸汽时代

- **焦炉**：木头 → 木炭，煤 → 焦炭（附带杂酚油）。2.9 新增了 **GT Coke Oven**（GregTech 自己的焦炉，无需供电），任务书的焦炉任务也改成教它，比旧路线省事。
- **砖高炉（Bricked Blast Furnace）**：出**钢**，是 LV 的前置。
- 一整套**蒸汽机器**：Steam Grinder（研磨）、Steam Furnace、Alloy Smelter、Compressor、Extractor 等。
- 2.9 新增 **Steam Hearth**：一次烧 8 个的蒸汽多方块熔炉，前期批量烧炼很好用。
- 供电：蒸汽锅炉 + 蒸汽轮机，或直接蒸汽驱动。**蒸汽压力不足是最常见的卡点**，先扩锅炉和管道。
- 橡胶：IC2 橡胶树/橡胶采集，用于线缆绝缘。

### 3.2 LV（32 EU/t）

- 电力机器 + 线缆（注意线损，配 Battery Buffer 做缓冲）。
- 基础**矿石处理线**：Macerator → Ore Washer → Centrifuge，从这时开始攒副产。
- **Electric Blast Furnace（EBF）**：一般 LV 期就能搭（白铜线圈 + LV 能源仓），炼铝与合金；要量产铝/不锈钢建议升 MV。
- 电路从电子管/基础电路板起步，**电路是每一级的硬门槛**。

### 3.3 MV（128 EU/t）

- **铝**：铝土矿 → 氧化铝 → EBF 炼铝，是 MV 的核心。
- **塑料 PE**：乙烯 → 聚乙烯，MV/HV 电路与外壳必需。
- 石油化工入门：蒸馏塔、化工厂；开始用**苯/燃气轮机**替代蒸汽发电。
- Implosion Compressor（要 TNT），做高级材料。
- 2.9 的好消息：**SMD 元件上移到 HV**，MV 电路只用普通元件，压力小了很多。

### 3.4 HV（512 EU/t）

- **不锈钢**（铁 + 镍 + 铬），升级多方块与外壳。
- **Cleanroom（洁净室）**：电路量产的前提。
- **SMD 元件量产**（2.9 起走 HV 装配机配方，耗时减半）。
- 大型多方块：大型化学反应器、蒸馏塔、GT++ 系列。
- 大规模发电：苯、柴油、燃气轮机阵列。

### 3.5 EV（2048 EU/t）

- **钛**：钛铁矿 / 金红石处理链。
- **晶体电路**：硅锭 → 晶圆 → 芯片的量产。
- 矿石处理全面多方块化，开始铺 **AE2**（ME 网络）。

### 3.6 IV（8192 EU/t）

- **钨钢**：黑钨矿 → 钨 → 钨钢，高温线圈与高级机器的材料。
- **铂族金属链**（镍/铜矿副产 → 铂/钯/铱/锇），铱是聚变与星门的关键。
- **Assembly Line（装配线）**：高级电路与聚变部件的门槛。
- 纳米电路。

### 3.7 LuV → ZPM

- **聚变 MK1**（LuV）→ **MK2**（ZPM）：液氦、超导、高级线圈。
- ZPM 阶段把老的 Mega 机器换掉：**Mega Blast Furnace → Exothermic Hearth**，**Mega Vacuum Freezer → Endothermic Fridge**（都是 2.9 的新结构，ZPM 级）。
- 离心机可以上 **Spinmatron-2737**（ZPM+，3 倍速、70% 能耗）。

### 3.8 UV（524k EU/t）

- **聚变 MK3**。
- **LHC（大型强子对撞机）+ Beamcrafting**：2.9 新增，**起点 UV**，取代已弃用的 Compact Cyclotron（2.10 会删除）。
  - 流程：Source Chamber 造粒子 → 束流线（beamline）→ 小环加速 → 大环分束对撞 → **随机产出粒子**。
  - 能量决定"哪些粒子可能出现"，输出的具体种类按仓随机器随机。
  - **Beam Crafter** 用两束粒子 + 普通物品/流体，做 containment unit、quark creation catalyst、boundless cosmic solder 等。
  - 配套小多方块：镜子（转向）、分离器（分束）、稳定器（把断续来源抹平）。
- 另有 256A 发电机仓（UV–UXV），不用再把 Active Transformer 插满 64A 仓。

### 3.9 UHV → UEV → UIV

- **UHV**：Trinium 等终极材料，电力规模起飞。
- **UEV / UMV**：Hypogen（配方电压从 UIV 降到 UEV）、Universium（UMV 起）、戴森云（2.9 改用 UIV 电路，不再卡 UMV）。
- **UIV 末**：解锁 **Forge of the Gods（众神熔炉）** 与 **BEC 产线**。
  - BEC（Bose-Einstein Condensate Line）是 5 个必须配合使用的多方块，用来取代成百上千个 Advanced Assembly Line；
  - **Eye of Harmony 的部件改为在 BEC 生产**。

### 3.10 UMV → UXV → MAX

- 新顶层 **MAX**：`ULV < LV < MV < HV < EV < IV < LuV < ZPM < UV < UHV < UEV < UIV < UMV < UXV < MAX`。
- MAX 级代表产物 **Planck-Scale Circuit（普朗克尺度电路）**。
- **Nanochip Assembly Complex（NAC）**：一个多方块承包 **ULV → MAX** 全部电路（含 ULV–EV 的"Primitive"线），后期电路总厂。
- 同层内容：Circuit Computation Singularity（每个电压等级一个，ULV→MAX）、**Exo-Foundry** 系列（模块化的终局熔铸/凝固）、Power IC。
- 2.9 新增终局组件：**Pseudo Star**、**Cosmic Solder**。

### 3.11 终局：星门（Stargate）

- 门槛：**BEC 产线** + 新机器产出的电路与部件。2.9 起**造价明显上调**，主要加在电路与新机器部件上。
- 按任务书收集 Naquadah、Trinium、Cosmic Solder、Pseudo Star 等材料，搭建星门结构。
- 结构细节：2.9 修好了跨区块成形与基座朝向的问题，现已稳定。

---

## 4. 2.9 对路线的影响

| 位置 | 变化 | 对路线的意义 |
|---|---|---|
| 蒸汽期 | GT Coke Oven、Steam Hearth 上线，焦炉任务改写 | 前期更顺，照任务书做即可 |
| 多方块重做 | 大型涡轮机、Steam Grinder/Squasher、工业焦炉、大型锅炉全换结构，锅炉产汽 +20% | 老教程的蓝图失效，重建前先看新结构 |
| HV | SMD 元件改为 HV 配方 | MV 期减负 |
| ZPM | Exothermic Hearth / Endothermic Fridge | Mega EBF 与 Mega Freezer 已不存在 |
| 中期 | IC2 作物被 **Crops NH** 全面替换（土壤、生物群系标签、施肥、确定性突变、生病代替死亡、抗性有收益、Industrial Farm 多方块） | 旧作物攻略作废，橡胶/材料作物要重新学 |
| UV | **LHC + Beamcrafting** 取代 Compact Cyclotron（2.10 删旧机） | 新产线要提前规划空间与能源 |
| UIV 末 | **BEC** 产线 + 众神熔炉 | 后期部件从"堆装配线"变成"跑 BEC" |
| 全期 | **Nanochip Assembly Complex** | 电路可以统一到一个多方块，但建造成本高 |
| 终局 | 星门涨价、新增 Pseudo Star / Cosmic Solder | 通关成本更高，MAX 层不可跳过 |
| 体验 | 任务书加方向箭头、完成度百分比；GuideNH 游戏内按 `G` 打开带 NEI 配方与 3D 多方块预览的指南 | 这才是现在最靠谱的攻略来源 |

平衡性小改动也值得记一下：

- EBF 里 **铁粉炼钢现在需要额外碳粉**（铁粉 + 煤/木炭/碳/褐煤粉 + 1000 L 氧气）。
- 传送带/泵从 LuV 起每级 ×4（以前是 ×2）。
- Advanced Assembly Line 超过 1 tick 后的超频转化为并行。

---

## 5. 通用建议与常见误区

1. **跟紧任务书**：每一版的任务书就是官方路线图，2.9 还补了 LHC、NAC、Exo-Foundry、Power IC/Planck 电路、BEC 与星门部件的分级任务。
2. **用 GuideNH**：按 `G` 打开游戏内指南，Markdown 页面带 NEI 配方和 3D 多方块预览；结构重做之后，它比老视频可靠。
3. **电力永远先于产能**：每级先把发电和储电做够，再扩机器；UV 之后不冲聚变就会卡死。
4. **矿石处理优先升级**：从单机到多方块，副产（铬、铂族、稀有金属）才是后期真正的瓶颈。
5. **尽早做 AE2**（MV/HV 期），它是后期自动化与存储的地基。
6. **常驻瓶颈材料**：钢、铝、塑料、不锈钢、钛、钨钢、铂族、Naquadah —— 看到就扩产。
7. **别抄老蓝图**：2.9 大量多方块换了结构，形状对不上一律以 GuideNH/任务书为准。
8. **性能**：GTNH 后期对 TPS 敏感，多方块和管道要分区，必要时配合区块加载与管道优化。
9. **常见误区**：
   - 跳级造机器（材料链断档，反而更慢）；
   - 高压电线直接拉满（线损 + 过载，必须配电池缓冲与变压器）；
   - 把 Compact Cyclotron 当长期方案（2.9 已弃用，2.10 删除）。

---

## 6. 参考资料

- 官方 changelog（2.8.4 → 2.9.0）：<https://changelog.gtnh.ogricanx.ch/2.8.4_to_2.9.0/>
- GitHub Releases（版本与更新日志）：<https://github.com/GTNewHorizons/GT-New-Horizons-Modpack/releases>
- 游戏内：任务书（Better Questing）+ GuideNH（`G`）+ NEI
- 中文 wiki：<https://gtnh.huijiwiki.com/>
